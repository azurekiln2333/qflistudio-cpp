import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_terminal_native.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';
import 'package:qfli_studio_core/terminal/shell/shell_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/forge/terminal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory sandbox;
  late StreamController<Object?> events;
  late SandboxShellBackend backend;
  late List<String> stdout;
  late List<String> stderr;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('forge-terminal');
    File('${sandbox.path}/main.c').writeAsStringSync('int main(){return 0;}');
    events = StreamController<Object?>.broadcast();
    backend = SandboxShellBackend(sandboxRoot: sandbox.path);
    stdout = <String>[];
    stderr = <String>[];
    backend.output.listen((chunk) {
      (chunk.kind == OutputKind.stdout ? stdout : stderr).add(chunk.text);
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await events.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  ForgeTerminalDelegate delegate({bool isOhos = true}) => ForgeTerminalDelegate(
    channel: channel,
    events: events.stream,
    isOhos: isOhos,
    cancellationTimeout: const Duration(seconds: 1),
  );

  test('non-OHOS platforms keep the desktop shell fallback', () async {
    final handled = await delegate(isOhos: false).handle(
      backend,
      'clang --version',
    );
    expect(handled, isFalse);
  });

  test('forwards clang with the sandbox root and cwd payload', () async {
    Map<Object?, Object?>? payload;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'terminalStart') {
        payload = call.arguments as Map<Object?, Object?>;
        final runId = payload!['runId'] as String;
        events.add({'runId': runId, 'kind': 'stdout', 'text': 'clang 22.1.0'});
        events.add({'runId': runId, 'kind': 'exit', 'exitCode': 0});
        return {'available': true};
      }
      return null;
    });
    expect(await delegate().handle(backend, 'clang --version'), isTrue);
    expect(payload!['command'], 'clang');
    expect(payload!['arguments'], ['--version']);
    expect(payload!['projectPath'], backend.sandboxRoot);
    expect(payload!['workingDirectory'], backend.cwd);
    expect(payload!['runId'], startsWith('ohos-term-'));
    expect(backend.lastExitCode, 0);
  });

  test('tokenizes a quoted source path into one argument', () async {
    Map<Object?, Object?>? payload;
    messenger.setMockMethodCallHandler(channel, (call) async {
      payload = call.arguments as Map<Object?, Object?>;
      final runId = payload!['runId'] as String;
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 0});
      return {'available': true};
    });
    expect(
      await delegate().handle(
        backend,
        'clang++ -std=c++20 "my dir/main file.cpp" -o prog',
      ),
      isTrue,
    );
    expect(payload!['command'], 'clang++');
    expect(payload!['arguments'], [
      '-std=c++20',
      'my dir/main file.cpp',
      '-o',
      'prog',
    ]);
  });

  test('rejects compound shell syntax instead of mis-parsing it', () async {
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return {'available': true};
    });
    for (final command in [
      'clang main.c > log',
      'clang main.c | grep error',
      'clang main.c && ./a.out',
      'clang *.c',
      'clang main.c; ./a.out',
    ]) {
      expect(await delegate().handle(backend, command), isFalse,
          reason: command);
    }
    expect(invoked, isFalse);
  });

  test('rejects malformed quoting without invoking the bridge', () async {
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return {'available': true};
    });
    expect(await delegate().handle(backend, 'clang "unterminated'), isFalse);
    expect(invoked, isFalse);
  });

  test('does not claim unrelated or bare program names', () async {
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return {'available': true};
    });
    expect(await delegate().handle(backend, 'main'), isFalse);
    expect(await delegate().handle(backend, 'ls -la'), isFalse);
    expect(invoked, isFalse);
  });

  test('streams stdout/stderr and preserves a nonzero exit code', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final runId = (call.arguments as Map)['runId'] as String;
      events.add({'runId': runId, 'kind': 'stdout', 'text': 'compiling'});
      events.add({'runId': runId, 'kind': 'stderr', 'text': 'error: boom'});
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 1});
      return {'available': true};
    });
    expect(await delegate().handle(backend, 'clang main.c -o prog'), isTrue);
    expect(stdout, ['compiling\n']);
    expect(stderr, ['error: boom\n']);
    expect(backend.lastExitCode, 1);
  });

  test('reports unavailable honestly and does not run a program', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'available': false},
    );
    expect(await delegate().handle(backend, 'clang --version'), isTrue);
    expect(stdout, isEmpty);
    expect(stderr, isNotEmpty);
    expect(backend.lastExitCode, kProgramNotRunExitCode);
  });

  test('malformed bridge output fails without hanging', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final runId = (call.arguments as Map)['runId'] as String;
      events.add({'runId': runId, 'kind': 'stdout', 'text': 42});
      return {'available': true};
    });
    expect(await delegate().handle(backend, 'clang main.c'), isTrue);
    expect(stderr, isNotEmpty);
    expect(backend.lastExitCode, kProgramNotRunExitCode);
  });

  test('cancellation forwards cancel(runId) and keeps prior output', () async {
    File('${sandbox.path}/prog').writeAsStringSync('wasm');
    String? started;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final runId = (call.arguments as Map)['runId'] as String;
      if (call.method == 'terminalStart') {
        started = runId;
        return {'available': true};
      }
      if (call.method == 'cancel') {
        expect(runId, started);
        events.add({'runId': runId, 'kind': 'stdout', 'text': 'before stop'});
        events.add({'runId': runId, 'kind': 'exit', 'exitCode': 130});
        return null;
      }
      return null;
    });
    final handled = delegate().handle(backend, './prog');
    // The bridge never emits an exit until cancel, so wait until the start
    // request has actually reached the channel.
    for (var i = 0; i < 50 && started == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(started, isNotNull);
    await backend.interrupt();
    expect(await handled, isTrue);
    expect(stdout, contains('before stop\n'));
  });

  test('./program routes only when the file actually exists', () async {
    File('${sandbox.path}/prog').writeAsStringSync('wasm');
    Map<Object?, Object?>? payload;
    messenger.setMockMethodCallHandler(channel, (call) async {
      payload = call.arguments as Map<Object?, Object?>;
      final runId = payload!['runId'] as String;
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 0});
      return {'available': true};
    });
    expect(await delegate().handle(backend, './prog'), isTrue);
    expect(payload!['command'], './prog');
    expect(payload!['arguments'], isEmpty);
    expect(await delegate().handle(backend, './missing'), isFalse);
  });
}
