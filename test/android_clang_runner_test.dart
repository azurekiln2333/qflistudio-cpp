import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/android_clang_runner.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/forge/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<Object?> events;
  late AndroidClangRunner runner;
  late String runId;
  late List<String> cancelledRuns;

  setUp(() {
    events = StreamController<Object?>.broadcast();
    cancelledRuns = [];
    runner = AndroidClangRunner(channel: channel, events: events.stream);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cancelledRuns.add((call.arguments as Map)['runId'] as String);
        return null;
      }
      runId = (call.arguments as Map)['runId'] as String;
      return {'available': true};
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await events.close();
  });

  Future<ProgramRunResult?> start([String type = 'cpp', List<String>? sources]) =>
      runner.run(
        type: type,
        projectPath: '/projects/example',
        entryFile: '/projects/example/main.$type',
        sources: sources,
      );

  void emit(String kind, String key, Object value, {String? id}) {
    events.add({'runId': id ?? runId, 'kind': kind, key: value});
  }

  test(
    'returns before exit and preserves output, blank lines and status',
    () async {
      final result = (await start())!;
      var exited = false;
      unawaited(result.exitCode.then((_) => exited = true));
      await Future<void>.delayed(Duration.zero);
      expect(exited, isFalse);
      final output = result.stdout.toList();
      final errors = result.stderr.toList();
      emit('stdout', 'text', 'ignored', id: 'another-run');
      emit('stdout', 'text', 'ready');
      emit('stdout', 'text', '');
      emit('stderr', 'text', 'diagnostic');
      emit('exit', 'exitCode', 23);
      expect(await result.exitCode, 23);
      expect(await output, ['ready', '']);
      expect(await errors, ['diagnostic']);
      expect(result.title, 'run main.cpp');
    },
  );

  test(
    'accepted C compilation errors do not invoke the interpreter fallback',
    () async {
      final result = await start('c');
      expect(result, isNotNull);
      emit('stderr', 'text', 'main.c:2: error: undeclared identifier');
      emit('exit', 'exitCode', 1);
      expect(await result!.stdout.toList(), isEmpty);
      expect(await result.stderr.toList(), contains(contains('main.c:2')));
      expect(await result.exitCode, 1);
    },
  );

  test('missing toolchain allows only the C fallback', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'available': false},
    );
    expect(await start('c'), isNull);
    final result = (await start())!;
    expect(await result.stderr.toList(), ['无法加载 C++ 编译工具链。']);
    expect(await result.stdout.toList(), isEmpty);
    expect(await result.exitCode, kProgramNotRunExitCode);
  });

  test('missing Android plugin returns unavailable without hanging', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await start('c'), isNull);
    final result = (await start())!;
    expect(await result.stderr.toList(), ['无法加载 C++ 编译工具链。']);
    expect(await result.exitCode, kProgramNotRunExitCode);
  });

  test(
    'cancellation addresses the accepted run and waits for its exit',
    () async {
      String? cancelledId;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final id = (call.arguments as Map)['runId'] as String;
        if (call.method == 'start') {
          runId = id;
          return {'available': true};
        }
        expect(call.method, 'cancel');
        cancelledId = id;
        emit('exit', 'exitCode', 130);
        return null;
      });
      final result = (await start())!;
      await result.cancel!();
      expect(cancelledId, runId);
      expect(await result.exitCode, 130);
      expect(await result.stdout.toList(), isEmpty);
      expect(await result.stderr.toList(), isEmpty);
    },
  );

  test('captures events that arrive before the start reply', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      runId = (call.arguments as Map)['runId'] as String;
      emit('stdout', 'text', 'quick');
      emit('exit', 'exitCode', 0);
      await Future<void>.delayed(Duration.zero);
      return {'available': true};
    });
    final result = (await start())!;
    expect(await result.stdout.toList(), ['quick']);
    expect(await result.stderr.toList(), isEmpty);
    expect(await result.exitCode, 0);
  });

  test('malformed exit produces an error and closes both streams', () async {
    final result = (await start())!;
    emit('exit', 'exitCode', 'success');
    expect(await result.stdout.toList(), isEmpty);
    expect(await result.stderr.toList(), ['编译运行通道返回了无效的退出状态。']);
    expect(await result.exitCode, kProgramNotRunExitCode);
    expect(cancelledRuns, [runId]);
  });

  test('channel failure after acceptance reports a terminal error', () async {
    final result = (await start())!;
    events.addError(PlatformException(code: 'disconnected'));
    expect(await result.exitCode, kProgramNotRunExitCode);
    expect(await result.stdout.toList(), isEmpty);
    expect((await result.stderr.toList()).single, contains('编译运行通道已断开'));
    expect(cancelledRuns, [runId]);
  });

  test(
    'cancels a native run accepted after an early protocol failure',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        final id = (call.arguments as Map)['runId'] as String;
        if (call.method == 'cancel') {
          cancelledRuns.add(id);
          return null;
        }
        runId = id;
        emit('stdout', 'text', 42);
        await Future<void>.delayed(Duration.zero);
        return {'available': true};
      });
      final result = (await start())!;
      expect(await result.exitCode, kProgramNotRunExitCode);
      expect(await result.stdout.toList(), isEmpty);
      expect(await result.stderr.toList(), ['编译运行通道返回了无效的输出。']);
      expect(cancelledRuns, [runId]);
    },
  );

  test(
    'ignores duplicate exit and late output after a terminal event',
    () async {
      final result = (await start())!;
      emit('stdout', 'text', 'last line');
      emit('exit', 'exitCode', 7);
      emit('exit', 'exitCode', 99);
      emit('stderr', 'text', 'late diagnostic');
      emit('stdout', 'text', 42);
      expect(await result.exitCode, 7);
      expect(await result.stdout.toList(), ['last line']);
      expect(await result.stderr.toList(), isEmpty);
      await result.cancel!();
      expect(cancelledRuns, isEmpty);
    },
  );

  test('closed event channel cancels an accepted run', () async {
    final result = (await start())!;
    await events.close();
    expect(await result.exitCode, kProgramNotRunExitCode);
    expect(await result.stdout.toList(), isEmpty);
    expect(await result.stderr.toList(), ['编译运行通道已关闭。']);
    expect(cancelledRuns, [runId]);
  });

  test('invalid start reply fails without C fallback and cleans up', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final id = (call.arguments as Map)['runId'] as String;
      if (call.method == 'cancel') {
        cancelledRuns.add(id);
        return null;
      }
      runId = id;
      return 'invalid reply';
    });
    final result = (await start('c'))!;
    expect(await result.exitCode, kProgramNotRunExitCode);
    expect(await result.stdout.toList(), isEmpty);
    expect((await result.stderr.toList()).single, contains('无法启动编译运行'));
    expect(cancelledRuns, [runId]);
  });

  test('forwards an explicit selected-source list to the Android bridge', () async {
    Map<Object?, Object?>? startArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'start') return null;
      startArguments = call.arguments as Map<Object?, Object?>;
      runId = startArguments!['runId'] as String;
      return {'available': true};
    });
    final result = (await start('c', const [
      '/projects/example/main.c',
      '/projects/example/utils.c',
    ]))!;
    emit('exit', 'exitCode', 0);
    expect(await result.exitCode, 0);
    expect(startArguments!['sources'], const [
      '/projects/example/main.c',
      '/projects/example/utils.c',
    ]);
  });

  test('omits the sources key when no selection is supplied', () async {
    Map<Object?, Object?>? startArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'start') return null;
      startArguments = call.arguments as Map<Object?, Object?>;
      runId = startArguments!['runId'] as String;
      return {'available': true};
    });
    final result = (await start('c'))!;
    emit('exit', 'exitCode', 0);
    expect(await result.exitCode, 0);
    // Absent key = legacy discovery. The Android bridge distinguishes this
    // from an explicit (possibly invalid) selection.
    expect(startArguments!.containsKey('sources'), isFalse);
  });

  test('forwards an explicit empty selection verbatim for rejection', () async {
    Map<Object?, Object?>? startArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'start') return null;
      startArguments = call.arguments as Map<Object?, Object?>;
      runId = startArguments!['runId'] as String;
      return {'available': true};
    });
    final result = (await start('c', const []))!;
    emit('exit', 'exitCode', 0);
    expect(await result.exitCode, 0);
    // An empty list must reach the bridge as an explicit payload, not be
    // dropped: the bridge rejects it instead of rediscovering every file.
    expect(startArguments!.containsKey('sources'), isTrue);
    expect(startArguments!['sources'], isEmpty);
  });
}
