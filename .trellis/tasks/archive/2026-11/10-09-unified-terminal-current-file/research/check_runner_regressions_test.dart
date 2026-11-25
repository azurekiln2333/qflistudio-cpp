import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/clang_runner.dart';
import 'package:qfli_c/c_runner.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'baseline/lib/clang_runner.dart' as baseline_clang;
import 'baseline/lib/c_runner.dart' as baseline_c;

const research = '.trellis/tasks/10-09-unified-terminal-current-file/research';
Future<(int, List<String>, List<String>)> capture(ProgramRunner runner, Directory project, String entry) async {
  final result = await runner.run(projectPath: project.path, entryFile: entry);
  if (result == null) return (-999, <String>[], <String>['no result']);
  final output = result.stdout.toList();
  final errors = result.stderr.toList();
  final code = await result.exitCode;
  return (code, await output, await errors);
}
void write(Directory root, String name, String value) {
  final file = File(p.join(root.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(value);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helpers = <String, String>{
    'static_helper_main': 'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
    'conditional_body': 'int main(void)\n#if USE_MAIN\n{ return 99; }\n#else\n;\n#endif\nint answer(void) { return 42; }\n',
    'crlf_macro_continuation': '#define UNUSED \\\r\nint main(void) { return 99; }\r\nint answer(void) { return 42; }\r\n',
    'spliced_line_comment': '// unused example \\\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
    'comment_in_macro_name': '#define /* name */ main qfli_main\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
  };
  for (final item in helpers.entries) {
    test('desktop retains ${item.key}', () async {
      final project = Directory(p.absolute(research)).createTempSync('check-${item.key}-');
      write(project, 'main.c', '#include <stdio.h>\nint answer(void);\nint main(void) { printf("%d\\n", answer()); return 0; }\n');
      write(project, 'helper.c', item.value);
      final entry = p.join(project.path, 'main.c');
      final before = await capture(baseline_clang.ClangProgramRunner(), project, entry);
      expect(before.$1, 0, reason: 'baseline: ${before.$3}');
      expect(before.$2, ['42']);
      final after = await capture(ClangProgramRunner(), project, entry);
      // ignore: avoid_print
      print('${item.key}: baseline=$before current=$after');
      expect(after.$1, 0, reason: 'selected helper must remain: ${after.$3}');
      expect(after.$2, ['42']);
    });
  }
  test('interpreter retains the full header set', () async {
    final project = Directory(p.absolute(research)).createTempSync('check-headers-');
    write(project, 'main.c', '#include "entry.h"\n');
    write(project, 'entry.h', '#include <stdio.h>\nint main(void) { puts("header entry"); return 0; }\n');
    final entry = p.join(project.path, 'main.c');
    final before = await capture(const baseline_c.CProgramRunner(), project, entry);
    expect(before.$1, 0, reason: 'baseline: ${before.$3}');
    expect(before.$2, ['header entry']);
    final after = await capture(const CProgramRunner(), project, entry);
    // ignore: avoid_print
    print('header: baseline=$before current=$after');
    expect(after.$1, 0, reason: 'header must remain: ${after.$3}');
    expect(after.$2, ['header entry']);
  });
  for (final interpreter in [false, true]) {
    test('${interpreter ? "interpreter" : "desktop"} rejects an entry outside project', () async {
      final container = Directory(p.absolute(research)).createTempSync('check-outside-');
      final project = Directory(p.join(container.path, 'project'))..createSync();
      write(project, 'main.c', '#include <stdio.h>\nint main(void) { puts("INSIDE"); return 0; }\n');
      write(container, 'outside.c', '#include <stdio.h>\nint main(void) { puts("OUTSIDE"); return 0; }\n');
      final ProgramRunner runner = interpreter ? const CProgramRunner() : ClangProgramRunner();
      final after = await capture(runner, project, p.join(container.path, 'outside.c'));
      // ignore: avoid_print
      print('outside ${interpreter ? "interpreter" : "desktop"}: $after');
      expect(after.$1, kProgramNotRunExitCode);
      expect(after.$2, isEmpty);
    });
  }
}
