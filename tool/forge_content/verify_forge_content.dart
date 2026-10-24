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
///   4. Match the complete authored ID inventory, level balance, no duplicate
///      explain/summary/first-exercise within a language, and distinct C vs C++
///      concept coverage.
///   5. Record the exact `-std` and compiler version used per example.
///
/// Run from `qfli_c` AFTER generating:
///
///   dart run tool/forge_content/generate_forge_content.dart
///   dart run tool/forge_content/verify_forge_content.dart
Future<void> main(List<String> args) async {
  var reportPath = 'native/build/forge-content-verification.json';
  for (var index = 0; index < args.length; index++) {
    if (args[index] == '--no-native') continue;
    if (args[index] == '--report' && index + 1 < args.length) {
      reportPath = args[++index];
      continue;
    }
    stderr.writeln(
      'Usage: verify_forge_content.dart [--no-native] [--report path]',
    );
    exitCode = 2;
    return;
  }
  final requireNative = !args.contains('--no-native');
  final toolDir = Directory('${Directory.current.path}/tool/forge_content');
  final staging = Directory('${toolDir.path}/staging');

  final tutorialFile = File('${staging.path}/forge_tutorials.json');
  final exampleFile = File('${staging.path}/forge_examples.json');
  if (!tutorialFile.existsSync() || !exampleFile.existsSync()) {
    stderr.writeln(
      'Staged rows missing. Run generate_forge_content.dart first.',
    );
    exitCode = 2;
    return;
  }

  final tutorials = readEntries(tutorialFile, 'tutorials');
  final examples = readEntries(exampleFile, 'examples');

  final topics = forgeTopics;
  final cCount = topics.where((t) => t.isC).length;
  final cppCount = topics.length - cCount;
  stdout.writeln(
    'Authored: ${topics.length} topics ($cCount C, $cppCount C++).',
  );

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
    final lesson = _singleLesson(tutorial);
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
  final shapeErrors = validateStagedContent(topics, tutorials, examples);

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
  // A fresh audit must not overwrite the historical task's accepted evidence.
  final reportFile = File(reportPath);
  await reportFile.create(recursive: true);
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );

  stdout.writeln(
    'Staged assets: ${tutorials.length} tutorials, ${examples.length} examples.',
  );
  final gate = requireNative ? 'Native' : 'Staged consistency (no execution)';
  stdout.writeln('$gate: $pass passed, $fail failed of ${topics.length}.');
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
  if (lesson['id'] != '${topic.tutorialId}-lesson') {
    return 'tutorial lesson id mismatch';
  }
  if (lesson['code'] != topic.code) return 'tutorial code mismatch';
  if (lesson['output'] != topic.output) return 'tutorial output mismatch';
  if (lesson['portableOutput'] != topic.portableOutput) {
    return 'tutorial portable output mismatch';
  }
  if (lesson['objective'] != topic.objective) {
    return 'tutorial objective mismatch';
  }
  if (!_sameList(lesson['pitfalls'], topic.pitfalls)) {
    return 'tutorial pitfalls mismatch';
  }
  if (!_sameList(lesson['prerequisites'], topic.prerequisites)) {
    return 'tutorial prerequisites mismatch';
  }
  if (!_sameInput(lesson['inputFixtures'], topic.input)) {
    return 'tutorial inputFixtures mismatch';
  }
  if (example == null) return 'missing example ${topic.exampleId}';
  if (example['code'] != topic.code) return 'example code mismatch';
  if (example['expectedOutput'] != topic.output) {
    return 'example expectedOutput mismatch';
  }
  if (example['portableExpectedOutput'] != topic.portableOutput) {
    return 'example portable output mismatch';
  }
  if (example['templateType'] != topic.language) {
    return 'example templateType mismatch';
  }
  if (example['sourceLessonId'] != '${topic.tutorialId}-lesson') {
    return 'example sourceLessonId mismatch';
  }
  if (!_sameInput(example['inputFixtures'], topic.input)) {
    return 'example inputFixtures mismatch';
  }
  return null;
}

/// Checks the complete staged inventory without invoking a compiler.
///
/// Counts alone cannot detect an omitted authored row replaced by an unrelated
/// row, or a lesson that loses the stdin required by its paired example.
List<String> validateStagedContent(
  List<ForgeTopic> topics,
  Map<String, Map<String, Object?>> tutorials,
  Map<String, Map<String, Object?>> examples,
) {
  final errors = <String>[];
  final tutorialIds = <String>{};
  final exampleIds = <String>{};
  if (topics.isEmpty) errors.add('No authored topics');
  for (final topic in topics) {
    final uniqueTutorial = tutorialIds.add(topic.tutorialId);
    final uniqueExample = exampleIds.add(topic.exampleId);
    if (!uniqueTutorial || !uniqueExample) {
      errors.add('Duplicate authored topic ${topic.exampleId}');
    }
    if (topic.language != 'c' && topic.language != 'cpp') {
      errors.add('${topic.exampleId}: unsupported authored language');
    }
  }
  // Preserve every original lesson independently of the supplied author list.
  // Exact equality alone would also accept jointly truncated or renamed sets.
  for (final language in ['c', 'cpp']) {
    for (var id = 1; id <= 100; id++) {
      final originalId = '$language-example-${id.toString().padLeft(3, '0')}';
      if (!exampleIds.contains(originalId)) {
        errors.add('Missing original authored example $originalId');
      }
    }
  }
  for (final (kind, expected, actual) in [
    ('tutorial', tutorialIds, tutorials.keys.toSet()),
    ('example', exampleIds, examples.keys.toSet()),
  ]) {
    for (final id in expected.difference(actual).toList()..sort()) {
      errors.add('Missing authored $kind $id');
    }
    for (final id in actual.difference(expected).toList()..sort()) {
      errors.add('Unexpected staged $kind $id');
    }
  }
  for (final topic in topics) {
    final tutorial = tutorials[topic.tutorialId];
    final example = examples[topic.exampleId];
    for (final (kind, row) in [('tutorial', tutorial), ('example', example)]) {
      if (row != null &&
          (row['language'] != topic.language ||
              row['type'] != topic.language)) {
        errors.add('${topic.exampleId}: $kind language/type mismatch');
      }
    }
    final mismatch = _crossCheck(topic, _singleLesson(tutorial), example);
    if (mismatch != null) errors.add('${topic.exampleId}: $mismatch');
  }

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
  final cConcepts = <String>{
    for (final t in topics.where((t) => t.isC)) ...t.concepts,
  };
  final cppConcepts = <String>{
    for (final t in topics.where((t) => !t.isC)) ...t.concepts,
  };
  final overlap = cConcepts.intersection(cppConcepts).length;
  final minSize = cConcepts.length < cppConcepts.length
      ? cConcepts.length
      : cppConcepts.length;
  if (minSize > 0 && overlap * 2 > minSize) {
    errors.add(
      'C and C++ concept coverage too similar (overlap $overlap of $minSize)',
    );
  }
  return errors;
}

Map<String, Object?>? _singleLesson(Map<String, Object?>? tutorial) {
  final lessons = tutorial?['lessons'];
  if (lessons is! List || lessons.length != 1 || lessons.single is! Map) {
    return null;
  }
  return (lessons.single as Map).cast<String, Object?>();
}

bool _sameInput(Object? fixtures, String? input) {
  if (fixtures == null) return input == null;
  if (fixtures is! Map) return false;
  if (input == null) return fixtures.isEmpty;
  return fixtures.length == 1 && fixtures['stdin'] == input;
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
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map || decoded['entries'] is! List) {
    throw FormatException('$kind document has no entries array');
  }
  final entries = decoded['entries'] as List;
  final result = <String, Map<String, Object?>>{};
  for (final raw in entries) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty) {
      throw FormatException('$kind entry has no non-empty string id');
    }
    final id = raw['id'] as String;
    if (result.containsKey(id)) {
      throw FormatException('Duplicate $kind id $id');
    }
    result[id] = raw.cast<String, Object?>();
  }
  return result;
}
