@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/platform_io_browser.dart';
import 'package:qfli_studio_core/services/platform_path.dart' as p;
import 'package:qfli_studio_core/services/project_config.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:web/web.dart' as web;

Future<web.IDBDatabase> _openPeer() async {
  final opened = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(
    'qfli-studio-browser-storage-tests',
    1,
  );
  request.onsuccess = ((web.Event _) => opened.complete(
    request.result as web.IDBDatabase,
  )).toJS;
  request.onerror = ((web.Event _) => opened.completeError(
    StateError('Peer storage connection failed'),
  )).toJS;
  return opened.future;
}

Future<String> _peerSnapshot({String? filePath, String? replacement}) async {
  final database = await _openPeer();
  try {
    final completed = Completer<String>();
    final transaction = database.transaction(
      'filesystem'.toJS,
      filePath == null && replacement == null ? 'readonly' : 'readwrite',
    );
    final store = transaction.objectStore('filesystem');
    final request = store.get('snapshot'.toJS);
    late String encoded;
    request.onsuccess = ((web.Event _) {
      encoded = request.result.dartify() as String;
      if (filePath != null) {
        final snapshot = jsonDecode(encoded) as Map<String, dynamic>;
        snapshot['revision'] = 'peer-${DateTime.now().microsecondsSinceEpoch}';
        (snapshot['entries'] as List).add({
          'path': filePath,
          'bytes': base64Encode(utf8.encode('peer content')),
          'modified': DateTime.now().toIso8601String(),
        });
        encoded = jsonEncode(snapshot);
        store.put(encoded.toJS, 'snapshot'.toJS);
      } else if (replacement != null) {
        encoded = replacement;
        store.put(encoded.toJS, 'snapshot'.toJS);
      }
    }).toJS;
    transaction.oncomplete = ((web.Event _) => completed.complete(
      encoded,
    )).toJS;
    transaction.onabort = ((web.Event _) => completed.completeError(
      StateError('Peer transaction failed'),
    )).toJS;
    return await completed.future;
  } finally {
    database.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String root;
  setUpAll(() async {
    StudioProfile.current = const StudioProfile(
      id: 'browser-storage-tests',
      appTitle: 'Storage Tests',
      templates: [ProjectTemplate.c, ProjectTemplate.cpp],
    );
    root = (await AppPaths.storageDirectory())!;
  });

  test(
    'binary files, rename, empty directories and deletion survive reload',
    () async {
      final directory = studioDirectory('$root/storage-test');
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
      await studioDirectory('${directory.path}/empty').create();
      final source = studioFile('${directory.path}/before.dat');
      await source.writeAsBytes([0, 255, 10, 128], flush: true);
      await source.rename('${directory.path}/after.dat');
      await reloadStudioStorageForTesting();
      expect(await studioFile('${directory.path}/after.dat').readAsBytes(), [
        0,
        255,
        10,
        128,
      ]);
      expect(studioFile(source.path).existsSync(), isFalse);
      expect(studioDirectory('${directory.path}/empty').existsSync(), isTrue);
      await studioFile('${directory.path}/after.dat').delete();
      await reloadStudioStorageForTesting();
      expect(studioFile('${directory.path}/after.dat').existsSync(), isFalse);
      await studioDirectory(directory.path).delete(recursive: true);
    },
  );

  test(
    'projects and saved C++ source reopen through the shared store',
    () async {
      final store = ProjectStore();
      await store.load();
      final location = (await AppPaths.projectsRoot(create: true))!;
      final result = await store.createProject(
        name: 'Browser C++',
        location: location,
        template: ProjectTemplate.cpp,
      );
      expect(result.error, isNull);
      final project = result.project!;
      expect(project.path, startsWith('/qfli/'));
      expect(project.path, isNot(contains('://')));
      final source = studioFile('${project.path}/src/main.cpp');
      await source.writeAsString(
        '#include <cstdio>\nint main() { std::puts("42"); }\n',
        flush: true,
      );
      await reloadStudioStorageForTesting();
      final reopened = ProjectStore();
      await reopened.load();
      expect(
        reopened.projects.any(
          (item) => item.id == project.id && item.path == project.path,
        ),
        isTrue,
      );
      expect(
        await studioFile(source.path).readAsString(),
        contains('std::puts("42")'),
      );
      store.dispose();
      reopened.dispose();
    },
  );

  test(
    'project and configured entry paths stay in the virtual filesystem',
    () async {
      final location = AppPaths.languageProjectsRoot('projects', type: 'cpp');
      expect(location, '/qfli/projects/${ProjectTemplate.cpp.directoryName}');
      expect(p.current, '/qfli');
      expect(p.separator, '/');
      final project = '$location/Runner Path';
      final entry = '$project/src/custom entry.CPP';
      await studioDirectory('$project/src').create(recursive: true);
      await studioFile(entry).writeAsString('int main() {}', flush: true);
      await ProjectConfig.write(
        projectRoot: project,
        name: 'Runner Path',
        language: 'C++',
        type: 'cpp',
        entryFile: 'src/custom entry.CPP',
        strict: true,
      );
      expect(RunnerService.findEntry(project), entry);
      expect(p.relative(entry, from: project), 'src/custom entry.CPP');
      expect(studioFile(p.relative(entry)).absolute.path, entry);
      final runner = _CapturedRunner();
      final previous = StudioProfile.current;
      StudioProfile.current = StudioProfile(
        id: previous!.id,
        appTitle: previous.appTitle,
        templates: previous.templates,
        runner: runner,
      );
      try {
        final result = await RunnerService.runProject(
          projectPath: project,
          entryFile: entry,
        );
        expect(runner.projectPath, project);
        expect(runner.entryFile, entry);
        expect(await result!.stdout!.toList(), ['42']);
        expect(await result.exitCode, 0);
      } finally {
        StudioProfile.current = previous;
        await studioDirectory(project).delete(recursive: true);
      }
    },
  );

  test(
    'exclusive creation cannot overwrite an existing browser file',
    () async {
      final source = studioFile('$root/exclusive-test.c');
      await source.writeAsString('kept', flush: true);
      await expectLater(
        source.create(exclusive: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await source.readAsString(), 'kept');
      await source.delete();
    },
  );

  test(
    'custom project locations persist while temporary files stay temporary',
    () async {
      final store = ProjectStore();
      await store.load();
      await studioDirectory('/workspace').create(recursive: true);
      final result = await store.createProject(
        name: 'Custom Location',
        location: '/workspace',
        template: ProjectTemplate.c,
      );
      expect(result.error, isNull);
      final path = result.project!.path;
      expect(path, startsWith('/workspace/'));
      await studioFile(
        '$path/src/custom.c',
      ).writeAsString('persistent', flush: true);
      await studioFile(
        '/tmp/temporary.c',
      ).writeAsString('temporary', flush: true);
      await reloadStudioStorageForTesting();
      expect(
        await studioFile('$path/src/custom.c').readAsString(),
        'persistent',
      );
      expect(studioFile('/tmp/temporary.c').existsSync(), isFalse);
      final reopened = ProjectStore();
      await reopened.load();
      expect(reopened.projects.any((project) => project.path == path), isTrue);
      await studioDirectory(path).delete(recursive: true);
      store.dispose();
      reopened.dispose();
    },
  );

  test('a stale tab cannot replace a committed peer snapshot', () async {
    final localPath = '$root/conflict-local.c';
    final peerPath = '$root/conflict-peer.c';
    await studioFile(localPath).writeAsString('original', flush: true);
    final peerSnapshot = await _peerSnapshot(filePath: peerPath);
    await expectLater(
      studioFile(localPath).writeAsString('stale edit', flush: true),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('another browser tab'),
        ),
      ),
    );
    expect(await _peerSnapshot(), peerSnapshot);
    await reloadStudioStorageForTesting(discardUnsaved: true);
    expect(await studioFile(peerPath).readAsString(), 'peer content');
    expect(await studioFile(localPath).readAsString(), 'original');
    await studioFile(peerPath).delete();
    await studioFile(localPath).delete();
  });

  test(
    'transaction failure retains bytes and the editor can save again',
    () async {
      final source = studioFile('$root/retry-save.cpp');
      await source.writeAsString('original', flush: true);
      final controller = EditorController(
        project: Project.create(name: 'Retry Save', path: root),
      );
      try {
        expect(await controller.openPath(source.path), isNull);
        final open = controller.current!;
        open.controller.text = 'unsaved bytes';
        closeStudioStorageForTesting();
        final error = await controller.saveFile(open);
        expect(error, contains('Browser project storage failed to save'));
        await expectLater(
          flushStudioStorage(),
          throwsA(isA<FileSystemException>()),
        );
        expect(open.dirty, isTrue);
        expect(await studioFile(source.path).readAsString(), 'unsaved bytes');
        await reconnectStudioStorageForTesting();
        await flushStudioStorage();
        open.controller.text = 'retry bytes';
        expect(await controller.saveFile(open), isNull);
        expect(open.dirty, isFalse);
        await reloadStudioStorageForTesting();
        expect(await studioFile(source.path).readAsString(), 'retry bytes');
        await studioFile(source.path).delete();
      } finally {
        controller.dispose();
        await reconnectStudioStorageForTesting();
      }
    },
  );

  test(
    'invalid durable snapshots report a filesystem error and can recover',
    () async {
      final source = studioFile('$root/initialize-retry.c');
      await source.writeAsString('preserved', flush: true);
      final snapshot = await _peerSnapshot();
      try {
        await _peerSnapshot(replacement: '{"version":99}');
        await expectLater(
          reloadStudioStorageForTesting(discardUnsaved: true),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await _peerSnapshot(replacement: snapshot);
        await initializeStudioStorage();
      }
      expect(await studioFile(source.path).readAsString(), 'preserved');
      await studioFile(source.path).delete();
    },
  );
}

class _CapturedRunner implements ProgramRunner {
  String? projectPath;
  String? entryFile;
  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    this.projectPath = projectPath;
    this.entryFile = entryFile;
    return ProgramRunResult(
      title: 'Path Test',
      stdout: Stream.value('42'),
      stderr: const Stream.empty(),
      exitCode: Future.value(0),
    );
  }
}
