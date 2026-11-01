import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/terminal/shell/command_parser.dart';
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';

import 'native_clang_runner.dart';

/// QFLIForge's terminal hook for the shared in-app terminal.
///
/// The editor's Run button and this delegate both reach the same signed
/// in-process LLVM/WASI backend, but through two different channel methods:
/// Run uses `start` (compile the project entry and execute it), while the
/// terminal uses `terminalStart` (run one explicit command line). Splitting the
/// methods keeps the existing Run contract untouched.
///
/// Exactly one surface is claimed per platform:
///
///   * **OHOS** — a real `clang` / `clang++` command, or an already-built
///     project program (`./program`), is forwarded verbatim to the ArkTS
///     `terminalStart` bridge, which compiles/runs it with the packaged
///     toolchain. stdout, stderr, the numeric exit status and cancellation are
///     the native backend's own.
///   * **Desktop / Android / iOS** — returns `false`, so the desktop real shell
///     keeps owning `clang`, and a mobile sandbox without the OHOS bridge
///     reports its own honest "unsupported" message instead of a fabricated
///     version or a fake success.
///
/// The delegate deliberately refuses anything it cannot faithfully execute:
/// compound shell lines (pipes, redirection, chaining, globs) and malformed
/// quoting are not claimed, so [SandboxShellBackend] keeps its own honest
/// construct diagnostics rather than mis-reading `clang a.c > log` as one
/// compiler invocation with a `>` operand.
Future<bool> forgeTerminalCommandDelegate(
  SandboxShellBackend backend,
  String command,
) => ForgeTerminalDelegate().handle(backend, command);

/// The delegate implementation, split out so tests can inject a channel, an
/// event stream and the platform predicate instead of reading the host OS.
class ForgeTerminalDelegate {
  ForgeTerminalDelegate({
    MethodChannel? channel,
    Stream<Object?>? events,
    bool? isOhos,
    Future<bool> Function()? programExists,
    this.cancellationTimeout,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _events = events ?? NativeClangRunner.sharedEvents,
       _isOhos = isOhos ?? _hostIsOhos,
       _programExists = programExists;

  /// Channel shared with the editor Run path, so both address one native bridge.
  static const String _channelName = 'qfli_forge/native';

  static const Set<String> _compilers = {'clang', 'clang++'};

  final MethodChannel _channel;
  final Stream<Object?> _events;
  final bool _isOhos;

  /// Optional override used by tests to decide whether a `./program` operand
  /// exists. Production probes the real filesystem.
  final Future<bool> Function()? _programExists;

  /// How long cancel waits for the native terminal exit event. Null waits
  /// without a timeout, matching the editor runner's default.
  final Duration? cancellationTimeout;

  static bool get _hostIsOhos {
    final os = Platform.operatingSystem;
    return os == 'ohos' || os == 'harmony';
  }

  Future<bool> handle(
    SandboxShellBackend backend,
    String command,
  ) async {
    if (!_isOhos) return false;
    // Match the sandbox's own policy (a backslash is a Windows path separator,
    // never an escape) so classification and tokenization cannot disagree.
    const policy = EscapePolicy.backslashLiteral;
    if (CommandParser.classify(command, escapePolicy: policy) !=
        CommandSyntax.simple) {
      // Compound lines need a real shell. Returning false lets the sandbox
      // report the exact missing construct (pipe/redirect/glob/...).
      return false;
    }
    final parsed = CommandParser.tokenize(command, escapePolicy: policy);
    if (!parsed.ok || parsed.tokens.isEmpty) return false;
    final tokens = parsed.tokens.map((token) => token.text).toList();
    final tool = tokens.first;
    final bool isCompiler = _compilers.contains(tool);
    final bool isProgram = !isCompiler && await _isProjectProgram(backend, tool);
    if (!isCompiler && !isProgram) return false;

    // A compiler run compiles sources; a program run executes an existing
    // module. Both use the identical payload plus the native `command` string,
    // so the ArkTS bridge can keep one code path.
    await _runThroughBridge(
      backend,
      title: command.trim(),
      command: tool,
      arguments: tokens.sublist(1),
    );
    return true;
  }

  /// Whether [token] names an existing program inside [backend]'s sandbox.
  ///
  /// Only explicit relative paths (`./main`, `../build/main`) are claimed. A
  /// bare `main` is left to the sandbox's ordinary "unsupported" message,
  /// because claiming it would also claim unrelated files (`README`); an
  /// explicit `./` is the documented way to run a built program.
  Future<bool> _isProjectProgram(
    SandboxShellBackend backend,
    String token,
  ) async {
    if (!token.startsWith('./') && !token.startsWith('../')) return false;
    final override = _programExists;
    if (override != null) return override();
    final String resolved;
    try {
      resolved = backend.resolveSandboxPath(token);
    } on SandboxEscapeException {
      return false;
    }
    final type = FileSystemEntity.typeSync(resolved, followLinks: true);
    return type == FileSystemEntityType.file;
  }

  /// Runs one accepted command through `terminalStart` and streams its events.
  Future<void> _runThroughBridge(
    SandboxShellBackend backend, {
    required String title,
    required String command,
    required List<String> arguments,
  }) async {
    final runId = NativeClangRunner.allocateRunId('ohos-term');
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final exitCode = Completer<int>();
    StreamSubscription<Object?>? subscription;
    var accepted = false;
    var cancellationSent = false;

    Future<void> cancelNativeRun() async {
      if (cancellationSent) return;
      cancellationSent = true;
      try {
        await _channel
            .invokeMethod<void>('cancel', {'runId': runId})
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Cancellation is best-effort; the terminal still waits for the exit
        // event (or falls back to a terminal status) so it never hangs.
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
      stderr.add(message);
      finish(kProgramNotRunExitCode);
      if (accepted) unawaited(cancelNativeRun());
    }

    // Subscribe before start: the native backend may emit the first line (or
    // even the terminal exit) before `terminalStart` returns, exactly like the
    // editor Run path. The shared broadcast stream is the same one Run uses, so
    // two listeners never fight over the single EventChannel subscription.
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
              fail('终端通道返回了无效的输出。');
              return;
            }
            (event['kind'] == 'stdout' ? stdout : stderr).add(text);
          case 'exit':
            final code = event['exitCode'];
            if (code is int) {
              finish(code);
            } else {
              fail('终端通道返回了无效的退出状态。');
            }
          default:
            fail('终端通道返回了未知事件。');
        }
      },
      onError: (Object error) => fail('终端通道已断开：$error'),
      onDone: () {
        if (!exitCode.isCompleted) fail('终端通道已关闭。');
      },
    );

    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'terminalStart',
        {
          'runId': runId,
          // The whole sandbox, not the cwd: the native side validates the
          // program/source paths against the project root and never chdirs.
          'projectPath': backend.sandboxRoot,
          'workingDirectory': backend.cwd,
          'command': command,
          'arguments': arguments,
        },
      );
      if (response?['available'] == true) {
        accepted = true;
      } else {
        fail('$command: 当前工具链不可用。');
      }
    } on MissingPluginException {
      unawaited(subscription.cancel());
      unawaited(stdout.close());
      unawaited(stderr.close());
      await backend.runStreams(
        title: title,
        stdout: const Stream<String>.empty(),
        stderr: Stream<String>.value(
          '$command: 当前平台未提供编译终端桥（缺少 native 插件）。',
        ),
        exitCode: Future<int>.value(kProgramNotRunExitCode),
      );
      return;
    } on PlatformException catch (error) {
      accepted = true;
      fail(error.message ?? error.code);
    } catch (error) {
      accepted = true;
      fail('$command: 无法启动终端命令：$error');
    }

    await backend.runStreams(
      title: title,
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exitCode.future,
      cancel: () async {
        if (exitCode.isCompleted) return;
        await cancelNativeRun();
        final timeout = cancellationTimeout;
        try {
          if (timeout == null) {
            await exitCode.future;
          } else {
            await exitCode.future.timeout(timeout);
          }
        } catch (_) {
          finish(130);
        }
      },
    );
  }
}
