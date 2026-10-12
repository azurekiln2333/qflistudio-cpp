import 'dart:convert';
import 'package:qfli_c/source_selection.dart';
void main() {
  final cases = <String, String>{
    'static_helper_main': 'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
    'conditional_body': 'int main(void)\n#if USE_MAIN\n{ return 99; }\n#else\n;\n#endif\nint answer(void) { return 42; }\n',
    'crlf_macro_continuation': '#define UNUSED \\\r\nint main(void) { return 99; }\r\nint answer(void) { return 42; }\r\n',
    'spliced_line_comment': '// unused example \\\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
    'comment_in_macro_name': '#define /* name */ main qfli_main\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
  };
  for (final item in cases.entries) {
    print(jsonEncode({
      'case': item.key,
      'actualDefinesMain': definesUnambiguousMain(item.value),
      'expectedDefinesMain': false,
      'selected': selectRunSources(entryFile: 'entry.c', allSources: ['entry.c', 'helper.c'], readSource: (path) => path == 'helper.c' ? item.value : null),
    }));
  }
}
