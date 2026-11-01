import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/ohos_startup.dart';

/// OHOS startup handshake with the native ArkUI splash (JVMX parity).
///
/// The native splash is hidden only when Flutter's first frame arrives, so
/// these tests pin the deferred frame, the `qflistudio/platform`
/// `startupProgress` payload, that the released frame is the ready home page,
/// and that a failed bootstrap still releases.
///
/// Widget tests run fake timers, so every startup future is started without
/// awaiting and driven with `pump` until it completes.
void main() {
  // MethodChannel needs a binding; the real app gets it from runApp.
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('qflistudio/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Non-zero but short: the real `Future.delayed` path without a second each.
  const minimum = Duration(milliseconds: 40);
  const settle = Duration(milliseconds: 1);
  const subscribe = Duration(milliseconds: 10);

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'condition not reached');
  }

  /// Runs [future] to completion under pumped fake time, capturing its error.
  Future<Object?> settleStartup(
    WidgetTester tester,
    Future<void> future,
  ) async {
    var done = false;
    Object? error;
    unawaited(
      future.then((_) => done = true, onError: (Object e) {
        error = e;
        done = true;
      }),
    );
    await pumpUntil(tester, () => done);
    return error;
  }

  void mockProgress(List<MethodCall> calls) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('holds the first frame until the ready home is laid out', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    mockProgress(calls);
    final startup = OhosStartup(binding: tester.binding);
    final loading = Completer<void>();
    final ready = ValueNotifier<bool>(false);

    startup.holdFirstFrame();
    final completion = startup.complete((reportProgress) async {
      reportProgress(1 / 3);
      await loading.future;
      reportProgress(2 / 3);
      ready.value = true;
    }, minimum: minimum, settle: settle, subscribe: subscribe);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (_, value, _) => Text(value ? 'Home' : 'Loading'),
        ),
      ),
    );

    // Data is still loading: no frame reaches the engine, so the native splash
    // stays on top and the fallback splash never appears.
    expect(tester.binding.sendFramesToEngine, isFalse);
    expect(find.text('Home'), findsNothing);

    // Initial and bootstrap progress use the shared platform channel.
    await pumpUntil(
      tester,
      () => calls.any((call) => (call.arguments as Map)['progress'] == 1 / 3),
    );
    expect(calls.first.method, 'startupProgress');
    expect(calls.first.arguments, {'progress': 0.05});

    // Home builds, but the frame is still held.
    loading.complete();
    await pumpUntil(tester, () => find.text('Home').evaluate().isNotEmpty);
    expect(tester.binding.sendFramesToEngine, isFalse);

    await settleStartup(tester, completion);
    expect(tester.binding.sendFramesToEngine, isTrue);
    final values = calls
        .map((call) => (call.arguments as Map)['progress'] as double)
        .toList();
    expect(values, containsAllInOrder([0.05, 1 / 3, 2 / 3]));
    expect(values.every((value) => value >= 0 && value <= 1), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    ready.dispose();
  });

  testWidgets('releases the first frame if bootstrap fails', (tester) async {
    mockProgress(<MethodCall>[]);
    final startup = OhosStartup(binding: tester.binding);
    startup.holdFirstFrame();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.sendFramesToEngine, isFalse);

    final completion = startup.complete(
      (_) async => throw StateError('load failed'),
      minimum: minimum,
      settle: settle,
      subscribe: subscribe,
    );
    final error = await settleStartup(tester, completion);
    expect(error, isStateError);
    expect(tester.binding.sendFramesToEngine, isTrue);
    // Fake time does not advance the Stopwatch, so the remaining floor is still
    // awaited; pump past it so no timer is left pending.
    await tester.pump(subscribe + minimum + settle);
  });

  testWidgets('startup completes when progress cannot be delivered', (
    tester,
  ) async {
    for (final missing in [true, false]) {
      final startup = OhosStartup(binding: tester.binding);
      startup.holdFirstFrame();
      if (!missing) {
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
      }
      var loaded = false;
      await settleStartup(
        tester,
        startup.complete((reportProgress) async {
          reportProgress(0.5);
          reportProgress(1);
          loaded = true;
        }, minimum: minimum, settle: settle, subscribe: subscribe),
      );
      expect(loaded, isTrue);
      expect(tester.binding.sendFramesToEngine, isTrue);
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('drops non-finite progress and clamps the rest', (tester) async {
    final calls = <MethodCall>[];
    mockProgress(calls);
    final startup = OhosStartup(binding: tester.binding);
    startup.holdFirstFrame();
    // Out-of-range values are clamped instead of raising INVALID_PROGRESS, and a
    // non-finite value is dropped rather than sent.
    await settleStartup(
      tester,
      startup.complete((reportProgress) async {
        reportProgress(double.nan);
        reportProgress(-0.5);
        reportProgress(1.5);
      }, minimum: minimum, settle: settle, subscribe: subscribe),
    );
    final values = calls
        .map((call) => (call.arguments as Map)['progress'] as double)
        .toList();
    expect(values, [0.05, 0.0, 1.0]);
  });
}
