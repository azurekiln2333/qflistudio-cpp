import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:qfli_studio_core/services/platform_io.dart';
import 'package:qfli_studio_core/services/platform_path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'run_title.dart';
import 'source_selection.dart';

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(JSString url, JSObject options);
  external set onmessage(JSFunction? callback);
  external set onerror(JSFunction? callback);
  external void postMessage(JSObject data);
  external void terminate();
}

extension type _Message._(JSObject _) implements JSObject {
  external JSAny? get data;
}

@JS('document.baseURI')
external JSString get _baseUri;

class WebClangProgramRunner implements ProgramRunner {
  const WebClangProgramRunner();

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    if (!const [
      '.c',
      '.cpp',
      '.cc',
      '.cxx',
    ].contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final exit = Completer<int>();
    _Worker? worker;
    var finished = false;
    final runId = 'web-${DateTime.now().microsecondsSinceEpoch}';
    Future<void> pendingFiles = Future.value();
    final initialFiles = <String, Uint8List>{};
    final initialDirectories = <String>{};
    final initialText = <String, String?>{};
    var persistenceFailed = false;

    Future<void> finish(int code) async {
      if (finished) return;
      finished = true;
      worker?.terminate();
      worker?.onmessage = null;
      worker?.onerror = null;
      await pendingFiles;
      unawaited(stdout.close());
      unawaited(stderr.close());
      exit.complete(
        code == 130
            ? 130
            : persistenceFailed
            ? kProgramNotRunExitCode
            : code,
      );
    }

    Future<void> saveFiles(List<Object?> files) async {
      try {
        final output = <String, Uint8List>{};
        final outputDirectories = <String>{};
        for (final item in files) {
          if (item is! Map) throw const FormatException('Invalid browser file');
          final name = item['path'];
          final bytes = item['bytes'];
          if (name is! String ||
              p.isAbsolute(name) ||
              name.contains('\\') ||
              name
                  .split('/')
                  .any((part) => part.isEmpty || part == '.' || part == '..')) {
            throw const FormatException('Invalid browser project path');
          }
          if (item['directory'] == true) {
            outputDirectories.add(name);
            continue;
          }
          if (bytes is! Uint8List) {
            throw const FormatException('Invalid browser project bytes');
          }
          if (output.containsKey(name)) {
            throw const FormatException('Duplicate browser file');
          }
          output[name] = bytes;
        }
        // Apply runtime diffs only when the live project still matches its input.
        final changes = <String, Uint8List?>{};
        for (final entry in initialFiles.entries) {
          if (!output.containsKey(entry.key)) changes[entry.key] = null;
        }
        for (final entry in output.entries) {
          final original = initialFiles[entry.key];
          if (original == null || !_same(original, entry.value)) {
            changes[entry.key] = entry.value;
          }
        }
        void checkInitialState(String name) {
          final path = p.join(projectPath, name);
          final original = initialFiles[name];
          final expected = original != null
              ? FileSystemEntityType.file
              : initialDirectories.contains(name)
              ? FileSystemEntityType.directory
              : FileSystemEntityType.notFound;
          if (studioEntityTypeSync(path, followLinks: false) != expected ||
              (original != null &&
                  !_same(studioFile(path).readAsBytesSync(), original))) {
            throw StateError('Project path changed during execution: $name');
          }
        }

        final createdDirectories =
            outputDirectories.difference(initialDirectories).toList()..sort(
              (a, b) => a.split('/').length.compareTo(b.split('/').length),
            );
        final removedDirectories =
            initialDirectories.difference(outputDirectories).toList()..sort(
              (a, b) => b.split('/').length.compareTo(a.split('/').length),
            );
        for (final name in changes.keys) {
          checkInitialState(name);
        }
        for (final name in [...createdDirectories, ...removedDirectories]) {
          checkInitialState(name);
        }

        // Remove old types first; nonrecursive removal protects new editor files.
        for (final entry in changes.entries.where(
          (entry) => entry.value == null,
        )) {
          checkInitialState(entry.key);
          await studioFile(p.join(projectPath, entry.key)).delete();
        }
        for (final directory in removedDirectories) {
          checkInitialState(directory);
          await studioDirectory(p.join(projectPath, directory)).delete();
        }
        for (final directory in createdDirectories) {
          final path = p.join(projectPath, directory);
          final type = studioEntityTypeSync(path, followLinks: false);
          if (type != FileSystemEntityType.notFound &&
              type != FileSystemEntityType.directory) {
            throw StateError(
              'Project path changed during execution: $directory',
            );
          }
          await studioDirectory(path).create(recursive: true);
        }
        for (final entry in changes.entries.where(
          (entry) => entry.value != null,
        )) {
          final file = studioFile(p.join(projectPath, entry.key));
          await file.parent.create(recursive: true);
          if (initialFiles.containsKey(entry.key)) {
            checkInitialState(entry.key);
          } else if (studioEntityTypeSync(file.path, followLinks: false) !=
              FileSystemEntityType.notFound) {
            throw StateError(
              'Project file changed during execution: ${entry.key}',
            );
          }
          await file.writeAsBytes(entry.value!, flush: true);
        }
        await flushStudioStorage();
      } catch (error) {
        persistenceFailed = true;
        stderr.add('Browser project save failed: $error');
      }
    }

    Future<void> start() async {
      try {
        final root = p.normalize(p.absolute(projectPath));
        final absoluteEntry = p.normalize(p.absolute(entryFile));
        if (!p.isWithin(root, absoluteEntry)) {
          throw const FormatException('Entry file is outside the project');
        }
        final files = <Map<String, Object>>[];
        await for (final file in studioDirectory(
          root,
        ).list(recursive: true, followLinks: false)) {
          if (finished) return;
          if (file is File) {
            final name = p.relative(file.path, from: root);
            final bytes = await file.readAsBytes();
            initialFiles[name] = bytes;
            if (isCCppSourcePath(name)) {
              // A decode failure is recorded as null so the file is kept in
              // the compilation set (see _decodeSource).
              initialText[name] = _decodeSource(bytes);
            }
            files.add({'path': name, 'bytes': bytes});
          } else if (file is Directory) {
            final name = p.relative(file.path, from: root);
            initialDirectories.add(name);
            files.add({'path': name, 'directory': true});
          }
        }
        if (finished) return;
        // The worker receives every project file (preopens and writeback stay
        // complete) plus the explicit compilation set: the requested entry and
        // ordinary helpers, without another program's unambiguous `main`.
        final selectedNames = selectRunSources(
          entryFile: p.relative(absoluteEntry, from: root),
          allSources: initialText.keys.toList(),
          readSource: (name) => initialText[name],
        );
        final runtimeUrl = Uri.parse(
          _baseUri.toDart,
        ).resolve('forge-worker.bundle.js');
        worker = _Worker(
          runtimeUrl.toString().toJS,
          {'type': 'module'}.jsify() as JSObject,
        );
        worker!.onmessage = ((_Message message) {
          if (finished) return;
          try {
            final event = message.data.dartify();
            if (event is! Map || event['runId'] != runId) return;
            switch (event['kind']) {
              case 'stdout':
              case 'stderr':
                final text = event['text'];
                if (text is! String) {
                  throw const FormatException('Invalid browser output');
                }
                (event['kind'] == 'stdout' ? stdout : stderr).add(text);
              case 'files':
                final files = event['files'];
                if (files is! List) {
                  throw const FormatException('Invalid browser files');
                }
                pendingFiles = saveFiles(files.cast<Object?>());
              case 'exit':
                final code = event['exitCode'];
                if (code is! int) {
                  throw const FormatException('Invalid browser exit');
                }
                unawaited(finish(code));
              default:
                throw const FormatException('Unknown browser event');
            }
          } catch (error) {
            stderr.add('Browser runtime protocol failed: $error');
            unawaited(finish(kProgramNotRunExitCode));
          }
        }).toJS;
        worker!.onerror = ((JSAny? _) {
          if (finished) return;
          stderr.add('Browser compiler worker failed to load.');
          unawaited(finish(kProgramNotRunExitCode));
        }).toJS;
        worker!.postMessage(
          {
                'runId': runId,
                'entryFile': p.relative(absoluteEntry, from: root),
                'sources': selectedNames,
                'files': files,
              }.jsify()
              as JSObject,
        );
      } catch (error) {
        if (finished) return;
        stderr.add('Browser compiler unavailable: $error');
        await finish(kProgramNotRunExitCode);
      }
    }

    unawaited(start());
    return ProgramRunResult(
      title: runTitle(projectPath: projectPath, entryFile: entryFile),
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exit.future,
      cancel: () => finish(130),
    );
  }
}

/// Strict UTF-8 decode for lexical selection. Returns null when the bytes are
/// not valid UTF-8; `selectRunSources` then keeps the file in the compilation
/// set instead of running a scan over replacement characters.
String? _decodeSource(Uint8List bytes) {
  try {
    return const Utf8Decoder(allowMalformed: false).convert(bytes);
  } on FormatException {
    return null;
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
