import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/run_title.dart';

/// The run header is one short command shape for every backend:
/// `run <project-relative entry path>`.
void main() {
  group('runTitle POSIX paths', () {
    test('relative to the project root', () {
      expect(
        runTitle(projectPath: '/home/me/proj', entryFile: '/home/me/proj/main.c'),
        'run main.c',
      );
    });

    test('keeps a nested source directory', () {
      expect(
        runTitle(
          projectPath: '/home/me/proj',
          entryFile: '/home/me/proj/src/main2.c',
        ),
        'run src/main2.c',
      );
    });

    test('renders an alternate program file name', () {
      expect(
        runTitle(
          projectPath: '/data/app_flutter/demo',
          entryFile: '/data/app_flutter/demo/main2.c',
        ),
        'run main2.c',
      );
    });
  });

  group('runTitle Windows paths', () {
    test('drive-rooted path uses the Windows context', () {
      expect(
        runTitle(
          projectPath: r'C:\Users\me\proj',
          entryFile: r'C:\Users\me\proj\src\main.c',
        ),
        'run src/main.c',
      );
    });

    test('drive letter case does not matter for the relative path', () {
      expect(
        runTitle(
          projectPath: r'C:\proj',
          entryFile: r'C:\proj\main2.cpp',
        ),
        'run main2.cpp',
      );
    });

    test('UNC path uses the Windows context', () {
      expect(
        runTitle(
          projectPath: r'\\server\share\proj',
          entryFile: r'\\server\share\proj\src\main.c',
        ),
        'run src/main.c',
      );
    });
  });

  group('runTitle platform independence', () {
    test('POSIX input stays POSIX on a Windows host and vice versa', () {
      // Explicit contexts mean the result depends only on path shape, so the
      // same inputs yield the same labels on every host, including Web.
      expect(
        runTitle(projectPath: '/p', entryFile: '/p/a/main.c'),
        'run a/main.c',
      );
      expect(
        runTitle(projectPath: r'D:\p', entryFile: r'D:\p\a\main.c'),
        'run a/main.c',
      );
    });

    test('never carries a backend or toolchain label', () {
      final title = runTitle(
        projectPath: '/p',
        entryFile: '/p/main.c',
      );
      for (final label in const [
        'Clang',
        'GCC',
        'clang',
        'gcc',
        'WASI',
        'HarmonyOS',
        '解释器',
        'picoc',
        '运行',
        '编译工具链',
      ]) {
        expect(title, isNot(contains(label)));
      }
    });
  });
}
