import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_terminal_native.dart';
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'interrupt during toolchain preparation reaches the accepted native run',
    () async {
      const channel = MethodChannel('test/forge/terminal/preparation');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final root = Directory.systemTemp.createTempSync(
        'forge-terminal-prepare',
      );
      final events = StreamController<Object?>.broadcast();
      final startSeen = Completer<void>();
      final prepared = Completer<Map<String, Object?>>();
      String? runId;
      var cancelled = false;
      final delegate = ForgeTerminalDelegate(
        channel: channel,
        events: events.stream,
        isOhos: true,
      );
      final backend = SandboxShellBackend(
        sandboxRoot: root.path,
        delegate: delegate.handle,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'terminalStart') {
          runId = (call.arguments as Map)['runId'] as String;
          startSeen.complete();
          return prepared.future;
        }
        if (call.method == 'cancel') {
          cancelled = true;
          events.add({'runId': runId, 'kind': 'exit', 'exitCode': 130});
        }
        return null;
      });
      try {
        final running = backend.execute('clang main.c -o program');
        await startSeen.future;
        await backend.interrupt();
        prepared.complete({'available': true});
        await running.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            events.add({'runId': runId, 'kind': 'exit', 'exitCode': 0});
            throw TimeoutException(
              'The pending interrupt was lost during preparation',
            );
          },
        );
        expect(cancelled, isTrue);
        expect(backend.busy, isFalse);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        await events.close();
        await backend.shutdown();
        root.deleteSync(recursive: true);
      }
    },
  );
}
