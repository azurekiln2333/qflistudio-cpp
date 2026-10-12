import 'dart:convert';
import 'dart:io';

import 'native_compiler_host.dart';
import 'forge_topic.dart';
import 'forge_topics.dart';

/// Verifies the authored C/C++ curriculum against the **staged aggregate rows**
/// (what the generator emits) and executes every sample on a genuine native
/// compiler.
///
/// Gate contract (`.trellis/tasks/10-12-c-cpp-substantive-curriculum/design.md`):
///   1. Cross-check every authored topic against its staged tutorial + example
///      rows; fail on any code/output/schema mismatch.
///   2. Compile + run every sample natively (WSL `qfli-java-build`: clang++ 18 /
///      g++ 13), diff stdout against the declared output, and diff stdin-driven
///      samples using the topic `input` fixture.
///   3. If the compiler is unavailable, fail with `compiler_unavailable` — a
///      hard environment failure, never an interpreter fallback.
///   4. Assert >= 100 C and >= 100 C++ topics, level balance, no duplicate
///      explain/summary/first-exercise within a language, and distinct C vs C++
///      concept coverage.
///   5. Record the exact `-std` and compiler version used per example.
///
/// Run from `qfli_c` AFTER generating:
///
///   dart run tool/forge_content/generate_forge_content.dart
///   dart run tool/forge_content/verify_forge_content.dart
Future<void> main(List<String> args) async {
  final requireNative = !args.contains('--no-native');
  final toolDir = Directory('${Directory.current.path}/tool/forge_content');
  final staging = Directory('${toolDir.path}/staging');

  final tutorialFile = File('${staging.path}/forge_tutorials.json');
  final exampleFile = File('${staging.path}/forge_examples.json');
  if (!tutorialFile.existsSync() || !exampleFile.existsSync()) {
    stderr.writeln('Staged rows missing. Run generate_forge_content.dart first.');
    exitCode = 2;
    return;
  }

  final tutorials = readEntries(tutorialFile, 'tutorials');
  final examples = readEntries(exampleFile, 'examples');

  final topics = forgeTopics;
  final cCount = topics.where((t) => t.isC).length;
  final cppCount = topics.length - cCount;
  stdout.writeln('Authored: ${topics.length} topics ($cCount C, $cppCount C++).');

  final native = WslNativeCompiler();
  if (requireNative) {
    final reason = await native.probe();
    stdout.writeln('Native clang++: ${native.clangVersion}');
    stdout.writeln('Native g++:     ${native.gccVersion}');
    if (reason != null) {
      stderr.writeln('compiler_unavailable: $reason');
      exitCode = 3;
      return;
    }
  }

  final tutorialErrors = <String>[];
  final exampleErrors = <String>[];
  var pass = 0;
  var fail = 0;
  final results = <Map<String, Object?>>[];
  final standardsUsed = <String, int>{};

  // Reject any authored standard above the app ceiling before executing: the
  // app cannot compile it, so a pass would be meaningless.
  for (final topic in topics) {
    if (!WslNativeCompiler.standardWithinCap(topic.language, topic.standard)) {
      exampleErrors.add(
        '${topic.exampleId}: standard ${topic.standard} exceeds the '
        '${topic.language == 'c' ? 'C17' : 'C++20'} app ceiling',
      );
    }
  }

  for (final topic in topics) {
    // --- staged-row cross-check ---
    final tutorial = tutorials[topic.tutorialId];
    final example = examples[topic.exampleId];
    final lessons = (tutorial?['lessons'] as List?) ?? const [];
    final lesson = lessons.isEmpty
        ? null
        : (lessons.first as Map).cast<String, Object?>();
    final crossMismatch = _crossCheck(topic, lesson, example);
    if (crossMismatch != null) {
      tutorialErrors.add('${topic.exampleId}: $crossMismatch');
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'asset_mismatch',
        'detail': crossMismatch,
      });
      fail++;
      continue;
    }

    // --- native execution of the emitted payload ---
    final emittedCode = example!['code'] as String;
    final emittedOutput = (example['expectedOutput'] as String)
        .replaceAll('\r\n', '\n')
        .trimRight();
    final fixtures = example['inputFixtures'];
    final stdinText = fixtures is Map && fixtures['stdin'] is String
        ? fixtures['stdin'] as String
        : null;

    if (!requireNative) {
      pass++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'staged_ok_no_native',
      });
      continue;
    }

    final run = await native.compileAndRun(
      language: topic.language,
      source: emittedCode,
      standard: topic.standard,
      stdinText: stdinText,
    );
    if (run.environmentUnavailable) {
      stderr.writeln('compiler_unavailable: ${run.unavailable}');
      exitCode = 3;
      return;
    }
    standardsUsed[run.standard] = (standardsUsed[run.standard] ?? 0) + 1;
    final actual = run.stdout.replaceAll('\r\n', '\n').trimRight();
    final actualErr = run.stderr.replaceAll('\r\n', '\n').trimRight();
    // A sample counts as verified ONLY when: compilation succeeded, the program
    // exited 0 on its own (not killed by the timeout), stdout is byte-exact, and
    // the program wrote nothing to stderr.
    if (run.compileFailed) {
      fail++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'compile_error',
        'standard': run.standard,
        'stderr': run.stderr,
      });
    } else if (run.timedOut) {
      fail++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'timeout',
        'standard': run.standard,
        'stderr': run.stderr,
      });
    } else if (run.exitCode != 0) {
      fail++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'nonzero_exit',
        'exitCode': run.exitCode,
        'standard': run.standard,
        'stdout': actual,
        'stderr': actualErr,
      });
    } else if (actual != emittedOutput) {
      fail++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'stdout_mismatch',
        'standard': run.standard,
        'expected': emittedOutput,
        'actual': actual,
        'stderr': actualErr,
      });
    } else if (actualErr.isNotEmpty) {
      fail++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'unexpected_stderr',
        'standard': run.standard,
        'stderr': actualErr,
      });
    } else {
      pass++;
      results.add(<String, Object?>{
        'id': topic.exampleId,
        'status': 'ok',
        'standard': run.standard,
        'compiler': run.compiler,
        'exitCode': run.exitCode,
      });
    }
  }

  // --- curriculum-shape assertions ---
  final shapeErrors = _checkShape(topics, tutorials, examples);

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'nativeRequired': requireNative,
    'clangVersion': native.clangVersion,
    'gccVersion': native.gccVersion,
    'cCount': cCount,
    'cppCount': cppCount,
    'standardsUsed': standardsUsed,
    'tutorialCount': tutorials.length,
    'exampleCount': examples.length,
    'stagedAssetErrors': tutorialErrors,
    'shapeErrors': shapeErrors,
    'passed': pass,
    'failed': fail,
    'results': results,
  };
  final reportFile = File(
    '${toolDir.parent.parent.path}/.trellis/tasks/10-12-c-cpp-substantive-curriculum/'
    'research/cpp-content-verification.json',
  );
  await reportFile.create(recursive: true);
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );

  stdout.writeln('Staged assets: ${tutorials.length} tutorials, ${examples.length} examples.');
  stdout.writeln('Native: $pass passed, $fail failed of ${topics.length}.');
  if (shapeErrors.isNotEmpty) {
    stdout.writeln('Shape errors (${shapeErrors.length}):');
    for (final e in shapeErrors.take(20)) {
      stdout.writeln('  - $e');
    }
  }
  stdout.writeln('Report: ${reportFile.path}');
  if (fail > 0 || shapeErrors.isNotEmpty || exampleErrors.isNotEmpty) {
    exitCode = 1;
  }
}

/// Returns a human mismatch description, or null when the staged rows match.
String? _crossCheck(
  ForgeTopic topic,
  Map<String, Object?>? lesson,
  Map<String, Object?>? example,
) {
  if (lesson == null) return 'missing tutorial lesson ${topic.tutorialId}';
  if (lesson['code'] != topic.code) return 'tutorial code mismatch';
  if (lesson['output'] != topic.output) return 'tutorial output mismatch';
  if (lesson['objective'] != topic.objective) return 'tutorial objective mismatch';
  if (!_sameList(lesson['pitfalls'], topic.pitfalls)) {
    return 'tutorial pitfalls mismatch';
  }
  if (!_sameList(lesson['prerequisites'], topic.prerequisites)) {
    return 'tutorial prerequisites mismatch';
  }
  if (example == null) return 'missing example ${topic.exampleId}';
  if (example['code'] != topic.code) return 'example code mismatch';
  if (example['expectedOutput'] != topic.output) {
    return 'example expectedOutput mismatch';
  }
  if (example['templateType'] != topic.language) {
    return 'example templateType mismatch';
  }
  if (example['sourceLessonId'] != '${topic.tutorialId}-lesson') {
    return 'example sourceLessonId mismatch';
  }
  return null;
}

List<String> _checkShape(
  List<ForgeTopic> topics,
  Map<String, Map<String, Object?>> tutorials,
  Map<String, Map<String, Object?>> examples,
) {
  final errors = <String>[];
  final cTutorials = tutorials.values.where((e) => e['language'] == 'c').length;
  final cppTutorials = tutorials.values.where((e) => e['language'] == 'cpp').length;
  final cExamples = examples.values.where((e) => e['language'] == 'c').length;
  final cppExamples = examples.values.where((e) => e['language'] == 'cpp').length;
  if (cTutorials < 100) errors.add('C tutorials $cTutorials < 100');
  if (cppTutorials < 100) errors.add('C++ tutorials $cppTutorials < 100');
  if (cExamples < 100) errors.add('C examples $cExamples < 100');
  if (cppExamples < 100) errors.add('C++ examples $cppExamples < 100');

  for (final lang in <String>['c', 'cpp']) {
    final group = topics.where((t) => t.language == lang).toList();
    final explains = <String>{};
    final summaries = <String>{};
    final exercises = <String>{};
    for (final t in group) {
      if (!explains.add(t.explain)) {
        errors.add('$lang duplicate explain: ${t.exampleId}');
      }
      if (!summaries.add(t.summary)) {
        errors.add('$lang duplicate summary: ${t.exampleId}');
      }
      if (t.tasks.isNotEmpty && !exercises.add(t.tasks.first.prompt)) {
        errors.add('$lang duplicate first exercise: ${t.exampleId}');
      }
    }
    final byLevel = <String, int>{};
    for (final t in group) {
      byLevel[t.level] = (byLevel[t.level] ?? 0) + 1;
    }
    for (final level in <String>['beginner', 'intermediate', 'advanced']) {
      if ((byLevel[level] ?? 0) == 0) {
        errors.add('$lang has no $level topics');
      }
    }
  }

  // C and C++ concept coverage must be genuinely distinct.
  final cConcepts = <String>{for (final t in topics.where((t) => t.isC)) ...t.concepts};
  final cppConcepts = <String>{for (final t in topics.where((t) => !t.isC)) ...t.concepts};
  final overlap = cConcepts.intersection(cppConcepts).length;
  final minSize = cConcepts.length < cppConcepts.length ? cConcepts.length : cppConcepts.length;
  if (minSize > 0 && overlap * 2 > minSize) {
    errors.add('C and C++ concept coverage too similar (overlap $overlap of $minSize)');
  }
  return errors;
}

bool _sameList(Object? value, List<String> expected) {
  if (value is! List) return expected.isEmpty;
  if (value.length != expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (value[i] != expected[i]) return false;
  }
  return true;
}

/// Reads `{entries: [...]}` from [file], keyed by row `id`.
Map<String, Map<String, Object?>> readEntries(File file, String kind) {
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = decoded['entries'] as List?;
  if (entries == null) {
    throw FormatException('$kind document has no entries array');
  }
  final result = <String, Map<String, Object?>>{};
  for (final raw in entries) {
    final map = (raw as Map).cast<String, Object?>();
    result[map['id'] as String] = map;
  }
  return result;
}
