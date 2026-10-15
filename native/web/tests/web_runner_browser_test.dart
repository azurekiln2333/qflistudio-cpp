@TestOn('browser')
library;

// This is a genuine browser test that lives outside `test/` so it is excluded
// from the default VM test run. It legitimately uses the storage facade's
// @visibleForTesting reload helper, which the analyzer only permits from a
// recognized test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/web_clang_runner.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_c/platform/platform_io.dart';
import 'package:qfli_c/platform/platform_io_browser.dart'
    show reloadStudioStorageForTesting;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    StudioProfile.current = const StudioProfile(
      id: 'browser-runner-tests',
      appTitle: 'Runner Tests',
      templates: [ProjectTemplate.c, ProjectTemplate.cpp],
    );
    await initializeStudioStorage();
  });

  Future<String> project(String name, String source) async {
    final root = '/workspace/runner-tests/$name';
    final directory = studioDirectory(root);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    await studioFile('$root/main.c').writeAsString(source, flush: true);
    return root;
  }

  test(
    'actual compiler preserves IO and durable custom-location filesystem changes',
    () async {
      final root = await project('files', r'''
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
int main(void) {
  int value;
  if (scanf("%d", &value) != 1) return 2;
  FILE *file = fopen("output.txt", "w");
  if (!file) return 3;
  fprintf(file, "%d\n", value);
  fclose(file);
  if (remove("deleted.txt") != 0 || rmdir("removed-empty") != 0) return 4;
  if (mkdir("created-empty", 0700) != 0) return 5;
  if (mkdir("generated", 0700) != 0) return 6;
  file = fopen("generated/child.txt", "w");
  if (!file) return 8;
  fputs("nested output\n", file);
  fclose(file);
  printf("input=%d\n", value);
  fputs("accepted\n", stderr);
  return 7;
}
''');
      await studioFile('$root/input.txt').writeAsString('42\n', flush: true);
      await studioFile(
        '$root/deleted.txt',
      ).writeAsString('remove me', flush: true);
      await studioDirectory('$root/removed-empty').create();
      await studioDirectory('$root/unchanged-empty').create();
      final result = (await const WebClangProgramRunner().run(
        projectPath: root,
        entryFile: '$root/main.c',
      ))!;
      try {
        final stdout = result.stdout.toList();
        final stderr = result.stderr.toList();
        expect(await result.exitCode, 7);
        expect(await stdout, ['input=42']);
        expect(await stderr, ['accepted']);
        expect(await studioFile('$root/output.txt').readAsString(), '42\n');
        await reloadStudioStorageForTesting();
        expect(await studioFile('$root/output.txt').readAsString(), '42\n');
        expect(
          await studioFile('$root/generated/child.txt').readAsString(),
          'nested output\n',
        );
        expect(studioFile('$root/deleted.txt').existsSync(), isFalse);
        expect(studioDirectory('$root/removed-empty').existsSync(), isFalse);
        expect(studioDirectory('$root/created-empty').existsSync(), isTrue);
        expect(studioDirectory('$root/unchanged-empty').existsSync(), isTrue);
      } finally {
        await result.cancel!();
        await studioDirectory(root).delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'runtime file and directory replacements persist after reload',
    () async {
      final root = await project('type-replacements', r'''
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
int main(void) {
  if (remove("file-node") != 0 || mkdir("file-node", 0700) != 0) return 2;
  FILE *file = fopen("file-node/child.txt", "w");
  if (!file) return 3;
  fputs("file became directory\n", file);
  fclose(file);
  if (remove("dir-node/inner/original.txt") != 0) return 4;
  if (rmdir("dir-node/inner") != 0 || rmdir("dir-node") != 0) return 5;
  file = fopen("dir-node", "w");
  if (!file) return 6;
  fputs("directory became file\n", file);
  fclose(file);
  return 0;
}
''');
      await studioFile(
        '$root/file-node',
      ).writeAsString('original', flush: true);
      await studioDirectory('$root/dir-node/inner').create(recursive: true);
      await studioFile(
        '$root/dir-node/inner/original.txt',
      ).writeAsString('remove me', flush: true);
      final result = (await const WebClangProgramRunner().run(
        projectPath: root,
        entryFile: '$root/main.c',
      ))!;
      final output = result.stdout.toList();
      final errors = result.stderr.toList();
      try {
        expect(await result.exitCode, 0);
        expect(await output, isEmpty);
        expect(await errors, isEmpty);
        await reloadStudioStorageForTesting();
        expect(
          studioEntityTypeSync('$root/file-node'),
          FileSystemEntityType.directory,
        );
        expect(
          await studioFile('$root/file-node/child.txt').readAsString(),
          'file became directory\n',
        );
        expect(
          studioEntityTypeSync('$root/dir-node'),
          FileSystemEntityType.file,
        );
        expect(
          await studioFile('$root/dir-node').readAsString(),
          'directory became file\n',
        );
      } finally {
        await result.cancel!();
        await studioDirectory(root).delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'runtime writeback preserves a saved live-editor change',
    () async {
      final root = await project('editor-conflict', r'''
#include <stdio.h>
#include <time.h>
int main(void) {
  puts("ready");
  fflush(stdout);
  struct timespec start, now;
  if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) return 2;
  do {
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 2;
  } while (now.tv_sec - start.tv_sec < 3);
  FILE *file = fopen("editable.txt", "w");
  if (!file) return 3;
  fputs("runtime output", file);
  fclose(file);
  return 0;
}
''');
      await studioFile(
        '$root/editable.txt',
      ).writeAsString('original', flush: true);
      final editor = EditorController(
        project: Project.create(name: 'Runtime Conflict', path: root),
      );
      expect(await editor.openPath('$root/editable.txt'), isNull);
      final result = (await const WebClangProgramRunner().run(
        projectPath: root,
        entryFile: '$root/main.c',
      ))!;
      final saved = Completer<void>();
      final errors = result.stderr.toList();
      final readyOutput = <String>[];
      final drained = Completer<void>();
      var receivedReady = false;
      result.stdout.listen(
        (line) {
          readyOutput.add(line);
          if (line != 'ready' || receivedReady) return;
          receivedReady = true;
          unawaited(() async {
            try {
              final open = editor.current!;
              open.controller.text = 'editor change';
              final error = await editor.saveFile(open);
              if (error != null) throw StateError(error);
              expect(open.dirty, isFalse);
              saved.complete();
            } catch (error, stack) {
              saved.completeError(error, stack);
            }
          }());
        },
        onDone: () {
          drained.complete();
          if (!receivedReady) {
            saved.completeError(
              StateError('Program ended before the ready line'),
            );
          }
        },
      );
      try {
        await saved.future.timeout(const Duration(minutes: 2));
        expect(await result.exitCode, kProgramNotRunExitCode);
        expect(await errors, contains(contains('changed during execution')));
        await drained.future;
        expect(readyOutput, ['ready']);
        await reloadStudioStorageForTesting();
        expect(
          await studioFile('$root/editable.txt').readAsString(),
          'editor change',
        );
      } finally {
        await result.cancel!();
        editor.dispose();
        await studioDirectory(root).delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'directory replacement cannot delete a new live-editor child',
    () async {
      final root = await project('directory-conflict', r'''
#include <stdio.h>
#include <time.h>
#include <unistd.h>
int main(void) {
  puts("ready");
  fflush(stdout);
  struct timespec start, now;
  if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) return 2;
  do {
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 2;
  } while (now.tv_sec - start.tv_sec < 3);
  if (rmdir("dir-node") != 0) return 3;
  FILE *file = fopen("dir-node", "w");
  if (!file) return 4;
  fputs("runtime replacement", file);
  fclose(file);
  return 0;
}
''');
      await studioDirectory('$root/dir-node').create();
      final editor = EditorController(
        project: Project.create(name: 'Directory Conflict', path: root),
      );
      final result = (await const WebClangProgramRunner().run(
        projectPath: root,
        entryFile: '$root/main.c',
      ))!;
      final saved = Completer<void>();
      final errors = result.stderr.toList();
      final output = <String>[];
      final drained = Completer<void>();
      var receivedReady = false;
      result.stdout.listen(
        (line) {
          output.add(line);
          if (line != 'ready' || receivedReady) return;
          receivedReady = true;
          unawaited(() async {
            try {
              final path = '$root/dir-node/editor.txt';
              await studioFile(path).writeAsString('new child', flush: true);
              expect(await editor.openPath(path), isNull);
              final open = editor.current!;
              open.controller.text = 'saved during execution';
              final error = await editor.saveFile(open);
              if (error != null) throw StateError(error);
              expect(open.dirty, isFalse);
              saved.complete();
            } catch (error, stack) {
              saved.completeError(error, stack);
            }
          }());
        },
        onDone: () {
          drained.complete();
          if (!receivedReady) {
            saved.completeError(
              StateError('Program ended before the ready line'),
            );
          }
        },
      );
      try {
        await saved.future.timeout(const Duration(minutes: 2));
        expect(await result.exitCode, kProgramNotRunExitCode);
        expect(await errors, contains(contains('Browser project save failed')));
        await drained.future;
        expect(output, ['ready']);
        await reloadStudioStorageForTesting();
        expect(
          studioEntityTypeSync('$root/dir-node'),
          FileSystemEntityType.directory,
        );
        expect(
          await studioFile('$root/dir-node/editor.txt').readAsString(),
          'saved during execution',
        );
      } finally {
        await result.cancel!();
        editor.dispose();
        await studioDirectory(root).delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'actual infinite program cancellation completes the Dart result with130',
    () async {
      final root = await project('cancel', r'''
#include <stdio.h>
int main(void) {
  puts("ready");
  fflush(stdout);
  for (;;) {}
}
''');
      final result = (await const WebClangProgramRunner().run(
        projectPath: root,
        entryFile: '$root/main.c',
      ))!;
      final ready = Completer<void>();
      final drained = Completer<void>();
      final output = <String>[];
      result.stdout.listen(
        (line) {
          output.add(line);
          if (line == 'ready' && !ready.isCompleted) {
            ready.complete();
          }
        },
        onDone: () {
          drained.complete();
          if (!ready.isCompleted) {
            ready.completeError(
              StateError('Program ended before the ready line'),
            );
          }
        },
      );
      final stderr = result.stderr.toList();
      try {
        await ready.future.timeout(const Duration(minutes: 2));
        await result.cancel!();
        expect(await result.exitCode, 130);
        await drained.future;
        expect(output, ['ready']);
        expect(await stderr, isEmpty);
      } finally {
        await result.cancel!();
        await studioDirectory(root).delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
