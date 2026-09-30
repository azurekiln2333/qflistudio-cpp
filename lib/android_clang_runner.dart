import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Streams one Android compilation/run through the packaged native executor.
class AndroidClangRunner {
  AndroidClangRunner({
    MethodChannel channel = const MethodChannel('qfli_forge/native'),
    Stream<Object?>? events,
  }) : _channel = channel,
       _events = events ?? _sharedEvents;

  static final Stream<Object?> _sharedEvents = const EventChannel(
    'qfli_forge/native/events',
  ).receiveBroadcastStream();
  static int _nextRunId = 0;

  final MethodChannel _channel;
  final Stream<Object?> _events;

  Future<ProgramRunResult?> run({
    required String type,
    required String projectPath,
    required String entryFile,
  }) async {
    final runId = 'android-${++_nextRunId}';
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final exitCode = Completer<int>();
    StreamSubscription<Object?>? subscription;
    var accepted = false;
    var failed = false;
    var cancellationSent = false;

    Future<void> cancelNativeRun() async {
      if (cancellationSent) return;
      cancellationSent = true;
      try {
        await _channel
            .invokeMethod<void>('cancel', {'runId': runId})
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // The output channel can fail independently of native cleanup.
      }
    }

    void finish(int code) {
      if (exitCode.isCompleted) return;
      exitCode.complete(code);
      unawaited(subscription?.cancel());
      unawaited(stdout.close());
      unawaited(stderr.close());
    }

    void fail(String message) {
      if (exitCode.isCompleted) return;
      failed = true;
      stderr.add(message);
      finish(kProgramNotRunExitCode);
      if (accepted) unawaited(cancelNativeRun());
    }

    subscription = _events.listen(
      (event) {
        if (event is! Map || event['runId'] != runId || exitCode.isCompleted) {
          return;
        }
        switch (event['kind']) {
          case 'stdout':
          case 'stderr':
            final text = event['text'];
            if (text is! String) {
              fail('编译运行通道返回了无效的输出。');
              return;
            }
            (event['kind'] == 'stdout' ? stdout : stderr).add(text);
          case 'exit':
            final code = event['exitCode'];
            if (code is int) {
              finish(code);
            } else {
              fail('编译运行通道返回了无效的退出状态。');
            }
          default:
            fail('编译运行通道返回了未知事件。');
        }
      },
      onError: (Object error) => fail('编译运行通道已断开：$error'),
      onDone: () {
        if (!exitCode.isCompleted) fail('编译运行通道已关闭。');
      },
    );
    if (exitCode.isCompleted) unawaited(subscription.cancel());

    var unavailable = false;
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'start',
        {
          'runId': runId,
          'type': type,
          'projectPath': projectPath,
          'entryFile': entryFile,
        },
      );
      if (response?['available'] == false) {
        unavailable = true;
      } else {
        accepted = true;
        if (response?['available'] != true) {
          fail('无法确认 C/C++ 编译工具链状态。');
        }
        if (failed) unawaited(cancelNativeRun());
      }
    } on MissingPluginException {
      unavailable = true;
    } on PlatformException catch (error) {
      accepted = true;
      fail(error.message ?? error.code);
    } catch (error) {
      accepted = true;
      fail('无法启动编译运行：$error');
    }

    if (unavailable) {
      if (type == 'c') {
        finish(kProgramNotRunExitCode);
        return null;
      }
      fail('无法加载 C++ 编译工具链。');
    }

    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（Android Clang $type）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exitCode.future,
      cancel: () async {
        if (exitCode.isCompleted) return;
        try {
          await cancelNativeRun();
          await exitCode.future.timeout(const Duration(seconds: 5));
        } catch (_) {
          finish(130);
        }
      },
    );
  }
}
