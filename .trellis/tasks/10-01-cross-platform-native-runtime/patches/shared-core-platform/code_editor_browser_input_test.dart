@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

class _SaveIntent extends Intent {
  const _SaveIntent();
}

SemanticsNode _textField(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .singleWhere((node) => node.getSemanticsData().flagsCollection.isTextField);

Future<void> _mount(
  WidgetTester tester,
  CodeLineEditingController controller,
  FocusNode focus, {
  bool readOnly = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: CodeEditor(
      controller: controller,
      focusNode: focus,
      readOnly: readOnly,
      autocompleteSymbols: false,
    ),
  ),
);

Future<void> _sendDelta(
  WidgetTester tester, {
  required String oldText,
  required String inserted,
  required int start,
  required int end,
  required int selection,
}) async {
  final client =
      tester.testTextInput.log
              .lastWhere((call) => call.method == 'TextInput.setClient')
              .arguments
          as List<dynamic>;
  final completed = Completer<void>();
  // TestTextInput exposes full-value updates only; inject the platform delta message.
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.updateEditingStateWithDeltas', [
        client.first,
        {
          'deltas': [
            {
              'oldText': oldText,
              'deltaText': inserted,
              'deltaStart': start,
              'deltaEnd': end,
              'selectionBase': selection,
              'selectionExtent': selection,
              'composingBase': -1,
              'composingExtent': -1,
            },
          ],
        },
      ]),
    ),
    (_) => completed.complete(),
  );
  await completed.future;
  await tester.pump();
}

void main() {
  testWidgets(
    'Web save reaches the ancestor and respects explicit overrides',
    (tester) async {
      final controller = CodeLineEditingController.fromText('save me');
      final focus = FocusNode();
      var outerSaves = 0;
      var editorSaves = 0;
      Future<void> mount({bool override = false}) => tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  _SaveIntent(),
            },
            child: Actions(
              actions: {
                _SaveIntent: CallbackAction<_SaveIntent>(
                  onInvoke: (_) {
                    outerSaves++;
                    return null;
                  },
                ),
              },
              child: CodeEditor(
                controller: controller,
                focusNode: focus,
                shortcutOverrideActions: override
                    ? {
                        CodeShortcutSaveIntent:
                            CallbackAction<CodeShortcutSaveIntent>(
                              onInvoke: (_) {
                                editorSaves++;
                                return null;
                              },
                            ),
                      }
                    : null,
              ),
            ),
          ),
        ),
      );
      Future<void> saveKey() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }

      try {
        await mount();
        focus.requestFocus();
        await tester.pump();
        await saveKey();
        expect(outerSaves, 1);
        expect(editorSaves, 0);
        await mount(override: true);
        await saveKey();
        expect(outerSaves, 1);
        expect(editorSaves, 1);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );

  testWidgets(
    'browser semantics supports focus, selection and multiline edits',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = CodeLineEditingController.fromText('abc\nkeep');
      final focus = FocusNode();
      try {
        await _mount(tester, controller, focus);
        var field = _textField(tester);
        expect(field.getSemanticsData().flagsCollection.isMultiline, isTrue);
        expect(field.getSemanticsData().value, 'abc');
        field.owner!.performAction(field.id, SemanticsAction.focus);
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        field = _textField(tester);
        expect(
          field.getSemanticsData().hasAction(SemanticsAction.setText),
          isTrue,
        );
        field.owner!.performAction(field.id, SemanticsAction.setSelection, {
          'base': 1,
          'extent': 2,
        });
        await tester.pump();
        expect(controller.selection.baseOffset, 1);
        expect(controller.selection.extentOffset, 2);
        expect(
          _textField(tester).getSemanticsData().textSelection,
          const TextSelection(baseOffset: 1, extentOffset: 2),
        );
        field.owner!.performAction(
          field.id,
          SemanticsAction.setText,
          'edited\nsecond',
        );
        await tester.pump();
        expect(controller.text, 'edited\nsecond\nkeep');
        expect(_textField(tester).getSemanticsData().value, 'second');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
        semantics.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );

  testWidgets(
    'browser delta input preserves characters, newline and replacement',
    (tester) async {
      final controller = CodeLineEditingController.fromText('abc\nkeep');
      final focus = FocusNode();
      try {
        await _mount(tester, controller, focus);
        focus.requestFocus();
        await tester.pump();
        controller.selection = const CodeLineSelection.collapsed(
          index: 0,
          offset: 3,
        );
        await tester.pump();
        final config = tester.testTextInput.setClientArgs!;
        expect(config['enableDeltaModel'], isTrue);
        expect((config['inputType'] as Map)['name'], 'TextInputType.multiline');
        await _sendDelta(
          tester,
          oldText: 'abc',
          inserted: '!',
          start: 3,
          end: 3,
          selection: 4,
        );
        expect(controller.text, 'abc!\nkeep');
        await _sendDelta(
          tester,
          oldText: 'abc!',
          inserted: '\n',
          start: 4,
          end: 4,
          selection: 5,
        );
        expect(controller.text, 'abc!\n\nkeep');
        controller.selectAll();
        await tester.pump();
        const replacement =
            '#include <stdio.h>\nint main(void) { return 7; }\n';
        await _sendDelta(
          tester,
          oldText: 'abc!',
          inserted: replacement,
          start: 0,
          end: 4,
          selection: replacement.length,
        );
        expect(controller.text, replacement);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );

  testWidgets(
    'accessible browser full-value input preserves multiline source',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = CodeLineEditingController.fromText('abc\nkeep');
      final focus = FocusNode();
      try {
        await _mount(tester, controller, focus);
        focus.requestFocus();
        await tester.pump();
        expect(
          tester.testTextInput.setClientArgs!['enableDeltaModel'],
          isFalse,
        );
        controller.selection = const CodeLineSelection.collapsed(
          index: 0,
          offset: 3,
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'abc!',
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange(start: 3, end: 4),
          ),
        );
        await tester.pump();
        expect(controller.text, 'abc!\nkeep');
        expect(controller.composing, const TextRange(start: 3, end: 4));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'abc!',
            selection: TextSelection(baseOffset: 1, extentOffset: 2),
          ),
        );
        await tester.pump();
        expect(controller.selection.baseOffset, 1);
        expect(controller.selection.extentOffset, 2);
        expect(controller.composing, TextRange.empty);
        controller.selectAll();
        await tester.pump();
        const source = '#include <stdio.h>\nint main(void) { return 7; }\n';
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: source,
            selection: TextSelection.collapsed(offset: source.length),
          ),
        );
        await tester.pump();
        expect(controller.text, source);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '//typed',
            selection: TextSelection.collapsed(offset: 7),
          ),
        );
        await tester.pump();
        expect(controller.text, '$source//typed');
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '//typed\n',
            selection: TextSelection.collapsed(offset: 8),
          ),
        );
        await tester.pump();
        expect(controller.text, '$source//typed\n');
        await _mount(tester, controller, focus, readOnly: true);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'denied',
            selection: TextSelection.collapsed(offset: 6),
          ),
        );
        await tester.pump();
        expect(controller.text, '$source//typed\n');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
        semantics.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );

  testWidgets(
    'enabling browser semantics updates an active input connection',
    (tester) async {
      final controller = CodeLineEditingController.fromText('abc');
      final focus = FocusNode();
      SemanticsHandle? semantics;
      try {
        await _mount(tester, controller, focus);
        focus.requestFocus();
        await tester.pump();
        expect(tester.testTextInput.setClientArgs!['enableDeltaModel'], isTrue);
        semantics = tester.ensureSemantics();
        await tester.pump();
        final configuration =
            tester.testTextInput.log
                    .lastWhere(
                      (call) => call.method == 'TextInput.updateConfig',
                    )
                    .arguments
                as Map<dynamic, dynamic>;
        expect(configuration['enableDeltaModel'], isFalse);
        controller.selectAll();
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'after\nactivation',
            selection: TextSelection.collapsed(offset: 16),
          ),
        );
        await tester.pump();
        expect(controller.text, 'after\nactivation');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
        semantics?.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );

  testWidgets(
    'read-only browser semantics cannot change source',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = CodeLineEditingController.fromText('unchanged');
      final focus = FocusNode();
      try {
        await _mount(tester, controller, focus, readOnly: true);
        var field = _textField(tester);
        expect(field.getSemanticsData().flagsCollection.isReadOnly, isTrue);
        field.owner!.performAction(field.id, SemanticsAction.focus);
        await tester.pump();
        field = _textField(tester);
        expect(
          field.getSemanticsData().hasAction(SemanticsAction.setText),
          isFalse,
        );
        expect(tester.testTextInput.hasAnyClients, isFalse);
        field.owner!.performAction(field.id, SemanticsAction.setText, 'denied');
        expect(controller.text, 'unchanged');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 60));
        focus.dispose();
        controller.dispose();
        semantics.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
    semanticsEnabled: false,
  );
}
