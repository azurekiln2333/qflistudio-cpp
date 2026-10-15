import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/native_clang_runner.dart';

import 'forge_content/forge_topics.dart';

const _portable = bool.fromEnvironment('QFLI_OHOS_PORTABLE');

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
      _portable
          ? 'int main(void) { __builtin_trap(); }'
          : '#include <signal.h>\nint main(void) { raise(SIGSEGV); return 0; }',
      exit: _portable ? 125 : 139,
    );

    current = _portable
        ? 'cancel-interpreter-sleep'
        : 'cancel-parent-and-child';
    debugPrintSynchronously('QFLI_C_OHOS_START $current');
    final entry = File(p.join(root.path, 'main.c'));
    final heartbeat = File(p.join(root.path, 'heartbeat.txt'));
    final heartbeatLiteral = jsonEncode(
      _portable ? 'heartbeat.txt' : heartbeat.path,
    );
    await entry.writeAsString('''
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <unistd.h>
#include <time.h>
int main(void) {
  ${_portable ? '' : 'if (fork() == 0) {'}
  ${_portable ? '' : 'for (;;) { FILE *f = fopen($heartbeatLiteral, "a"); if (f) { fputs("x", f); fclose(f); } usleep(50000); } }'}
  puts("loop-started"); fflush(stdout);
  ${_portable ? 'for (;;) { FILE *f = fopen($heartbeatLiteral, "a"); if (f) { fputs("x", f); fclose(f); } struct timespec delay = {0, 50000000}; nanosleep(&delay, 0); }' : 'for (;;) usleep(50000);'}
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
      await Future.any<void>([
        started.future,
        run.exitCode.then((code) async {
          throw StateError(
            'Cancel fixture exited before start: $code ${(await errors).join('\n')}',
          );
        }),
      ]).timeout(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await run.cancel!().timeout(const Duration(seconds: 10));
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
      await run.cancel?.call().timeout(const Duration(seconds: 10));
      await subscription.cancel();
    }
    if (_portable) {
      await entry.delete();
      current = 'cancel-C++-CPU-and-sleep-threads';
      debugPrintSynchronously('QFLI_C_OHOS_START $current');
      final threadedEntry = File(p.join(root.path, 'main.cpp'));
      await threadedEntry.writeAsString('''
#include <atomic>
#include <chrono>
#include <cstdio>
#include <thread>
int main() {
  std::thread cpu([] {
    std::atomic<unsigned> value{0};
    for (;;) value.fetch_add(1, std::memory_order_relaxed);
  });
  std::thread sleeper([] { std::this_thread::sleep_for(std::chrono::seconds(30)); });
  puts("threads-started"); fflush(stdout);
  cpu.join(); sleeper.join();
}
''');
      final threadedRun = await runner.run(
        type: 'cpp',
        projectPath: root.path,
        entryFile: threadedEntry.path,
      );
      if (threadedRun == null) throw StateError('C++ threads unavailable');
      final threadsStarted = Completer<void>();
      final threadOutput = threadedRun.stdout.listen((line) {
        if (line == 'threads-started' && !threadsStarted.isCompleted) {
          threadsStarted.complete();
        }
      });
      final threadErrors = threadedRun.stderr.toList();
      try {
        await Future.any<void>([
          threadsStarted.future,
          threadedRun.exitCode.then((code) async {
            throw StateError(
              'Thread fixture exited before start: $code ${(await threadErrors).join('\n')}',
            );
          }),
        ]).timeout(const Duration(seconds: 60));
        await threadedRun.cancel!().timeout(const Duration(seconds: 10));
        final code = await threadedRun.exitCode.timeout(
          const Duration(seconds: 10),
        );
        final errors = await threadErrors;
        if (code != 130 || errors.isNotEmpty) {
          throw StateError(
            'C++ thread cancellation failed: exit=$code ${errors.join('\n')}',
          );
        }
        results.add(current);
        debugPrintSynchronously(
          'QFLI_C_OHOS_CASE ${jsonEncode({'name': current, 'exit': code})}',
        );
      } finally {
        await threadedRun.cancel?.call().timeout(const Duration(seconds: 10));
        await threadOutput.cancel();
        await threadedEntry.delete();
      }
    }
    if (_portable) {
      await check(
        'C++-concurrent-memory-growth',
        r'''#include <atomic>
#include <cstdio>
#include <thread>

static std::atomic<unsigned> seen[4096]{};

int main() {
  constexpr int per_thread = 128;
  constexpr int expected = 2 * per_thread;
  std::atomic<int> ready{0}, unique{0}, failures{0};
  std::atomic<bool> start{false};
  auto grow = [&] {
    ready.fetch_add(1, std::memory_order_release);
    while (!start.load(std::memory_order_acquire)) std::this_thread::yield();
    for (int index = 0; index < per_thread; ++index) {
      const size_t old_pages = __builtin_wasm_memory_grow(0, 1);
      if (old_pages == static_cast<size_t>(-1) || old_pages >= 4096) {
        failures.fetch_add(1);
      } else if (seen[old_pages].fetch_add(1) == 0) {
        unique.fetch_add(1);
      }
    }
  };
  std::thread left(grow), right(grow);
  while (ready.load(std::memory_order_acquire) != 2) std::this_thread::yield();
  // Both guest stacks and their startup allocations exist before this sample.
  const size_t before = __builtin_wasm_memory_size(0);
  start.store(true, std::memory_order_release);
  left.join();
  right.join();
  const size_t added = __builtin_wasm_memory_size(0) - before;
  std::printf("memory.grow pages=%zu unique=%d\n", added, unique.load());
  return added == expected && unique.load() == expected && failures.load() == 0 ? 0 : 8;
}
''',
        type: 'cpp',
        output: 'memory.grow pages=256 unique=256',
        exactOutput: true,
      );
      await File(p.join(root.path, 'main.cpp')).delete();
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
        output: _portable ? topic.portableOutput ?? topic.output : topic.output,
        exactOutput: true,
      );
    }
    debugPrintSynchronously(
      'QFLI_C_OHOS_AUDIT ${jsonEncode({'ok': true, 'execution': _portable ? 'interpreter' : 'native', 'passed': results.length, 'curriculum': forgeTopics.length})}',
    );
  } catch (error, stack) {
    debugPrintSynchronously(
      'QFLI_C_OHOS_AUDIT ${jsonEncode({'ok': false, 'execution': _portable ? 'interpreter' : 'native', 'case': current, 'error': error.toString(), 'stack': stack.toString(), 'passed': results})}',
    );
  } finally {
    await root.delete(recursive: true);
  }
}
