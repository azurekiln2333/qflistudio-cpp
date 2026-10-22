import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/code_analysis.dart';

import 'native_clang_runner.dart';

/// The packaged Clang syntax/type checker. This never invokes the Run method.
/// Platforms without the dedicated native method report unavailable explicitly.
class ForgeCodeAnalyzer implements CodeAnalyzer {
  ForgeCodeAnalyzer({
    MethodChannel channel = const MethodChannel('qfli_forge/native'),
    Stream<Object?>? events,
    this.timeout = const Duration(seconds: 30),
  }) : _channel = channel,
       _events = events ?? NativeClangRunner.sharedEvents;

  final MethodChannel _channel;
  final Stream<Object?> _events;
  final Duration timeout;

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) async {
    final documents = <String, CodeDocumentSnapshot>{};
    try {
      if (!{'c', 'cpp'}.contains(request.language) ||
          !p.isAbsolute(request.projectPath) ||
          request.documents.isEmpty ||
          request.documents.length > 64) {
        throw const FormatException('不支持的 C/C++ 语法检查请求。');
      }
      var units = 0;
      for (final document in request.documents) {
        final path = p.canonicalize(document.path);
        if (!p.isAbsolute(document.path) ||
            !p.isWithin(request.projectPath, document.path) ||
            documents.containsKey(path) ||
            document.text.contains('\u0000')) {
          throw const FormatException('语法检查文档路径或内容无效。');
        }
        if (!{
          '.c',
          '.cpp',
          '.cc',
          '.cxx',
          '.h',
          '.hpp',
          '.hh',
          '.hxx',
          '.inl',
        }.contains(p.extension(document.path).toLowerCase())) {
          continue;
        }
        units += document.text.length;
        if (units > 4 * 1024 * 1024) {
          throw const FormatException('语法检查文档超过大小限制。');
        }
        _byteBoundaries(document.text, const {});
        documents[path] = document;
      }
      if (!documents.containsKey(p.canonicalize(request.activeFilePath))) {
        throw const FormatException('语法检查缺少当前未保存文档。');
      }
    } on FormatException catch (error) {
      return CodeAnalysisResult(unavailableReason: error.message);
    }

    final runId = NativeClangRunner.allocateRunId('ohos-analysis');
    final output = StringBuffer();
    final errors = StringBuffer();
    final exit = Completer<int>();
    var timedOut = false;
    var cancelled = false;
    String? protocolError;
    Future<void> cancel() async {
      if (cancelled) return;
      cancelled = true;
      try {
        await _channel.invokeMethod<void>('cancel', {'runId': runId});
      } on Object {
        // The shared native slot remains occupied until its real cleanup event.
      }
    }

    final subscription = _events.listen(
      (event) {
        if (event is! Map || event['runId'] != runId || exit.isCompleted) {
          return;
        }
        switch (event['kind']) {
          case 'stdout':
          case 'stderr':
            final text = event['text'];
            final target = event['kind'] == 'stdout' ? output : errors;
            if (text is! String ||
                target.length + text.length > 8 * 1024 * 1024) {
              protocolError = '语法检查返回了无效或过大的结果。';
              unawaited(cancel());
            } else {
              target.write(text);
            }
          case 'exit':
            final code = event['exitCode'];
            if (code is int) {
              exit.complete(code);
            } else {
              protocolError = '语法检查退出状态无效。';
              unawaited(cancel());
            }
          default:
            protocolError = '语法检查通道返回了未知事件。';
            unawaited(cancel());
        }
      },
      onError: (Object error) {
        protocolError = '语法检查通道已断开：$error';
        unawaited(cancel());
        if (!exit.isCompleted) exit.complete(127);
      },
      onDone: () {
        if (!exit.isCompleted) {
          protocolError = '语法检查通道已关闭。';
          unawaited(cancel());
          exit.complete(127);
        }
      },
    );
    final timer = Timer(timeout, () {
      timedOut = true;
      unawaited(cancel());
    });
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'analyzeStart',
        {
          'runId': runId,
          'projectPath': request.projectPath,
          'activeFilePath': request.activeFilePath,
          'language': request.language,
          'documents': [
            for (final document in documents.values)
              {'path': document.path, 'text': document.text},
          ],
        },
      );
      if (response?['available'] != true) {
        return const CodeAnalysisResult(
          unavailableReason: '当前未提供离线 Clang 语法检查工具链。',
        );
      }
      final code = await exit.future;
      if (timedOut || code == 130) {
        return const CodeAnalysisResult(unavailableReason: '语法检查已超时或取消。');
      }
      if (protocolError != null) {
        return CodeAnalysisResult(unavailableReason: protocolError);
      }
      if (code != 0 && code != 1) {
        return CodeAnalysisResult(
          unavailableReason: errors.isEmpty
              ? 'Clang 语法检查未完成（$code）。'
              : errors.toString(),
        );
      }
      return _decode(output.toString(), documents, code);
    } on MissingPluginException {
      return const CodeAnalysisResult(
        unavailableReason: '当前平台未提供离线 Clang 语法检查桥。',
      );
    } on PlatformException catch (error) {
      return CodeAnalysisResult(unavailableReason: error.message ?? error.code);
    } on Object catch (error) {
      return CodeAnalysisResult(unavailableReason: '无法完成 Clang 语法检查：$error');
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  CodeAnalysisResult _decode(
    String output,
    Map<String, CodeDocumentSnapshot> documents,
    int code,
  ) {
    final decoded = jsonDecode(output);
    if (decoded is! Map ||
        decoded['diagnostics'] is! List ||
        decoded['unmappedErrors'] is! bool) {
      throw const FormatException('Clang 诊断格式无效。');
    }
    final raw = decoded['diagnostics'] as List;
    if (raw.length > 1000) throw const FormatException('Clang 诊断数量超过限制。');
    final offsets = <String, Set<int>>{};
    for (final item in raw) {
      if (item is! Map ||
          item['filePath'] is! String ||
          item['startByte'] is! int ||
          item['endByte'] is! int ||
          item['message'] is! String ||
          item['code'] is! String ||
          !{'error', 'warning', 'info'}.contains(item['severity'])) {
        throw const FormatException('Clang 诊断字段无效。');
      }
      final path = p.canonicalize(item['filePath'] as String);
      if (!documents.containsKey(path) ||
          (item['startByte'] as int) < 0 ||
          (item['endByte'] as int) < (item['startByte'] as int)) {
        throw const FormatException('Clang 诊断不属于此次未保存快照。');
      }
      offsets.putIfAbsent(path, () => {}).addAll([
        item['startByte'] as int,
        item['endByte'] as int,
      ]);
    }
    final boundaries = {
      for (final entry in offsets.entries)
        entry.key: _byteBoundaries(documents[entry.key]!.text, entry.value),
    };
    final diagnostics = <CodeDiagnostic>[];
    for (final item in raw) {
      final path = p.canonicalize(item['filePath'] as String);
      final start = boundaries[path]![item['startByte']];
      final end = boundaries[path]![item['endByte']];
      if (start == null || end == null) {
        throw const FormatException('Clang 诊断位置越界或落在 UTF-8 字符中间。');
      }
      diagnostics.add(
        CodeDiagnostic(
          filePath: documents[path]!.path,
          startOffset: start,
          endOffset: end,
          message: item['message'] as String,
          severity: switch (item['severity']) {
            'error' => CodeDiagnosticSeverity.error,
            'warning' => CodeDiagnosticSeverity.warning,
            _ => CodeDiagnosticSeverity.information,
          },
          source: 'Clang C17/C++20',
          code: item['code'] as String,
        ),
      );
    }
    final unmapped = decoded['unmappedErrors'] as bool;
    if (code == 1 &&
        !unmapped &&
        !diagnostics.any(
          (item) => item.severity == CodeDiagnosticSeverity.error,
        )) {
      throw const FormatException('Clang 检查失败但未提供错误位置。');
    }
    return CodeAnalysisResult(
      diagnostics: diagnostics,
      unavailableReason: unmapped ? '部分错误来自未打开的文件或诊断超过限制；请打开相关头文件后重新检查。' : null,
    );
  }
}

/// Scan once per document, retaining only requested UTF-8 boundaries. This avoids
/// allocating a byte-sized map for every character in a large editor buffer.
Map<int, int> _byteBoundaries(String text, Set<int> requested) {
  final result = <int, int>{};
  var byte = 0;
  for (var unit = 0; unit < text.length; unit++) {
    if (requested.contains(byte)) result[byte] = unit;
    final value = text.codeUnitAt(unit);
    if (value >= 0xd800 && value <= 0xdbff) {
      if (unit + 1 == text.length ||
          text.codeUnitAt(unit + 1) < 0xdc00 ||
          text.codeUnitAt(unit + 1) > 0xdfff) {
        throw const FormatException('语法检查文档含无效 UTF-16 字符。');
      }
      unit++;
      byte += 4;
    } else if (value >= 0xdc00 && value <= 0xdfff) {
      throw const FormatException('语法检查文档含无效 UTF-16 字符。');
    } else {
      byte += value < 0x80
          ? 1
          : value < 0x800
          ? 2
          : 3;
    }
  }
  if (requested.contains(byte)) result[byte] = text.length;
  return result;
}
