import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/cpp_runner.dart';
import 'package:qfli_c/main.dart' show forgeProfile;
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = forgeProfile;
    project = Directory.current.createTempSync('qfli_native_compiler_test_');
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
      expect(title, anyOf(contains('Clang'), contains('GCC')));
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
    expect(title, anyOf(contains('Clang'), contains('GCC')));
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
    expect(result.title, anyOf(contains('Clang'), contains('GCC')));
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
