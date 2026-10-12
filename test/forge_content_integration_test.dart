import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/clang_runner.dart';
import 'package:qfli_c/main.dart' show forgeProfile;
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

import '../tool/forge_content/merge_forge_content.dart' as merge;

/// End-to-end integration checks for the authored C/C++ curriculum.
///
/// This is the integration counterpart to the per-track unit checks: it loads
/// the generated aggregate staging exactly the way the app's content repository
/// does, applies the real `forge` product filter, and runs representative
/// samples through the real desktop runner. It also pins the extension-selection
/// contract (a C++ row must import as `main.cpp`, never `main.c`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory.current.path;
  final staging = p.join(repoRoot, 'tool', 'forge_content', 'staging');
  final tutorialFile = File(p.join(staging, 'forge_tutorials.json'));
  final exampleFile = File(p.join(staging, 'forge_examples.json'));

  late ContentCatalog catalog;
  late List<TutorialContent> forgeTutorials;
  late List<ExampleContent> forgeExamples;
  final liveCoreDir = p.normalize(p.join(repoRoot, '..', 'qfli_studio_core'));
  final liveTutorials = File(
    p.join(liveCoreDir, 'assets', 'content', 'tutorials.json'),
  );
  final liveExamples = File(
    p.join(liveCoreDir, 'assets', 'content', 'examples.json'),
  );

  setUpAll(() {
    expect(
      tutorialFile.existsSync() && exampleFile.existsSync(),
      isTrue,
      reason: 'Run: dart run tool/forge_content/generate_forge_content.dart',
    );
    catalog = ContentCatalog.fromJson(
      tutorialsSource: tutorialFile.readAsStringSync(),
      examplesSource: exampleFile.readAsStringSync(),
    );
    const filter = ContentFilter(types: {'c', 'cpp'});
    forgeTutorials = catalog.tutorials.where(filter.matches).toList();
    forgeExamples = catalog.examples.where(filter.matches).toList();
  });

  group('repository load and forge filter', () {
    test('parses without throwing and exposes 100 C + 100 C++ each', () {
      final cTutorials = forgeTutorials.where((t) => t.type == 'c').length;
      final cppTutorials = forgeTutorials.where((t) => t.type == 'cpp').length;
      final cExamples = forgeExamples.where((e) => e.type == 'c').length;
      final cppExamples = forgeExamples.where((e) => e.type == 'cpp').length;
      expect(cTutorials, 100);
      expect(cppTutorials, 100);
      expect(cExamples, 100);
      expect(cppExamples, 100);
    });

    test('every C/C++ row carries all required schema fields', () {
      for (final t in forgeTutorials) {
        expect(t.id, isNotEmpty, reason: t.id);
        expect(t.language, isNotEmpty, reason: t.id);
        expect(t.type, anyOf('c', 'cpp'), reason: t.id);
        expect(t.level, anyOf('beginner', 'intermediate', 'advanced'), reason: t.id);
        expect(t.title, isNotEmpty, reason: t.id);
        expect(t.summary, isNotEmpty, reason: t.id);
        expect(t.concepts, isNotEmpty, reason: t.id);
        expect(t.source, isNotEmpty, reason: t.id);
        expect(t.license, isNotEmpty, reason: t.id);
        expect(t.updatedAt, isNotEmpty, reason: t.id);
        expect(t.lessons, isNotEmpty, reason: t.id);
        for (final lesson in t.lessons) {
          expect(lesson.id, isNotEmpty, reason: t.id);
          expect(lesson.title, isNotEmpty, reason: t.id);
          expect(lesson.summary, isNotEmpty, reason: t.id);
          expect(lesson.explain, isNotEmpty, reason: t.id);
          expect(lesson.code, isNotEmpty, reason: t.id);
          expect(lesson.output, isNotEmpty, reason: t.id);
          expect(lesson.concepts, isNotEmpty, reason: t.id);
          expect(lesson.objective, isNotEmpty, reason: '${t.id} objective');
          expect(lesson.pitfalls, isNotEmpty, reason: '${t.id} pitfalls');
        }
      }
      for (final e in forgeExamples) {
        expect(e.id, isNotEmpty, reason: e.id);
        expect(e.code, isNotEmpty, reason: e.id);
        expect(e.expectedOutput, isNotEmpty, reason: e.id);
        expect(e.templateType, anyOf('c', 'cpp'), reason: e.id);
        expect(e.sourceLessonId, isNotNull, reason: e.id);
      }
    });

    test('levels are balanced across beginner/intermediate/advanced', () {
      for (final lang in const ['c', 'cpp']) {
        final levels = <String, int>{};
        for (final t in forgeTutorials.where((t) => t.type == lang)) {
          levels[t.level] = (levels[t.level] ?? 0) + 1;
        }
        expect(levels['beginner'], greaterThanOrEqualTo(25), reason: lang);
        expect(levels['intermediate'], greaterThanOrEqualTo(25), reason: lang);
        expect(levels['advanced'], greaterThanOrEqualTo(25), reason: lang);
      }
    });
  });

  group('substantive, non-duplicated, distinct', () {
    test('no duplicate explain/summary/first-exercise within a language', () {
      for (final lang in const ['c', 'cpp']) {
        final rows = forgeTutorials.where((t) => t.type == lang);
        final explains = <String>{};
        final summaries = <String>{};
        final prompts = <String>{};
        for (final t in rows) {
          final lesson = t.lessons.first;
          expect(
            explains.add(lesson.explain),
            isTrue,
            reason: 'duplicate explain in $lang: ${t.id}',
          );
          expect(
            summaries.add(t.summary),
            isTrue,
            reason: 'duplicate summary in $lang: ${t.id}',
          );
          if (lesson.exercises.isNotEmpty) {
            expect(
              prompts.add(lesson.exercises.first.prompt),
              isTrue,
              reason: 'duplicate first exercise in $lang: ${t.id}',
            );
          }
        }
      }
    });

    test('C and C++ explanations are genuinely different', () {
      final cExplains = {
        for (final t in forgeTutorials.where((t) => t.type == 'c'))
          t.lessons.first.explain,
      };
      final cppExplains = {
        for (final t in forgeTutorials.where((t) => t.type == 'cpp'))
          t.lessons.first.explain,
      };
      expect(cExplains.intersection(cppExplains), isEmpty);
    });

    test('no placeholder padding signature remains', () {
      for (final e in forgeExamples) {
        expect(e.code.contains('weighted='), isFalse, reason: e.id);
        expect(e.code.trim().split('\n').length >= 2, isTrue, reason: e.id);
      }
    });
  });

  group('extension selection: type drives the file name', () {
    test('C++ rows use type cpp and C rows use type c', () {
      for (final e in forgeExamples) {
        if (e.language == 'cpp') {
          expect(e.type, 'cpp', reason: e.id);
          expect(e.templateType, 'cpp', reason: e.id);
        } else {
          expect(e.type, 'c', reason: e.id);
          expect(e.templateType, 'c', reason: e.id);
        }
      }
    });
  });

  group('live shared-core assets match the authored source', () {
    test('when the core is present, live C/C++ rows equal the staged rows', () {
      if (!liveTutorials.existsSync() || !liveExamples.existsSync()) {
        markTestSkipped('shared core not present at $liveCoreDir');
        return;
      }
      final liveCatalog = ContentCatalog.fromJson(
        tutorialsSource: liveTutorials.readAsStringSync(),
        examplesSource: liveExamples.readAsStringSync(),
      );
      const filter = ContentFilter(types: {'c', 'cpp'});
      final liveTut = liveCatalog.tutorials.where(filter.matches).toList();
      final liveEx = liveCatalog.examples.where(filter.matches).toList();
      expect(liveTut.length, forgeTutorials.length);
      expect(liveEx.length, forgeExamples.length);
      final stagedT = {
        for (final t in forgeTutorials) t.id: _tutorialFingerprint(t),
      };
      final liveT = {for (final t in liveTut) t.id: _tutorialFingerprint(t)};
      expect(liveT, stagedT);
      final stagedE = {
        for (final e in forgeExamples) e.id: _exampleFingerprint(e),
      };
      final liveE = {for (final e in liveEx) e.id: _exampleFingerprint(e)};
      expect(liveE, stagedE);
    });
  });

  group('scoped merge semantics (spec: metadata + language ownership)', () {
    test('updatedAt and all top-level metadata are preserved', () {
      final live = <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'tutorials',
        'updatedAt': '2020-01-01',
        'entries': <Map<String, dynamic>>[
          {'id': 'c-example-001', 'language': 'c', 'type': 'c', 'old': true},
          {'id': 'java-1', 'language': 'java', 'type': 'java'},
        ],
      };
      final staged = <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'tutorials',
        'updatedAt': '2099-12-31',
        'entries': <Map<String, dynamic>>[
          {'id': 'c-example-001', 'language': 'c', 'type': 'c', 'old': false},
        ],
      };
      final merged = merge.scopedMerge(live, staged).merged;
      expect(merged['updatedAt'], '2020-01-01');
      expect(merged['schemaVersion'], 1);
      expect(merged['kind'], 'tutorials');
      expect(merged['entries'].first['old'], isFalse);
    });

    test('a foreign row with type c but non-C/C++ language stays foreign', () {
      final live = <String, dynamic>{
        'kind': 'tutorials',
        'entries': <Map<String, dynamic>>[
          {'id': 'java-1', 'language': 'java', 'type': 'c'},
          {'id': 'cpp-example-001', 'language': 'cpp', 'type': 'cpp', 'v': 1},
        ],
      };
      final staged = <String, dynamic>{
        'kind': 'tutorials',
        'entries': <Map<String, dynamic>>[
          {'id': 'cpp-example-001', 'language': 'cpp', 'type': 'cpp', 'v': 2},
        ],
      };
      final merged = merge.scopedMerge(live, staged).merged;
      final java = merged['entries'].firstWhere((e) => e['id'] == 'java-1');
      expect(java['type'], 'c'); // untouched, not treated as owned
      expect(java.containsKey('v'), isFalse);
      final cpp = merged['entries'].firstWhere((e) => e['id'] == 'cpp-example-001');
      expect(cpp['v'], 2);
    });
  });

  group('real desktop run of representative samples', () {
    setUp(() => StudioProfile.current = forgeProfile);

    Future<(int, List<String>, List<String>)> runExample(
      ExampleContent example,
    ) async {
      final isCpp = example.type == 'cpp';
      final entryName = isCpp ? 'main.cpp' : 'main.c';
      final project = Directory.systemTemp.createTempSync('forge_content_run_');
      try {
        File(p.join(project.path, entryName)).writeAsStringSync(example.code);
        final stdinFixture = example.inputFixtures['stdin'];
        if (stdinFixture != null) {
          File(p.join(project.path, 'input.txt')).writeAsStringSync(stdinFixture);
        }
        final result = await ClangProgramRunner().run(
          projectPath: project.path,
          entryFile: p.join(project.path, entryName),
        );
        if (result == null) {
          fail('runner returned null for ${example.id}');
        }
        final out = await result.stdout.toList();
        final err = await result.stderr.toList();
        final code = await result.exitCode;
        return (code, out, err);
      } finally {
        project.deleteSync(recursive: true);
      }
    }

    test('a representative C example runs with exact expected output', () async {
      final example = forgeExamples.firstWhere((e) => e.id == 'c-example-100');
      final (code, out, err) = await runExample(example);
      expect(code, 0, reason: err.join('\n'));
      expect(err, isEmpty);
      expect(out.join('\n').trimRight(), example.expectedOutput.trimRight());
    });

    test('a representative C++ example runs with exact expected output', () async {
      final example = forgeExamples.firstWhere((e) => e.id == 'cpp-example-100');
      final (code, out, err) = await runExample(example);
      expect(code, 0, reason: err.join('\n'));
      expect(err, isEmpty);
      expect(out.join('\n').trimRight(), example.expectedOutput.trimRight());
    });

    test('input fixture round-trips through input.txt', () async {
      ExampleContent? withInput;
      for (final e in forgeExamples) {
        if (e.inputFixtures['stdin'] != null) {
          withInput = e;
          break;
        }
      }
      expect(withInput, isNotNull, reason: 'no example declares stdin fixture');
      final (code, out, err) = await runExample(withInput!);
      expect(code, 0, reason: err.join('\n'));
      expect(out.join('\n').trimRight(), withInput.expectedOutput.trimRight());
    });
  });
}

/// A stable fingerprint of a tutorial row covering everything the app renders
/// and runs: level, concepts, per-lesson code/output/exercises and pitfalls.
String _tutorialFingerprint(TutorialContent t) => jsonEncode(<Object?>[
  t.id, t.language, t.type, t.locale, t.level, t.title, t.summary, t.concepts,
  [
    for (final l in t.lessons)
      <Object?>[
        l.id, l.title, l.summary, l.concepts, l.objective, l.explain, l.code,
        l.output, l.pitfalls,
        <Object?>[for (final e in l.exercises) <Object?>[e.prompt, e.hint, e.answer]],
      ],
  ],
]);

/// A stable fingerprint of an example row (code + expected output + fixtures).
String _exampleFingerprint(ExampleContent e) => jsonEncode(<Object?>[
  e.id, e.language, e.type, e.level, e.title, e.summary, e.concepts, e.code,
  e.expectedOutput, e.inputFixtures, e.templateType, e.sourceLessonId,
]);
