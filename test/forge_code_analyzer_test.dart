import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/forge_code_analyzer.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('qfli_forge/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<Object?> events;
  final root = p.absolute('analysis_project');
  final sourcePath = p.join(root, 'main.cpp');
  final headerPath = p.join(root, 'include', 'local.h');
  final calls = <MethodCall>[];

  CodeAnalysisRequest request({
    String source = 'int main(){return 0;}',
    String? header,
    String language = 'cpp',
  }) => CodeAnalysisRequest(
    projectPath: root,
    activeFilePath: sourcePath,
    language: language,
    revision: 7,
    documents: [
      CodeDocumentSnapshot(path: sourcePath, text: source, revision: 7),
      if (header != null)
        CodeDocumentSnapshot(path: headerPath, text: header, revision: 3),
    ],
  );

  Map<String, Object> row(
    String path,
    int start,
    int end, {
    String severity = 'error',
  }) => {
    'filePath': path,
    'startByte': start,
    'endByte': end,
    'message': 'actual compiler diagnostic',
    'severity': severity,
    'code': '1234',
  };

  void reply(
    MethodCall call,
    List<Object> diagnostics, {
    bool unmapped = false,
    int code = 0,
  }) {
    final runId = (call.arguments as Map)['runId'];
    final text = jsonEncode({
      'diagnostics': diagnostics,
      'unmappedErrors': unmapped,
    });
    // Ignore another consumer; accept split structured output and early exit.
    events.add({'runId': 'another-run', 'kind': 'stdout', 'text': 'not JSON'});
    events.add({
      'runId': runId,
      'kind': 'stdout',
      'text': text.substring(0, text.length ~/ 2),
    });
    events.add({
      'runId': runId,
      'kind': 'stdout',
      'text': text.substring(text.length ~/ 2),
    });
    events.add({'runId': runId, 'kind': 'exit', 'exitCode': code});
  }

  setUp(() {
    calls.clear();
    events = StreamController<Object?>.broadcast(sync: true);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await events.close();
  });

  ForgeCodeAnalyzer analyzer({
    Duration timeout = const Duration(seconds: 30),
  }) => ForgeCodeAnalyzer(
    channel: channel,
    events: events.stream,
    timeout: timeout,
  );

  test(
    'sends exact unsaved snapshots and maps CRLF Unicode UTF8 byte ranges',
    () async {
      const source = '// 中文😀\r\nint main(){return unknown;}\r\n';
      const header = '// 头😀\r\nint value = missing;\r\n';
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final start = utf8
            .encode(source.substring(0, source.indexOf('unknown')))
            .length;
        final other = utf8
            .encode(header.substring(0, header.indexOf('missing')))
            .length;
        reply(call, [
          row(sourcePath, start, start + 7),
          row(headerPath, other, other + 7, severity: 'warning'),
        ], code: 1);
        return {'available': true};
      });
      final result = await analyzer().analyze(
        request(source: source, header: header),
      );
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics, hasLength(2));
      expect(result.diagnostics.first.startOffset, source.indexOf('unknown'));
      expect(result.diagnostics.first.endOffset, source.indexOf('unknown') + 7);
      expect(result.diagnostics.last.filePath, headerPath);
      expect(result.diagnostics.last.startOffset, header.indexOf('missing'));
      expect(result.diagnostics.last.severity, CodeDiagnosticSeverity.warning);
      expect(calls.single.method, 'analyzeStart');
      final payload = calls.single.arguments as Map;
      expect(payload['language'], 'cpp');
      expect(payload['documents'], [
        {'path': sourcePath, 'text': source},
        {'path': headerPath, 'text': header},
      ]);
    },
  );

  test(
    'astral token and CRLF EOF insertion retain exact UTF16 endpoints',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        reply(call, [row(sourcePath, 0, 4), row(sourcePath, 6, 6)], code: 1);
        return {'available': true};
      });
      final result = await analyzer().analyze(request(source: '😀\r\n'));
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics.first.startOffset, 0);
      expect(result.diagnostics.first.endOffset, 2);
      expect(result.diagnostics.last.startOffset, 4);
      expect(result.diagnostics.last.endOffset, 4);
    },
  );

  test(
    'unrelated open project documents do not disable C and C++ analysis',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        reply(call, []);
        return {'available': true};
      });
      final original = request();
      final result = await analyzer().analyze(
        CodeAnalysisRequest(
          projectPath: root,
          activeFilePath: sourcePath,
          language: 'cpp',
          revision: 7,
          documents: [
            ...original.documents,
            CodeDocumentSnapshot(
              path: p.join(root, 'README.md'),
              text: '# Project',
              revision: 2,
            ),
          ],
        ),
      );
      expect(result.unavailableReason, isNull);
      expect((calls.single.arguments as Map)['documents'], [
        {'path': sourcePath, 'text': original.documents.single.text},
      ]);
    },
  );

  test(
    'empty diagnostics are clean only after an actual successful check',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        reply(call, []);
        return {'available': true};
      });
      final result = await analyzer().analyze(request());
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'unmapped closed-file errors remain unavailable with mapped diagnostics',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        reply(
          call,
          [row(sourcePath, 0, 3, severity: 'info')],
          unmapped: true,
          code: 1,
        );
        return {'available': true};
      });
      final result = await analyzer().analyze(request());
      expect(result.unavailableReason, isNotNull);
      expect(
        result.diagnostics.single.severity,
        CodeDiagnosticSeverity.information,
      );
    },
  );

  for (final type in [
    'middle-byte',
    'foreign',
    'reversed',
    'past-end',
    'failed-without-error',
  ]) {
    test(
      'invalid native diagnostics cannot claim a clean result: $type',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          final rows = switch (type) {
            'middle-byte' => [row(sourcePath, 1, 2)],
            'foreign' => [row(p.join(p.dirname(root), 'foreign.cpp'), 0, 1)],
            'reversed' => [row(sourcePath, 5, 2)],
            'past-end' => [row(sourcePath, 999, 1000)],
            _ => <Object>[],
          };
          reply(call, rows, code: type == 'failed-without-error' ? 1 : 0);
          return {'available': true};
        });
        final result = await analyzer().analyze(request(source: '😀;\r\n'));
        expect(result.unavailableReason, isNotNull);
      },
    );
  }

  test(
    'invalid UTF16, language and outside-root documents never reach native',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      for (final input in [
        request(source: String.fromCharCode(0xd800)),
        request(language: 'dart'),
        CodeAnalysisRequest(
          projectPath: root,
          activeFilePath: sourcePath,
          language: 'cpp',
          revision: 1,
          documents: [
            CodeDocumentSnapshot(
              path: p.join(p.dirname(root), 'escape.cpp'),
              text: '',
              revision: 1,
            ),
          ],
        ),
      ]) {
        expect((await analyzer().analyze(input)).unavailableReason, isNotNull);
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'missing native method, unavailable backend and busy slot are distinct from clean',
    () async {
      for (final mode in ['missing', 'unavailable', 'busy']) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (mode == 'missing') throw MissingPluginException();
          if (mode == 'busy') {
            throw PlatformException(
              code: 'runner_busy',
              message: 'toolchain busy',
            );
          }
          return {'available': false};
        });
        final result = await analyzer().analyze(request());
        expect(result.unavailableReason, isNotNull);
        expect(result.diagnostics, isEmpty);
      }
    },
  );

  test(
    'timeout requests cancellation and waits for real cleanup exit',
    () async {
      Object? runId;
      var completed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        runId = (call.arguments as Map)['runId'];
        return call.method == 'analyzeStart' ? {'available': true} : null;
      });
      final pending = analyzer(timeout: const Duration(milliseconds: 50))
          .analyze(request())
          .then((result) {
            completed = true;
            return result;
          });
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(calls.map((call) => call.method), ['analyzeStart', 'cancel']);
      expect(completed, isFalse);
      events.add({'runId': runId, 'kind': 'exit', 'exitCode': 130});
      expect((await pending).unavailableReason, isNotNull);
    },
  );
}
