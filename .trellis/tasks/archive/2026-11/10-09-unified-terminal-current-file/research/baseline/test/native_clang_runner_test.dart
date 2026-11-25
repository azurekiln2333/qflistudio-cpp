import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/native_clang_runner.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/forge/ios');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<Object?> events;
  late NativeClangRunner runner;

  setUp(() {
    events = StreamController<Object?>.broadcast();
    runner = NativeClangRunner(
      channel: channel,
      events: events.stream,
      backendName: 'iOS Clang/WASI',
      runIdPrefix: 'ios',
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await events.close();
  });

  Future<ProgramRunResult> start(String type) async => (await runner.run(
    type: type,
    projectPath: '/projects/example',
    entryFile: '/projects/example/main.$type',
  ))!;

  test(
    'missing iOS toolchain reports failure for both source families',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'available': false},
      );
      for (final type in ['c', 'cpp']) {
        final result = await start(type);
        expect(await result.exitCode, kProgramNotRunExitCode);
        expect(await result.stdout.toList(), isEmpty);
        expect(await result.stderr.toList(), isNotEmpty);
      }
    },
  );

  test('iOS captures early diagnostics and retains accepted failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final runId = (call.arguments as Map)['runId'] as String;
      expect(runId, startsWith('ios-'));
      events.add({
        'runId': runId,
        'kind': 'stderr',
        'text': 'undefined symbol',
      });
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 1});
      await Future<void>.delayed(Duration.zero);
      return {'available': true};
    });
    final result = await start('c');
    expect(result.title, contains('iOS Clang/WASI'));
    expect(await result.exitCode, 1);
    expect(await result.stdout.toList(), isEmpty);
    expect(await result.stderr.toList(), ['undefined symbol']);
  });

  test('iOS cancel retains prior output and addresses its own run', () async {
    String? started;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final runId = (call.arguments as Map)['runId'] as String;
      if (call.method == 'start') {
        started = runId;
        return {'available': true};
      }
      expect(call.method, 'cancel');
      expect(runId, started);
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 130});
      return null;
    });
    final result = await start('cpp');
    events.add({'runId': started, 'kind': 'stdout', 'text': 'ready'});
    await result.cancel!();
    expect(await result.exitCode, 130);
    expect(await result.stdout.toList(), ['ready']);
    expect(await result.stderr.toList(), isEmpty);
  });

  testWidgets('iOS cancellation waits for the native cleanup event', (
    tester,
  ) async {
    String? runId;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        runId = (call.arguments as Map)['runId'] as String;
        return {'available': true};
      }
      return null;
    });
    final result = await start('cpp');
    var finished = false;
    final stopped = result.cancel!().then((_) => finished = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(finished, isFalse);
    events.add({'runId': runId, 'kind': 'stdout', 'text': 'drained'});
    events.add({'runId': runId, 'kind': 'exit', 'exitCode': 130});
    await tester.pump();
    await stopped;
    expect(await result.exitCode, 130);
    expect(await result.stdout.toList(), ['drained']);
    expect(await result.stderr.toList(), isEmpty);
  });
}
