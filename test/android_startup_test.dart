import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/android_startup.dart';

void main() {
  const channel = MethodChannel('qfli_forge/startup');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('holds rendering until data and the home layout are ready', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    final startup = AndroidStartup(binding: tester.binding);
    final loading = Completer<void>();
    final ready = ValueNotifier(false);
    startup.holdFirstFrame();
    final completion = startup.complete((reportProgress) async {
      reportProgress(1 / 3);
      await loading.future;
      reportProgress(2 / 3);
      reportProgress(1);
      ready.value = true;
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (_, value, _) => Text(value ? 'Home' : 'Loading'),
        ),
      ),
    );
    expect(tester.binding.sendFramesToEngine, isFalse);
    expect(find.text('Home'), findsNothing);
    expect(calls.single.method, 'startupProgress');
    expect(calls.single.arguments, {'progress': 1 / 3});

    loading.complete();
    await tester.pump();
    await tester.pump();
    await completion;
    expect(find.text('Home'), findsOneWidget);
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(calls.map((call) => (call.arguments as Map)['progress']), [
      1 / 3,
      2 / 3,
      1.0,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    ready.dispose();
  });

  testWidgets('releases the first frame if bootstrap fails', (tester) async {
    final startup = AndroidStartup(binding: tester.binding);
    startup.holdFirstFrame();
    expect(tester.binding.sendFramesToEngine, isFalse);
    await expectLater(
      startup.complete((_) async => throw StateError('load failed')),
      throwsStateError,
    );
    expect(tester.binding.sendFramesToEngine, isTrue);
    await tester.pump();
  });

  for (final missing in [true, false]) {
    testWidgets(
      'progress channel ${missing ? 'absence' : 'failure'} does not block startup',
      (tester) async {
        if (!missing) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
        }
        final startup = AndroidStartup(binding: tester.binding);
        startup.holdFirstFrame();
        final completion = startup.complete((reportProgress) async {
          reportProgress(1);
        });
        await tester.pump();
        await tester.pump();
        await completion;
        expect(tester.binding.sendFramesToEngine, isTrue);
      },
    );
  }
}
