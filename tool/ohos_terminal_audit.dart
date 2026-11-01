import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qfli_c/main.dart' as product;
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';
import 'package:qfli_studio_core/terminal/shell/shell_backend.dart';

/// On-device terminal audit for the QFLIForge OHOS build.
///
/// This runs the *real* production path — `forgeProfile.terminalCommandDelegate`
/// wired through a real [SandboxShellBackend] over a real sandbox directory — so
/// passing here means the packaged clang/clang++ toolchain actually answers the
/// terminal. It is compiled as an alternate `lib/main.dart`-style entry and
/// installed by the root; it performs no android/device action of its own.
///
/// Cases mirror `native/toolchain/tests/ohos-portable-bridge-regression.py`:
/// version/help, C and C++20 compile-then-run, a linked existing object file,
/// argv containing spaces, cwd subdirectory compile/execute, clang++ forced onto
/// a `.c` source, `-E` preprocessing, quoted source/define and a nonzero exit,
/// plus a syntax error with recovery. Each step has a bounded timeout so a stuck
/// native call cannot hang the audit forever.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Clang terminal verification'))),
    ),
  );
  unawaited(_audit());
}

Future<void> _audit() async {
  final root = await Directory.systemTemp.createTemp('forge-terminal-audit-');
  final delegate = product.forgeProfile.terminalCommandDelegate;
  final shell = SandboxShellBackend(sandboxRoot: root.path, delegate: delegate);
  final chunks = <ShellChunk>[];
  final subscription = shell.output.listen(chunks.add);
  final results = <Map<String, Object?>>[];
  String current = 'profile';
  final startedAt = DateTime.now();
  try {
    if (delegate == null) {
      throw StateError('Forge terminal delegate is missing');
    }

    // `cd` routes through the backend built-in and updates the backend cwd, so
    // a following command's `workingDirectory` payload follows the change.
    Future<void> cd(String name, String target) async {
      current = name;
      chunks.clear();
      final from = shell.cwd;
      await shell.execute('cd $target').timeout(const Duration(seconds: 30));
      if (shell.lastExitCode != null && shell.lastExitCode != 0) {
        throw StateError('$name: cd returned ${shell.lastExitCode}');
      }
      final Directory cwd;
      try {
        cwd = Directory(shell.cwd);
      } on FileSystemException catch (error) {
        throw StateError('$name: invalid cwd ${shell.cwd}: $error');
      }
      if (!cwd.existsSync()) {
        throw StateError('$name: cd did not land in an existing directory');
      }
      final expected = switch (target) {
        '..' => Directory(from).parent.absolute.path,
        '~' => shell.sandboxRoot,
        _ => null,
      };
      if (expected != null && expected != cwd.absolute.path) {
        throw StateError(
          '$name: expected $expected but landed in ${cwd.absolute.path}',
        );
      }
    }

    Future<void> check(
      String name,
      String command, {
      int status = 0,
      String? output,
      bool error = false,
      bool stdoutEmpty = false,
    }) async {
      current = name;
      chunks.clear();
      debugPrintSynchronously('QFLI_OHOS_TERMINAL_START $name');
      final began = DateTime.now();
      await shell.execute(command).timeout(const Duration(seconds: 120));
      final stdout = chunks
          .where((chunk) => chunk.kind == OutputKind.stdout)
          .map((chunk) => chunk.text)
          .join();
      final stderr = chunks
          .where((chunk) => chunk.kind == OutputKind.stderr)
          .map((chunk) => chunk.text)
          .join();
      final actual = shell.lastExitCode;
      final ok =
          actual == status &&
          (output == null || stdout.contains(output)) &&
          (!stdoutEmpty || stdout.isEmpty) &&
          (!error || stderr.isNotEmpty);
      results.add({
        'name': name,
        'command': command,
        'cwd': shell.cwd,
        'exitCode': actual,
        'ms': DateTime.now().difference(began).inMilliseconds,
        'stdout': stdout.length > 900 ? stdout.substring(0, 900) : stdout,
        'stderr': stderr.length > 900 ? stderr.substring(0, 900) : stderr,
        'ok': ok,
      });
      if (!ok) {
        throw StateError('$name: exit=$actual stdout=$stdout stderr=$stderr');
      }
      debugPrintSynchronously(
        'QFLI_OHOS_TERMINAL_CASE ${jsonEncode(results.last)}',
      );
    }

    Future<void> expectFile(String name, String relative) async {
      final file = File('${shell.cwd}/$relative');
      if (!await file.exists()) {
        throw StateError('$name: expected artifact missing: $relative');
      }
    }

    // --- version / help -----------------------------------------------------
    await check('version', 'clang --version', output: '22.1.0');
    await check('help', 'clang --help', output: 'clang');

    // --- C compile -> run ---------------------------------------------------
    await File('${root.path}/hello.c').writeAsString(
      '#include <stdio.h>\n'
      'int main(int argc, char **argv) { '
      'printf("terminal-C-ok argc=%d\\n", argc); return 0; }\n',
    );
    await check('compile-C', 'clang -std=c17 hello.c -o hello');
    await expectFile('compile-C', 'hello');
    await check('run-C', './hello', output: 'terminal-C-ok argc=1');

    // --- argv with spaces preserved as one argument -------------------------
    await check(
      'run-C-argv-spaces',
      './hello "one two" three',
      output: 'terminal-C-ok argc=3',
    );

    // --- object output, then LINK an existing .o and run it -----------------
    await check('compile-object', 'clang -c hello.c -o hello.o');
    await expectFile('compile-object', 'hello.o');
    await check('link-existing-object', 'clang hello.o -o relinked');
    await expectFile('link-existing-object', 'relinked');
    await check(
      'run-linked-object',
      './relinked',
      output: 'terminal-C-ok argc=1',
    );

    // --- C++20 compile -> run ----------------------------------------------
    await File('${root.path}/hello.cpp').writeAsString(
      '#include <iostream>\n'
      '#include <vector>\n'
      'int main() { std::vector<int> v{2,3,5}; '
      'std::cout << "terminal-Cpp-ok=" << v.size() << "\\n"; }\n',
    );
    await check('compile-Cpp', 'clang++ -std=c++20 hello.cpp -o cpp-program');
    await check('run-Cpp', './cpp-program', output: 'terminal-Cpp-ok=3');

    // --- clang++ over a `.c` file compiles it as C++ ------------------------
    await File('${root.path}/forced.cpp.c').writeAsString(
      'int main() { auto v = 41 + 1; return v == 42 ? 0 : 1; }\n',
    );
    await check(
      'compile-cpp-language-on-c-source',
      'clang++ -std=c++20 forced.cpp.c -o forced-cpp',
    );
    await check('run-cpp-language-on-c-source', './forced-cpp');

    // --- -E preprocessing: to a file, and to stdout without -o ----------------
    await File(
      '${root.path}/pp.c',
    ).writeAsString('#define PP_MARKER 4242\nint pp_value = PP_MARKER;\n');
    await check(
      '-E-preprocess-file',
      'clang -E pp.c -o pp.i',
      stdoutEmpty: true,
    );
    await expectFile('-E-preprocess-file', 'pp.i');
    // The preprocessed text must actually contain the expanded constant.
    final preprocessed = await File('${root.path}/pp.i').readAsString();
    if (!preprocessed.contains('4242')) {
      throw StateError('-E-preprocess-file: expanded marker 4242 missing');
    }
    // `-E` without `-o` must stream the preprocessed translation unit to stdout.
    await check(
      '-E-preprocess-stdout',
      'clang -E pp.c',
      output: 'int pp_value = 4242',
    );

    // --- cd into a subdirectory and compile/execute there -------------------
    final nested = Directory('${root.path}/nested')..createSync();
    await File('${nested.path}/nested.c').writeAsString(
      '#include <stdio.h>\n'
      'int main(void) { puts("nested-cwd-ok"); return 0; }\n',
    );
    await cd('cd-nested', 'nested');
    await check(
      'compile-nested-cwd',
      'clang -std=c17 nested.c -o nested-program',
    );
    await check('run-nested-cwd', './nested-program', output: 'nested-cwd-ok');
    await cd('cd-back', '..');

    // --- quoted filename/define and a nonzero program exit ------------------
    await File('${root.path}/quote name.c').writeAsString(
      '#ifndef VALUE\n#error VALUE missing\n#endif\nint main(void) { return VALUE; }\n',
    );
    await check(
      'quoted-source-and-define',
      'clang -DVALUE=7 "quote name.c" -o "quote program"',
    );
    await check('nonzero-exit', './"quote program"', status: 7);

    // --- diagnostics then recovery -----------------------------------------
    await File(
      '${root.path}/broken.c',
    ).writeAsString('int main(void) { broken source; }\n');
    await check(
      'compile-diagnostics',
      'clang broken.c -o broken',
      status: 1,
      error: true,
      stdoutEmpty: true,
    );
    await check('recovery', './hello', output: 'terminal-C-ok argc=1');

    debugPrintSynchronously(
      'QFLI_OHOS_TERMINAL_AUDIT ${jsonEncode({
        'ok': true,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'cases': results.map((result) => {'name': result['name'], 'exitCode': result['exitCode'], 'ms': result['ms'], 'ok': result['ok']}).toList(),
      })}',
    );
  } catch (error, stack) {
    debugPrintSynchronously(
      'QFLI_OHOS_TERMINAL_AUDIT ${jsonEncode({'ok': false, 'current': current, 'error': '$error', 'stack': '$stack', 'cases': results})}',
    );
  } finally {
    await shell.interrupt();
    await subscription.cancel();
    await shell.shutdown();
    await root.delete(recursive: true);
  }
}
