import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/clang_runner.dart';
import 'package:qfli_c/cpp_runner.dart';
import 'package:qfli_c/main.dart' show forgeProfile;
import 'package:qfli_c/source_selection.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = forgeProfile;
    project = Directory.current.createTempSync('qfli native compiler test ');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String contents) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  void copyFixture(String name) {
    final fixture = Directory(
      p.join('test', 'fixtures', 'desktop_native', name),
    );
    for (final entity in fixture.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final destination = File(
        p.join(project.path, p.relative(entity.path, from: fixture.path)),
      );
      destination.parent.createSync(recursive: true);
      entity.copySync(destination.path);
    }
  }

  Future<(int, List<String>, List<String>, String)> run(String entry) async {
    final result = await RunnerService.runProject(
      projectPath: project.path,
      entryFile: p.join(project.path, entry),
    );
    expect(result, isNotNull);
    final stdout = result!.stdout!.toList();
    final stderr = result.stderr!.toList();
    final code = await result.exitCode!;
    return (code, await stdout, await stderr, result.title);
  }

  test(
    'compiles and runs multi-file C with project and system headers',
    () async {
      write('include/math.h', 'int answer(void);\n');
      write(
        'src/math.c',
        '#include <math.h>\nint answer(void) { return 42; }\n',
      );
      write('src/main.c', '''
#include <stdio.h>
#include <math.h>
int main(void) { printf("%d\\n", answer()); return 0; }
''');

      final (code, output, errors, title) = await run('src/main.c');
      expect(title, 'run src/main.c');
      expect(code, 0, reason: errors.join('\n'));
      expect(output, ['42']);
      expect(errors, isEmpty);
    },
  );

  test('compiles and runs multi-file C++ with standard library', () async {
    write('include/math.hpp', 'int answer();\n');
    write('src/math.cpp', '''
#include <math.hpp>
#include <vector>
int answer() { std::vector<int> values{20, 22}; return values[0] + values[1]; }
''');
    write('src/main.cpp', '''
#include <iostream>
#include <math.hpp>
int main() { std::cout << answer() << std::endl; return 0; }
''');

    final (code, output, errors, title) = await run('src/main.cpp');
    expect(title, 'run src/main.cpp');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['42']);
    expect(errors, isEmpty);
  });

  test('compiles C sources as C in a C++ project', () async {
    write('include/math.h', '''
#ifdef __cplusplus
extern "C" {
#endif
int answer(void);
#ifdef __cplusplus
}
#endif
''');
    write('src/math.c', '#include <math.h>\nint answer(void) { return 42; }\n');
    write('src/main.cpp', '''
#include <iostream>
#include <math.h>
int main() { std::cout << answer() << std::endl; return 0; }
''');

    final (code, output, errors, _) = await run('src/main.cpp');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['42']);
    expect(errors, isEmpty);
  });

  test('links a C entry with C++ helpers and compiles C syntax as C', () async {
    copyFixture('mixed_c_main');

    final (code, output, errors, title) = await run('main.c');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['42']);
    expect(errors, isEmpty);
    expect(title, 'run main.c');
  });

  test(
    'handles source extensions without case-sensitive compiler inference',
    () async {
      copyFixture('mixed_c_main');
      File(
        p.join(project.path, 'main.c'),
      ).renameSync(p.join(project.path, 'main.C'));
      File(
        p.join(project.path, 'helper.cpp'),
      ).renameSync(p.join(project.path, 'helper.CPP'));

      final (code, output, errors, _) = await run('main.C');
      expect(code, 0, reason: errors.join('\n'));
      expect(output, ['42']);
      expect(errors, isEmpty);
    },
  );

  test('links math functions evaluated from runtime input', () async {
    copyFixture('math');

    final (code, output, errors, _) = await run('main.c');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['4.000000']);
    expect(errors, isEmpty);
  });

  test(
    'runs the requested main and keeps the shared helper in a multi-main project',
    () async {
      copyFixture('multi_main');

      final (codeA, outputA, errorsA, titleA) = await run('main.c');
      expect(codeA, 0, reason: errorsA.join('\n'));
      expect(outputA, ['program A 42']);
      expect(errorsA, isEmpty);
      expect(titleA, 'run main.c');

      final (codeB, outputB, errorsB, titleB) = await run('main2.c');
      expect(codeB, 0, reason: errorsB.join('\n'));
      expect(outputB, ['program B 42']);
      expect(errorsB, isEmpty);
      expect(titleB, 'run main2.c');
      // The two programs must differ, not merely carry different titles.
      expect(outputA, isNot(outputB));
    },
  );

  test('selecting main2.c drops main.c from the compile set', () async {
    copyFixture('multi_main');
    final all =
        Directory(project.path)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((file) => file.path)
            .where(
              (path) => const ['.c', '.cc', '.cpp', '.cxx'].contains(
                p.extension(path).toLowerCase(),
              ),
            )
            .toList();
    final selected = selectRunSources(
      entryFile: p.join(project.path, 'main2.c'),
      allSources: all,
      readSource: (path) => File(path).readAsStringSync(),
    );
    expect(selected, contains(p.join(project.path, 'main2.c')));
    expect(selected, contains(p.join(project.path, 'helper.c')));
    expect(selected, isNot(contains(p.join(project.path, 'main.c'))));
  });

  test('a header entry fails explicitly instead of running a program', () async {
    copyFixture('multi_main');

    final result = await ClangProgramRunner().run(
      projectPath: project.path,
      entryFile: p.join(project.path, 'helper.h'),
    );
    expect(result, isNotNull);
    expect(await result!.exitCode, kProgramNotRunExitCode);
    expect(await result.stdout.toList(), isEmpty);
    expect((await result.stderr.toList()).join('\n'), contains('头文件'));
    expect(result.title, 'run helper.h');
  });

  test('rejects an entry outside the project without running it', () async {
    copyFixture('multi_main');
    final container = Directory.systemTemp.createTempSync('qfli_outside_');
    addTearDown(() {
      if (container.existsSync()) container.deleteSync(recursive: true);
    });
    final outside = File(p.join(container.path, 'outside.c'))
      ..writeAsStringSync(
        '#include <stdio.h>\nint main(void) { puts("OUTSIDE"); return 0; }\n',
      );

    final result = await ClangProgramRunner().run(
      projectPath: project.path,
      entryFile: outside.path,
    );
    expect(result, isNotNull);
    expect(await result!.exitCode, kProgramNotRunExitCode);
    expect(await result.stdout.toList(), isEmpty);
    expect((await result.stderr.toList()).join('\n'), contains('工程内'));
  });

  test('a helper defining main is retained, not selected as the entry', () async {
    write(
      'main.c',
      '#include <stdio.h>\nint answer(void);\nint main(void) { printf("%d\\n", answer()); return 0; }\n',
    );
    write(
      'helper.c',
      'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
    );

    final (code, output, errors, title) = await run('main.c');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['42']);
    expect(errors, isEmpty);
    expect(title, 'run main.c');
  });

  test('feeds input.txt and keeps stdout and stderr separate', () async {
    copyFixture('io');

    final (code, output, errors, _) = await run('main.c');
    expect(code, 0, reason: errors.join('\n'));
    expect(output, ['input=42']);
    expect(errors, ['input accepted']);
  });

  test('preserves native stderr and a nonzero program exit', () async {
    copyFixture('nonzero');

    final (code, output, errors, _) = await run('main.c');
    expect(code, 7);
    expect(output, ['before exit']);
    expect(errors, ['intentional failure']);
  });

  test('does not run an old executable when the next link fails', () async {
    copyFixture('io');
    final (previousCode, previousOutput, previousErrors, _) = await run(
      'main.c',
    );
    expect(previousCode, 0, reason: previousErrors.join('\n'));
    expect(previousOutput, ['input=42']);
    expect(
      File(
        p.join(
          project.path,
          '.qfli',
          'build',
          'forge',
          Platform.isWindows ? 'program.exe' : 'program',
        ),
      ).existsSync(),
      isTrue,
    );

    copyFixture('link_error');
    final (code, output, errors, _) = await run('main.c');
    expect(code, isNot(0));
    expect(code, isNot(kProgramNotRunExitCode));
    expect(output, isEmpty);
    expect(errors.join('\n'), contains('missing_symbol'));
    expect(errors, isNot(contains('input accepted')));
  });

  test(
    'cancels a running native loop with exit 130 and process cleanup',
    () async {
      copyFixture('cancel');
      final supervisor = ProcessSupervisor();
      final result = await ClangProgramRunner(supervisor: supervisor).run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.c'),
      );
      expect(result, isNotNull);
      final ready = Completer<void>();
      final output = result!.stdout.map((line) {
        if (line == 'ready' && !ready.isCompleted) ready.complete();
        return line;
      }).toList();
      final errors = result.stderr.toList();

      try {
        await ready.future.timeout(const Duration(seconds: 20));
        expect(supervisor.activeCount, 1);
        await result.cancel!().timeout(const Duration(seconds: 10));
        expect(await result.exitCode, 130);
        expect(await output, ['ready']);
        expect(await errors, isEmpty);
        expect(supervisor.activeCount, 0);
      } finally {
        await supervisor.dispose();
        await result.cancel!();
      }
    },
  );

  test('reports compiler diagnostics without running invalid C++', () async {
    write('main.cpp', 'int main() { return missing_symbol; }\n');

    final (code, output, errors, _) = await run('main.cpp');
    expect(code, isNot(0));
    expect(output, isEmpty);
    expect(errors.join('\n'), contains('main.cpp'));
  });

  test('legacy C++ runner delegates to a working compiler', () async {
    write('main.cpp', '''
#include <iostream>
#include <numeric>
#include <vector>
int main() {
  std::vector<int> values{10, 20, 12};
  std::cout << std::accumulate(values.begin(), values.end(), 0) << std::endl;
  return 0;
}
''');
    final result = await const CppProgramRunner().run(
      projectPath: project.path,
      entryFile: p.join(project.path, 'main.cpp'),
    );
    expect(result, isNotNull);
    final output = result!.stdout.toList();
    final errors = result.stderr.toList();
    final code = await result.exitCode;
    expect(code, 0, reason: (await errors).join('\n'));
    expect(await output, ['42']);
    expect(result.title, 'run main.cpp');
  });

  test('allows output streams to be consumed one after another', () async {
    write('main.cpp', '''
#include <iostream>
int main() { std::cout << "ready" << std::endl; return 0; }
''');
    final result = await RunnerService.runProject(
      projectPath: project.path,
      entryFile: p.join(project.path, 'main.cpp'),
    );

    expect(await result!.stdout!.toList(), ['ready']);
    expect(await result.stderr!.toList(), isEmpty);
    expect(await result.exitCode, 0);
  });
}
