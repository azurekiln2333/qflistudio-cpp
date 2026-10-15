import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/native_clang_runner.dart';

import 'forge_content/forge_topics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('C/C++'))),
    ),
  );
  unawaited(audit());
}

Future<void> audit() async {
  final root = await Directory.systemTemp.createTemp('forge-native-audit-');
  final runner = NativeClangRunner(
    backendName: 'OHOS Clang',
    runIdPrefix: 'ohos-audit',
  );
  final results = <String>[];
  var current = 'prepare';
  try {
    Future<void> check(
      String name,
      String source, {
      String type = 'c',
      int exit = 0,
      String? output,
      String? error,
      bool emptyOutput = false,
      bool exactOutput = false,
      List<String>? sources,
    }) async {
      current = name;
      debugPrintSynchronously('QFLI_C_OHOS_START $name');
      final entry = File(
        p.join(root.path, type == 'c' ? 'main.c' : 'main.cpp'),
      );
      await entry.writeAsString(source);
      final run = await runner.run(
        type: type,
        projectPath: root.path,
        entryFile: entry.path,
        sources:
            sources ??
            root
                .listSync(recursive: true)
                .whereType<File>()
                .where(
                  (file) => {
                    '.c',
                    '.cpp',
                    '.cc',
                    '.cxx',
                  }.contains(p.extension(file.path).toLowerCase()),
                )
                .map((file) => file.path)
                .toList(),
      );
      if (run == null) throw StateError('Native runtime is unavailable');
      final stdout = run.stdout.toList();
      final stderr = run.stderr.toList();
      final code = await run.exitCode.timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          await run.cancel?.call();
          throw TimeoutException(name);
        },
      );
      final out = (await stdout).join('\n');
      final err = (await stderr).join('\n');
      if (code != exit ||
          output != null &&
              (exactOutput
                  ? out.trimRight() != output.trimRight()
                  : !out.contains(output)) ||
          error != null && !err.contains(error)) {
        throw StateError('$name exit=$code stdout=$out stderr=$err');
      }
      if (emptyOutput && out.isNotEmpty) {
        throw StateError('Stale program output: $out');
      }
      if (exactOutput && err.isNotEmpty) {
        throw StateError('$name unexpected stderr: $err');
      }
      results.add(name);
      debugPrintSynchronously(
        'QFLI_C_OHOS_CASE ${jsonEncode({'name': name, 'exit': code, 'stdout': out.length > 512 ? '${out.substring(0, 512)} [${out.length} chars]' : out, 'stderr': err})}',
      );
    }

    await check(
      'real-C-source',
      '#include <stdio.h>\nint main(void) { puts("native C"); return 0; }',
      output: 'native C',
    );
    await File(p.join(root.path, 'main.c')).delete();
    await check(
      'C++-stdlib-exceptions',
      '''
#include <iostream>
#include <vector>
#include <numeric>
#include <stdexcept>
int main() {
  std::vector<int> values{10, 12, 20};
  try { throw std::runtime_error("exception"); }
  catch (const std::exception &e) { std::cout << e.what() << " " << std::accumulate(values.begin(), values.end(), 0) << "\\n"; }
}
''',
      type: 'cpp',
      output: 'exception 42',
    );
    await File(p.join(root.path, 'main.cpp')).delete();
    await Directory(p.join(root.path, 'include')).create();
    await File(
      p.join(root.path, 'include', 'answer.h'),
    ).writeAsString('int answer(void);\n');
    await File(p.join(root.path, 'helper.cpp')).writeAsString('''
#include <vector>
#include <numeric>
extern "C" int answer() { std::vector<int> values{10,12,20}; return std::accumulate(values.begin(), values.end(), 0); }
''');
    await File(p.join(root.path, 'input.txt')).writeAsString('0.5\n');
    await check(
      'mixed-C-C++-headers-math-stdin-streams-exit',
      '''
#include <stdio.h>
#include <math.h>
#include "include/answer.h"
int main(void) {
  double input; if (scanf("%lf", &input) != 1) return 9;
  printf("mixed=%d math=%.3f\\n", answer(), sin(input) + exp(input));
  fprintf(stderr, "separate stderr\\n"); return 17;
}
''',
      exit: 17,
      output: 'mixed=42 math=2.128',
      error: 'separate stderr',
    );
    await File(p.join(root.path, 'helper.cpp')).delete();
    await check(
      'compiler-diagnostics',
      'int main(void) { this is not valid C; }',
      exit: 1,
      error: 'error:',
      emptyOutput: true,
    );
    await check(
      'linker-diagnostics',
      'extern int missing_symbol(void);\nint main(void) { return missing_symbol(); }',
      exit: 1,
      error: 'undefined symbol',
      emptyOutput: true,
    );
    await check(
      'program-crash-isolation',
      '#include <signal.h>\nint main(void) { raise(SIGSEGV); return 0; }',
      exit: 139,
    );

    current = 'cancel-parent-and-child';
    final entry = File(p.join(root.path, 'main.c'));
    final heartbeat = File(p.join(root.path, 'heartbeat.txt'));
    final heartbeatLiteral = jsonEncode(heartbeat.path);
    await entry.writeAsString('''
#include <stdio.h>
#include <unistd.h>
int main(void) {
  if (fork() == 0) {
    for (;;) { FILE *f = fopen($heartbeatLiteral, "a"); if (f) { fputs("x", f); fclose(f); } usleep(50000); }
  }
  puts("loop-started"); fflush(stdout);
  for (;;) usleep(50000);
}
''');
    final run = await runner.run(
      type: 'c',
      projectPath: root.path,
      entryFile: entry.path,
    );
    if (run == null) {
      throw StateError('Native runtime unavailable during cancel');
    }
    final started = Completer<void>();
    final output = <String>[];
    final subscription = run.stdout.listen((value) {
      output.add(value);
      if (value.contains('loop-started') && !started.isCompleted) {
        started.complete();
      }
    });
    final errors = run.stderr.toList();
    try {
      await started.future.timeout(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await run.cancel!();
      final code = await run.exitCode.timeout(const Duration(seconds: 10));
      await errors;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final length = await heartbeat.length();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (code != 130 || length == 0 || length != await heartbeat.length()) {
        throw StateError('Cancellation failed: exit=$code, heartbeat=$length');
      }
      results.add(current);
      debugPrintSynchronously(
        'QFLI_C_OHOS_CASE ${jsonEncode({'name': current, 'exit': code, 'stdout': output})}',
      );
    } finally {
      await run.cancel?.call();
      await subscription.cancel();
    }
    await check(
      'fresh-run-after-errors-crash-stop',
      '#include <stdio.h>\nint main(void) { puts("fresh"); return 0; }',
      output: 'fresh',
    );
    final otherEntry = File(p.join(root.path, 'another-main.c'));
    await otherEntry.writeAsString('int main(void) { return 99; }');
    await check(
      'selected-entry-excludes-other-main',
      '#include <stdio.h>\nint main(void) { puts("selected"); return 0; }',
      sources: [entry.path],
      output: 'selected',
    );
    await otherEntry.delete();
    final unicodeLine = List.filled(5000, '鸿蒙C++').join();
    await check(
      'utf8-and-pipe-chunk-boundaries',
      '#include <stdio.h>\nint main(void) { puts("$unicodeLine"); return 0; }',
      output: unicodeLine,
    );
    for (final topic in forgeTopics) {
      for (final file in root.listSync().whereType<File>()) {
        if ({'.c', '.cpp', '.cc', '.cxx'}.contains(p.extension(file.path))) {
          await file.delete();
        }
      }
      final input = File(p.join(root.path, 'input.txt'));
      if (topic.input case final String text) {
        await input.writeAsString(text);
      } else if (await input.exists()) {
        await input.delete();
      }
      await check(
        topic.exampleId,
        topic.code,
        type: topic.language,
        output: topic.output,
        exactOutput: true,
      );
    }
    debugPrintSynchronously(
      'QFLI_C_OHOS_AUDIT ${jsonEncode({'ok': true, 'passed': results.length, 'curriculum': forgeTopics.length})}',
    );
  } catch (error, stack) {
    debugPrintSynchronously(
      'QFLI_C_OHOS_AUDIT ${jsonEncode({'ok': false, 'case': current, 'error': error.toString(), 'stack': stack.toString(), 'passed': results})}',
    );
  } finally {
    await root.delete(recursive: true);
  }
}
