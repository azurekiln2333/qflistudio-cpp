import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:qfli_c/source_selection.dart';

void main() {
  const source = r'''const char *example = R"tag()tag\
"; int main(void) { return 99; }
)tag";
int answer(void) { return 42; }
''';
  final root = Directory(p.absolute('.trellis/tasks/10-09-unified-terminal-current-file/research')).createTempSync('check-raw-literal-');
  final entry = File(p.join(root.path, 'main.cpp'))..writeAsStringSync('#include <stdio.h>\nint answer(void);\nint main(void) { printf("%d\\n", answer()); return 0; }\n');
  final helper = File(p.join(root.path, 'helper.cpp'))..writeAsStringSync(source);
  final binary = p.join(root.path, 'raw.exe');
  final compiled = Process.runSync(r'D:\ProgramFiles\Dev-Cpp\MinGW64\bin\g++.exe', ['-std=c++11', entry.path, helper.path, '-o', binary]);
  final executed = compiled.exitCode == 0 ? Process.runSync(binary, []) : null;
  final result = {
    'actualDefinesMain': definesUnambiguousMain(source),
    'expectedDefinesMain': false,
    'compilerExit': compiled.exitCode,
    'compilerError': compiled.stderr,
    'programExit': executed?.exitCode,
    'programOutput': executed?.stdout,
  };
  print(jsonEncode(result));
  File('.trellis/tasks/10-09-unified-terminal-current-file/research/check_raw_literal_results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
}
