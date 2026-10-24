import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/forge_code_analyzer.dart';
import 'package:qfli_c/main.dart' show forgeProfile;
import 'package:qfli_studio_core/editor/editor_analysis_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/open_file.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

/// Product/core wiring proof with the actual editor and ForgeCodeAnalyzer.
/// Only the native method/event transport is mocked. These tests do not prove
/// Clang execution or OHOS acceptance; code-analysis-regression.cjs covers the
/// actual Clang/NAPI action independently.
void main() {
  for (final variant in [
    (language: 'c', extension: '.c', size: const Size(1280, 900)),
    (language: 'cpp', extension: '.cpp', size: const Size(390, 844)),
  ]) {
    testWidgets(
      'mock transport wires real ${variant.language} editor analysis at '
      '${variant.size}',
      (tester) async {
        final fixture = _EditorFixture(variant.language, variant.extension);
        await fixture.mount(tester, variant.size);
        final analysis = tester
            .widget<EditorProblemsBar>(find.byType(EditorProblemsBar))
            .analysis;
        expect(analysis.analyzer, same(fixture.analyzer));
        expect(forgeProfile.codeAnalyzer, isA<ForgeCodeAnalyzer>());
        await _waitForAnalysis(tester, analysis);
        expect(analysis.problems, isEmpty);
        expect(find.text('本地检查未发现问题'), findsOneWidget);

        final source = analysis.editor.current!;
        final header = await _open(
          tester,
          analysis,
          fixture.header,
          fixture.project,
        );
        header.controller.text = _invalidHeader;
        source.controller.text = _invalidSource;
        analysis.editor.select(analysis.editor.files.indexOf(source));
        await _waitForAnalysis(tester, analysis);

        expect(source.dirty, isTrue);
        expect(header.dirty, isTrue);
        _expectRequest(
          fixture.transport.requests.last,
          project: fixture.project.path,
          active: fixture.source.path,
          language: variant.language,
          documents: {
            fixture.source.path: _invalidSource,
            fixture.header.path: _invalidHeader,
          },
        );
        expect(analysis.problems, hasLength(2));
        final sourceProblem = analysis.problems.singleWhere(
          (problem) => p.equals(problem.filePath, fixture.source.path),
        );
        final headerProblem = analysis.problems.singleWhere(
          (problem) => p.equals(problem.filePath, fixture.header.path),
        );
        for (final row in [
          (sourceProblem, _invalidSource, 'missing_source'),
          (headerProblem, _invalidHeader, 'missing_header'),
        ]) {
          expect(row.$1.startOffset, row.$2.indexOf(row.$3));
          expect(row.$1.endOffset, row.$2.indexOf(row.$3) + row.$3.length);
          expect(row.$1.source, 'Clang C17/C++20');
          expect(row.$1.severity, CodeDiagnosticSeverity.error);
        }
        expect(
          _wavyLeaves(
            _lineSpan(tester, source, 2),
          ).map((span) => span.text).join(),
          'missing_source',
        );
        expect(
          _wavyLeaves(
            _lineSpan(tester, header, 1),
          ).map((span) => span.text).join(),
          'missing_header',
        );
        expect(
          source.diagnostics!.gutterSeverity(2),
          CodeDiagnosticSeverity.error,
        );
        fixture.expectOriginalPayloadBytes();

        await tester.tap(
          find.byKey(const ValueKey('editor-problems-status')).hitTestable(),
        );
        await tester.pump();
        final panel = find.byType(EditorProblemsPanel);
        expect(panel, findsOneWidget);
        expect(
          find.descendant(
            of: panel,
            matching: find.textContaining(
              '${p.basename(fixture.source.path)}:3:'
              '${_invalidSource.split('\r\n')[2].indexOf('missing_source') + 1}',
            ),
          ),
          findsOneWidget,
        );
        await _tapProblem(tester, sourceProblem.message);
        expect(analysis.editor.current, same(source));
        _expectSelection(source, 2, 'missing_source');

        // A Problems row must select the dirty nested header, not reread its
        // clean disk bytes or reinterpret Clang byte columns as UTF-16 columns.
        await _tapProblem(tester, headerProblem.message);
        expect(analysis.editor.current, same(header));
        _expectSelection(header, 1, 'missing_header');
        await _waitForAnalysis(tester, analysis);
        _expectRequest(
          fixture.transport.requests.last,
          project: fixture.project.path,
          active: fixture.header.path,
          language: variant.language,
          documents: {
            fixture.source.path: _invalidSource,
            fixture.header.path: _invalidHeader,
          },
        );

        analysis.editor.select(analysis.editor.files.indexOf(source));
        await _waitForAnalysis(tester, analysis);
        // The source becomes shorter while its previous waves are installed.
        // The mounted renderer must reconcile its old line indices safely.
        source.controller.text = _repairedSource;
        header.controller.text = _repairedHeader;
        await _waitForAnalysis(tester, analysis);
        expect(analysis.problems, isEmpty);
        expect(find.text('本地检查未发现问题'), findsWidgets);
        expect(find.text(sourceProblem.message), findsNothing);
        expect(find.text(headerProblem.message), findsNothing);
        expect(_wavyLeaves(_lineSpan(tester, source, 1)), isEmpty);
        expect(_wavyLeaves(_lineSpan(tester, header, 1)), isEmpty);
        expect(source.controller.text, _repairedSource);
        expect(header.controller.text, _repairedHeader);
        expect(source.dirty, isTrue);
        expect(header.dirty, isTrue);
        fixture.expectOriginalPayloadBytes();

        // Both original dirty documents remain open. Only this owner's buffer
        // may be sent when a tab from another workspace root becomes active.
        final other = await _open(
          tester,
          analysis,
          fixture.otherSource,
          fixture.otherProject,
        );
        other.controller.text = _invalidOther;
        await _waitForAnalysis(tester, analysis);
        _expectRequest(
          fixture.transport.requests.last,
          project: fixture.otherProject.path,
          active: fixture.otherSource.path,
          language: variant.language,
          documents: {fixture.otherSource.path: _invalidOther},
        );
        final otherProblem = analysis.problems.single;
        expect(otherProblem.filePath, fixture.otherSource.path);
        expect(
          otherProblem.startOffset,
          _invalidOther.indexOf('missing_other'),
        );
        expect(
          otherProblem.endOffset,
          _invalidOther.indexOf('missing_other') + 'missing_other'.length,
        );
        expect(source.diagnostics!.problems, isEmpty);
        expect(header.diagnostics!.problems, isEmpty);

        analysis.editor.select(analysis.editor.files.indexOf(source));
        await _waitForAnalysis(tester, analysis);
        _expectRequest(
          fixture.transport.requests.last,
          project: fixture.project.path,
          active: fixture.source.path,
          language: variant.language,
          documents: {
            fixture.source.path: _repairedSource,
            fixture.header.path: _repairedHeader,
          },
        );
        expect(analysis.problems, isEmpty);
        expect(other.diagnostics!.problems, isEmpty);
        expect(source.controller.text, _repairedSource);
        expect(header.controller.text, _repairedHeader);
        expect(other.controller.text, _invalidOther);
        expect(other.dirty, isTrue);
        expect(_wavyLeaves(_lineSpan(tester, source, 1)), isEmpty);
        expect(fixture.transport.methods, everyElement('analyzeStart'));
        fixture.expectOriginalPayloadBytes();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _savedSource =
    '// 已保存 😀\r\n'
    '#include "include/deep/local.h"\r\n'
    'int main(void) { return 0; }\r\n';
const _savedHeader = '// 已保存头 😀\r\n#define VALUE 7\r\n';
const _savedOther = '// 另一项目已保存 😀\r\nint main(void) { return 0; }\r\n';
const _invalidSource =
    '// 临时 😀\r\n'
    '#include "include/deep/local.h"\r\n'
    'int main(void) { /* 😀 */ return missing_source; }\r\n';
const _invalidHeader =
    '// 临时头 😀\r\nstatic int value = /* 😀 */ missing_header;\r\n';
const _invalidOther =
    '// 另一项目临时 😀\r\nint main(void) { /* 😀 */ return missing_other; }\r\n';
const _repairedSource = '// 修复 😀\r\nint main(void) { return 42; }';
const _repairedHeader = '// 修复头 😀\r\n#define VALUE 7\r\n';

Future<OpenFile> _open(
  WidgetTester tester,
  EditorAnalysisController analysis,
  File file,
  Project owner,
) async {
  final error = await tester.runAsync(
    () => analysis.editor.openPath(
      file.path,
      ownerProjectName: owner.name,
      ownerProjectPath: owner.path,
      ownerProjectType: owner.type,
    ),
  );
  expect(error, isNull);
  expect(analysis.editor.current?.path, file.path);
  return analysis.editor.current!;
}

void _expectRequest(
  _AnalysisRequest request, {
  required String project,
  required String active,
  required String language,
  required Map<String, String> documents,
}) {
  expect(request.projectPath, project);
  expect(request.activePath, active);
  expect(request.language, language);
  expect(request.documents, documents);
  expect(
    request.documents.keys,
    everyElement(
      predicate<String>(
        (path) => p.isWithin(project, path),
        'a document under the active project root',
      ),
    ),
  );
}

Future<void> _tapProblem(WidgetTester tester, String message) async {
  final row = find.ancestor(
    of: find.descendant(
      of: find.byType(EditorProblemsPanel),
      matching: find.text(message),
    ),
    matching: find.byType(ListTile),
  );
  expect(row, findsOneWidget);
  await tester.ensureVisible(row);
  // ensureVisible jumps the list position but does not lay out the new scroll
  // offset. Commit that frame before using the row's geometry on a phone.
  await tester.pump();
  final target = row.hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'The scrolled Problems row must accept a real pointer hit.',
  );
  await tester.tap(target);
  await tester.pump();
}

void _expectSelection(OpenFile file, int line, String token) {
  final column = file.controller.codeLines[line].text.indexOf(token);
  expect(column, greaterThanOrEqualTo(0));
  expect(file.controller.selection.baseIndex, line);
  expect(file.controller.selection.baseOffset, column);
  expect(file.controller.selection.extentIndex, line);
  expect(file.controller.selection.extentOffset, column + token.length);
}

TextSpan _lineSpan(WidgetTester tester, OpenFile file, int index) =>
    file.controller.buildTextSpan(
      context: tester.element(find.byType(EditorProblemsBar).first),
      index: index,
      textSpan: TextSpan(text: file.controller.codeLines[index].text),
      style: const TextStyle(),
    );

List<TextSpan> _wavyLeaves(TextSpan span) => [
  if (span.text != null &&
      span.style?.decorationStyle == TextDecorationStyle.wavy)
    span,
  for (final child in span.children ?? const <InlineSpan>[])
    if (child is TextSpan) ..._wavyLeaves(child),
];

Future<void> _waitForAnalysis(
  WidgetTester tester,
  EditorAnalysisController analysis,
) async {
  await _pumpUntil(
    tester,
    () => !analysis.pending && analysis.checked,
    'mock-transport Forge analysis',
  );
  expect(analysis.unavailableReason, isNull);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String operation,
) async {
  for (var attempt = 0; attempt < 200 && !done(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(done(), isTrue, reason: '$operation did not finish');
  await tester.pump();
}

class _AnalysisRequest {
  _AnalysisRequest(Map<dynamic, dynamic> payload)
    : projectPath = payload['projectPath'] as String,
      activePath = payload['activeFilePath'] as String,
      language = payload['language'] as String,
      documents = {
        for (final document in payload['documents'] as List)
          (document as Map)['path'] as String: document['text'] as String,
      };

  final String projectPath;
  final String activePath;
  final String language;
  final Map<String, String> documents;
}

class _MockClangDiagnostic {
  const _MockClangDiagnostic(this.path, this.snapshot, this.token);

  final String path;
  final String snapshot;
  final String token;

  Map<String, Object> toNativeRow() {
    final offset = snapshot.indexOf(token);
    final start = utf8.encode(snapshot.substring(0, offset)).length;
    return {
      'filePath': path,
      'startByte': start,
      'endByte': start + utf8.encode(token).length,
      'severity': 'error',
      'message': 'Mock Clang transport: undeclared $token',
      'code': '4711',
    };
  }
}

class _MockAnalysisTransport {
  static const channel = MethodChannel('qfli_forge/native');
  final events = StreamController<Object?>.broadcast(sync: true);
  final methods = <String>[];
  final requests = <_AnalysisRequest>[];
  final diagnostics = <_MockClangDiagnostic>[];

  Future<Object?> handle(MethodCall call) async {
    methods.add(call.method);
    if (call.method != 'analyzeStart') {
      throw StateError('Editor analysis unexpectedly invoked ${call.method}');
    }
    final payload = call.arguments as Map;
    final request = _AnalysisRequest(payload);
    requests.add(request);
    final rows = [
      for (final diagnostic in diagnostics)
        if (request.documents[diagnostic.path] == diagnostic.snapshot)
          diagnostic.toNativeRow(),
    ];
    final output = jsonEncode({'diagnostics': rows, 'unmappedErrors': false});
    final runId = payload['runId'];
    // Exercise the real adapter's shared-run filtering and split JSON assembly.
    events.add({
      'runId': 'unrelated-run',
      'kind': 'stdout',
      'text': 'not JSON',
    });
    events.add({
      'runId': runId,
      'kind': 'stdout',
      'text': output.substring(0, output.length ~/ 2),
    });
    events.add({
      'runId': runId,
      'kind': 'stdout',
      'text': output.substring(output.length ~/ 2),
    });
    events.add({
      'runId': runId,
      'kind': 'exit',
      'exitCode': rows.isEmpty ? 0 : 1,
    });
    return {'available': true};
  }
}

class _EditorFixture {
  _EditorFixture(String language, String extension) {
    final root = Directory(p.join(directory.path, 'project'))..createSync();
    final otherRoot = Directory(p.join(directory.path, 'other'))..createSync();
    source = _write(
      p.join(root.path, 'main$extension'),
      utf8.encode(_savedSource),
    );
    header = _write(
      p.join(root.path, 'include', 'deep', 'local.h'),
      utf8.encode(_savedHeader),
    );
    otherSource = _write(
      p.join(otherRoot.path, 'main$extension'),
      utf8.encode(_savedOther),
    );
    // Existing compiler output must also survive an analysis-only edit cycle.
    _write(p.join(root.path, 'existing.wasm'), [0, 97, 115, 109, 1, 0, 0, 0]);
    project = Project.create(
      name: 'Forge analysis project',
      path: root.path,
      type: language,
      language: language == 'c' ? 'C' : 'C++',
    );
    otherProject = Project.create(
      name: 'Other Forge project',
      path: otherRoot.path,
      type: language,
      language: language == 'c' ? 'C' : 'C++',
    );
    store = ProjectStore(
      storageFile: File(p.join(directory.path, 'projects.json')),
    );
    settings = SettingsStore(
      storageFile: File(p.join(directory.path, 'settings.json')),
    );
    analyzer = ForgeCodeAnalyzer(events: transport.events.stream);
    transport.diagnostics.addAll([
      _MockClangDiagnostic(source.path, _invalidSource, 'missing_source'),
      _MockClangDiagnostic(header.path, _invalidHeader, 'missing_header'),
      _MockClangDiagnostic(otherSource.path, _invalidOther, 'missing_other'),
    ]);
  }

  final directory = Directory.systemTemp.createTempSync(
    'forge-editor-analysis-',
  );
  final auth = AuthStore();
  final transport = _MockAnalysisTransport();
  final originalPayloadBytes = <String, List<int>>{};
  late final File source;
  late final File header;
  late final File otherSource;
  late final Project project;
  late final Project otherProject;
  late final ProjectStore store;
  late final SettingsStore settings;
  late final ForgeCodeAnalyzer analyzer;

  File _write(String path, List<int> bytes) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    originalPayloadBytes[path] = List<int>.of(bytes);
    return file;
  }

  void expectOriginalPayloadBytes() {
    for (final entry in originalPayloadBytes.entries) {
      expect(File(entry.key).readAsBytesSync(), entry.value, reason: entry.key);
    }
    for (final owner in [project, otherProject]) {
      expect(
        Directory(owner.path)
            .listSync(recursive: true)
            .whereType<File>()
            // Session metadata is deliberately persisted by the actual page.
            .where((file) => p.basename(file.path) != 'history.json')
            .map((file) => file.path),
        unorderedEquals(
          originalPayloadBytes.keys.where(
            (path) => p.isWithin(owner.path, path),
          ),
        ),
      );
    }
  }

  Future<void> mount(WidgetTester tester, Size size) async {
    final previousProfile = StudioProfile.current;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _MockAnalysisTransport.channel,
      transport.handle,
    );
    // Preserve the product's editor identity and policy; inject only the event
    // stream into the real adapter so no OHOS/native library is required here.
    StudioProfile.current = StudioProfile(
      id: forgeProfile.id,
      appTitle: forgeProfile.appTitle,
      productKey: forgeProfile.productKey,
      templates: forgeProfile.templates,
      isOffline: forgeProfile.isOffline,
      offlineOnly: forgeProfile.offlineOnly,
      supportedFileExtensions: forgeProfile.supportedFileExtensions,
      entryFileNames: forgeProfile.entryFileNames,
      codeAnalyzer: analyzer,
    );
    expect(settings.autoSave, isFalse);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpWidget(const SizedBox.shrink());
        var drained = false;
        Object? drainError;
        // History.load joins the page/explorer's queued writes before deletion.
        final pending =
            Future.wait([
              ProjectHistory.load(project.path),
              ProjectHistory.load(otherProject.path),
            ]).then<void>(
              (_) {
                drained = true;
              },
              onError: (Object error) {
                drainError = error;
                drained = true;
              },
            );
        await _pumpUntil(tester, () => drained, 'editor history cleanup');
        await pending;
        expect(drainError, isNull);
        expectOriginalPayloadBytes();
      } finally {
        messenger.setMockMethodCallHandler(
          _MockAnalysisTransport.channel,
          null,
        );
        await transport.events.close();
        StudioProfile.current = previousProfile;
        auth.dispose();
        store.dispose();
        settings.dispose();
        for (var attempt = 0; attempt < 50; attempt++) {
          try {
            if (directory.existsSync()) directory.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            if (attempt == 49) rethrow;
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
        }
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          project: project,
          auth: auth,
          store: store,
          settings: settings,
          initialOpenPath: source.path,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(EditorProblemsBar).evaluate().isNotEmpty,
      'Forge editor mount',
    );
  }
}
