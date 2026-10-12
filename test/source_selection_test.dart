import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/source_selection.dart';

/// Lexical-boundary coverage for the one C/C++ source-selection rule.
///
/// The rule decides only whether a non-entry unit contains an unambiguous
/// top-level `main` *definition*. Anything it cannot decide must stay in the
/// compilation set, so all "unsure" fixtures assert `false` (keep the file).
void main() {
  group('definesUnambiguousMain: real definitions', () {
    test('classic C main definition', () {
      expect(
        definesUnambiguousMain('int main(void) { return 0; }\n'),
        isTrue,
      );
    });

    test('main with argc/argv', () {
      expect(
        definesUnambiguousMain('int main(int argc, char **argv) { return 0; }\n'),
        isTrue,
      );
    });

    test('main spanning lines', () {
      expect(
        definesUnambiguousMain('int\nmain\n(\nvoid\n)\n{\nreturn 0;\n}\n'),
        isTrue,
      );
    });

    test('C++ main using std::', () {
      expect(
        definesUnambiguousMain(
          'int main() { std::cout << "hi"; return 0; }\n',
        ),
        isTrue,
      );
    });
  });

  group('definesUnambiguousMain: comments', () {
    test('line comment', () {
      expect(
        definesUnambiguousMain('// int main(void) { return 0; }\nint helper(){}\n'),
        isFalse,
      );
    });

    test('block comment', () {
      expect(
        definesUnambiguousMain('/* int main() { } */ void helper(void) {}\n'),
        isFalse,
      );
    });

    test('main word inside a comment about the program', () {
      expect(
        definesUnambiguousMain('// call main() to start\nint answer(void){return 42;}\n'),
        isFalse,
      );
    });
  });

  group('definesUnambiguousMain: strings', () {
    test('normal string mentions main(', () {
      expect(
        definesUnambiguousMain('const char *s = "main()";\n'),
        isFalse,
      );
    });

    test('escaped quote then main(', () {
      expect(
        definesUnambiguousMain('const char *s = "\\"main()\\"";\n'),
        isFalse,
      );
    });

    test('character literal', () {
      expect(definesUnambiguousMain("char c = ')'; int helper(void){}\n"), isFalse);
    });

    test('raw string contains main definition', () {
      expect(
        definesUnambiguousMain('const char *s = R"(int main() { return 0; })";\n'),
        isFalse,
      );
    });

    test('raw string with delimiter', () {
      expect(
        definesUnambiguousMain('auto s = R"x(int main(){} )x";\n'),
        isFalse,
      );
    });
  });

  group('definesUnambiguousMain: not a definition', () {
    test('prototype only', () {
      expect(definesUnambiguousMain('int main(void);\n'), isFalse);
    });

    test('struct field named main', () {
      expect(definesUnambiguousMain('struct S { int main; };\n'), isFalse);
    });

    test('integer variable named main', () {
      expect(definesUnambiguousMain('int main = 5;\n'), isFalse);
    });

    test('member call obj.main()', () {
      expect(
        definesUnambiguousMain('int helper(void) { return obj.main(); }\n'),
        isFalse,
      );
    });

    test('pointer member call p->main()', () {
      expect(
        definesUnambiguousMain('int helper(void) { return p->main(); }\n'),
        isFalse,
      );
    });

    test('namespace-qualified Foo::main()', () {
      expect(
        definesUnambiguousMain('int Foo::main() { return 0; }\n'),
        isFalse,
      );
    });

    test('member function declaration in a class', () {
      expect(
        definesUnambiguousMain('class C { int main(); };;\n'),
        isFalse,
      );
    });

    test('inline member definition inside a class', () {
      expect(
        definesUnambiguousMain('class C { public: int main() { return 0; } };\n'),
        isFalse,
      );
    });

    test('inline member definition inside a struct', () {
      expect(
        definesUnambiguousMain('struct S { int main() { return 0; } };\n'),
        isFalse,
      );
    });

    test('main inside a namespace definition', () {
      expect(
        definesUnambiguousMain('namespace n { int main() { return 0; } }\n'),
        isFalse,
      );
      expect(
        definesUnambiguousMain(
          'namespace outer { namespace inner { int main(){ return 0; } } }\n',
        ),
        isFalse,
      );
    });

    test('nested function main inside another function', () {
      expect(
        definesUnambiguousMain('void run(void) { int main() { return 0; } }\n'),
        isFalse,
      );
    });

    test('body that never closes before EOF is ambiguous', () {
      expect(
        definesUnambiguousMain('int main(int argc, char **argv)\n'),
        isFalse,
      );
      expect(definesUnambiguousMain('int main(void)\n'), isFalse);
    });

    test('function pointer variable', () {
      expect(
        definesUnambiguousMain('int (*main)(void) = 0;\n'),
        isFalse,
      );
    });

    test('identifier merely containing main', () {
      expect(
        definesUnambiguousMain('int mainLoop(void) { return 0; }\n'),
        isFalse,
      );
      expect(
        definesUnambiguousMain('int domain(void) { return 0; }\n'),
        isFalse,
      );
    });
  });

  group('definesUnambiguousMain: ambiguous preprocessing is kept', () {
    test('main under #if 0', () {
      expect(
        definesUnambiguousMain('#if 0\nint main(void) { return 1; }\n#endif\n'),
        isFalse,
      );
    });

    test('main selected by #ifdef', () {
      expect(
        definesUnambiguousMain(
          '#ifdef USE_B\nint main(void){ return 1; }\n#endif\n',
        ),
        isFalse,
      );
    });

    test('paired conditional programs are both ambiguous', () {
      const source =
          '#ifdef A\nint main(void){ return 1; }\n#else\nint main(void){ return 2; }\n#endif\n';
      expect(definesUnambiguousMain(source), isFalse);
    });

    test('macro-defined main', () {
      expect(definesUnambiguousMain('#define main qfli_main\nint main(void){}\n'), isFalse);
    });

    test('macro-defined main split across a continuation line', () {
      expect(
        definesUnambiguousMain('#define \\\n  main qfli_main\nint main(void){}\n'),
        isFalse,
      );
    });

    test('#undef main keeps the file', () {
      expect(definesUnambiguousMain('#undef main\nint main(void){}\n'), isFalse);
    });

    test('directive with a backslash continuation keeps its condition block', () {
      // The `#if 0 \` continues onto the next line: the body must stay in the
      // conditional region and therefore stay ambiguous.
      expect(
        definesUnambiguousMain('#if 0 \\\n/* keep */\nint main(void){ return 1; }\n#endif\n'),
        isFalse,
      );
    });

    test('comment before the hash still marks a directive line', () {
      expect(
        definesUnambiguousMain('/* c */ #define main qfli_main\nint main(void){}\n'),
        isFalse,
      );
    });

    test('unterminated block comment is ambiguous', () {
      expect(definesUnambiguousMain('int helper(void){}\n/* int main(){}'), isFalse);
    });

    test('unterminated raw string is ambiguous', () {
      expect(definesUnambiguousMain('const char *s = R"(oops\n'), isFalse);
    });
  });

  group('definesUnambiguousMain: reviewer false positives are retained', () {
    test('static helper main has internal linkage, not the entry', () {
      expect(
        definesUnambiguousMain(
          'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
        ),
        isFalse,
      );
    });

    test('main body chosen by #if with a semicolon #else is ambiguous', () {
      expect(
        definesUnambiguousMain(
          'int main(void)\n#if USE_MAIN\n{ return 99; }\n#else\n;\n#endif\nint answer(void) { return 42; }\n',
        ),
        isFalse,
      );
    });

    test('backslash-CRLF macro continuation swallows the next line', () {
      expect(
        definesUnambiguousMain(
          '#define UNUSED \\\r\nint main(void) { return 99; }\r\nint answer(void) { return 42; }\r\n',
        ),
        isFalse,
      );
    });

    test('backslash-LF line splice joins the next line into the // comment', () {
      expect(
        definesUnambiguousMain(
          '// unused example \\\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
        ),
        isFalse,
      );
    });

    test('comment between define and the macro name is still a rename', () {
      expect(
        definesUnambiguousMain(
          '#define /* name */ main qfli_main\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
        ),
        isFalse,
      );
    });

    test('selectRunSources keeps the helper for every reviewer case', () {
      const cases = <String>[
        'static int main(void) { return 42; }\nint answer(void) { return main(); }\n',
        'int main(void)\n#if USE_MAIN\n{ return 99; }\n#else\n;\n#endif\nint answer(void) { return 42; }\n',
        '#define UNUSED \\\r\nint main(void) { return 99; }\r\nint answer(void) { return 42; }\r\n',
        '// unused example \\\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
        '#define /* name */ main qfli_main\nint main(void) { return 99; }\nint answer(void) { return 42; }\n',
      ];
      for (final source in cases) {
        final selected = selectRunSources(
          entryFile: 'entry.c',
          allSources: ['entry.c', 'helper.c'],
          readSource: (path) => path == 'helper.c' ? source : null,
        );
        expect(selected, ['entry.c', 'helper.c'], reason: source);
      }
    });

    test('a genuine global main is still detected beside these forms', () {
      expect(
        definesUnambiguousMain('int main(void) { return 0; }\n'),
        isTrue,
      );
      expect(
        definesUnambiguousMain(
          'static int unused(void) { return 1; }\nint main(int argc, char **argv) { return 0; }\n',
        ),
        isTrue,
      );
    });
  });

  group('definesUnambiguousMain: top level outside conditionals still counts', () {
    test('unconditional main after a closed conditional helper', () {
      expect(
        definesUnambiguousMain(
          '#ifdef X\nint helper(void){return 1;}\n#endif\nint main(void){return 0;}\n',
        ),
        isTrue,
      );
    });
  });

  group('selectRunSources', () {
    String? Function(String) reader(Map<String, String> files) =>
        (path) => files[path];

    test('keeps entry and helpers, drops the other main program', () {
      final files = {
        'proj/main.c': 'int main(void){ return 1; }\n',
        'proj/main2.c': 'int main(void){ return 2; }\n',
        'proj/utils.c': 'int helper(void){ return 42; }\n',
      };
      final selected = selectRunSources(
        entryFile: 'proj/main2.c',
        allSources: ['proj/main.c', 'proj/main2.c', 'proj/utils.c'],
        readSource: reader(files),
      );
      expect(selected, ['proj/main2.c', 'proj/utils.c']);
      expect(selected, isNot(contains('proj/main.c')));
      expect(selected, contains('proj/main2.c'));
      expect(selected, contains('proj/utils.c'));
    });

    test('keeps the entry even when enumeration omitted it', () {
      final selected = selectRunSources(
        entryFile: 'proj/main2.c',
        allSources: ['proj/main.c', 'proj/utils.c'],
        readSource: reader({'proj/main.c': 'int main(void){return 1;}\n'}),
      );
      expect(selected.first, 'proj/main2.c');
      expect(selected, contains('proj/utils.c'));
      expect(selected, isNot(contains('proj/main.c')));
    });

    test('does not drop a helper that only mentions main in text', () {
      final files = {
        'proj/help.c':
            '// call main()\nconst char *k = "main()";\nint helper(void){return 1;}\n',
      };
      final selected = selectRunSources(
        entryFile: 'proj/entry.c',
        allSources: ['proj/entry.c', 'proj/help.c'],
        readSource: reader(files),
      );
      expect(selected, ['proj/entry.c', 'proj/help.c']);
    });

    test('keeps an ambiguous conditional unit for compiler diagnostics', () {
      final files = {
        'proj/conditional.c':
            '#ifdef A\nint main(void){return 1;}\n#endif\nint helper(void){return 2;}\n',
      };
      final selected = selectRunSources(
        entryFile: 'proj/entry.c',
        allSources: ['proj/entry.c', 'proj/conditional.c'],
        readSource: reader(files),
      );
      expect(selected, contains('proj/conditional.c'));
    });

    test('unreadable unit is kept', () {
      final selected = selectRunSources(
        entryFile: 'proj/entry.c',
        allSources: ['proj/entry.c', 'proj/missing.c'],
        readSource: (path) => null,
      );
      expect(selected, ['proj/entry.c', 'proj/missing.c']);
    });

    test('selects the requested program with Windows separators', () {
      final files = {
        r'proj\main.c': 'int main(void){return 1;}\n',
        r'proj\main2.c': 'int main(void){return 2;}\n',
      };
      final selected = selectRunSources(
        entryFile: r'proj\main2.c',
        allSources: [r'proj\main.c', r'proj\main2.c'],
        readSource: reader(files),
      );
      expect(selected, [r'proj\main2.c']);
    });
  });

  group('isCCppSourcePath', () {
    test('accepts C/C++ extensions case-insensitively', () {
      expect(isCCppSourcePath('a/main.c'), isTrue);
      expect(isCCppSourcePath('a/MAIN.C'), isTrue);
      expect(isCCppSourcePath('a/helper.CPP'), isTrue);
      expect(isCCppSourcePath('a/x.cc'), isTrue);
      expect(isCCppSourcePath('a/x.cxx'), isTrue);
    });

    test('rejects headers and other languages', () {
      expect(isCCppSourcePath('a/helper.h'), isFalse);
      expect(isCCppSourcePath('a/helper.hpp'), isFalse);
      expect(isCCppSourcePath('a/main.py'), isFalse);
      expect(isCCppSourcePath('a/noext'), isFalse);
    });
  });
}
