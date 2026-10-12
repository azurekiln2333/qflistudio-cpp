import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final compiler = r'D:\ProgramFiles\Dev-Cpp\MinGW64\bin\gcc.exe';
  if (!File(compiler).existsSync()) throw StateError('Missing compiler: $compiler');
  final helpers = <String, String>{
    'static_helper_main': 'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
    'conditional_body': 'int main(void)\n#if USE_MAIN\n{ return 99; }\n#else\n;\n#endif\nint answer(void) { return 42; }\n',
    'crlf_macro_continuation': '#define UNUSED \\\r\nint main(void) { return 99; }\r\nint answer(void) { return 42; }\r\n',
    'spliced_line_comment': '// unused example \\\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
    'comment_in_macro_name': '#define /* name */ main qfli_main\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
  };
  final report = <Map<String, Object?>>[];
  for (final item in helpers.entries) {
    final root = Directory(p.absolute('.trellis/tasks/10-09-unified-terminal-current-file/research')).createTempSync('compiler-${item.key}-');
    final entry = File(p.join(root.path, 'main.c'))..writeAsStringSync('#include <stdio.h>\nint answer(void);\nint main(void) { printf("%d\\n", answer()); return 0; }\n');
    final helper = File(p.join(root.path, 'helper.c'))..writeAsStringSync(item.value);
    final binary = p.join(root.path, 'all.exe');
    final all = Process.runSync(compiler, ['-x', 'c', '-std=c11', entry.path, helper.path, '-o', binary]);
    final executed = all.exitCode == 0 ? Process.runSync(binary, []) : null;
    final dropped = Process.runSync(compiler, ['-x', 'c', '-std=c11', entry.path, '-o', p.join(root.path, 'dropped.exe')]);
    final result = <String, Object?>{
      'case': item.key,
      'allSourcesCompileExit': all.exitCode,
      'allSourcesCompileError': all.stderr,
      'programExit': executed?.exitCode,
      'programOutput': executed?.stdout,
      'selectedWithoutHelperCompileExit': dropped.exitCode,
      'selectedWithoutHelperCompileError': dropped.stderr,
    };
    report.add(result);
    print(jsonEncode(result));
  }
  File('.trellis/tasks/10-09-unified-terminal-current-file/research/check_compiler_results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
}

