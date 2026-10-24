import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/forge_content_repository.dart';
import 'package:qfli_studio_core/content/local_content_adapter.dart';
import 'package:qfli_studio_core/models/tutorial.dart';
import 'package:qfli_studio_core/services/code_import_service.dart';
import 'package:qfli_studio_core/services/file_backup.dart';

import '../tool/forge_content/forge_topics.dart';
import '../tool/forge_content/verify_forge_content.dart' as verifier;

const _stdinCases = <String, String>{
  'c-example-026': '17 5\n',
  'c-example-027': 'hello world\n',
  'cpp-example-004': '7 35\n',
  'cpp-example-021': 'Alice 25\nHello World\n',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('forge_tutorial_fixture_');
    FileBackup.baseOverride = root.path;
  });
  tearDown(() async {
    FileBackup.baseOverride = null;
    await root.delete(recursive: true);
  });

  for (final entry in _stdinCases.entries) {
    test(
      '${entry.key} tutorial materializes exact stdin from app assets',
      () async {
        final topic = forgeTopics.singleWhere(
          (topic) => topic.exampleId == entry.key,
        );
        expect(topic.input, entry.value);
        for (final portable in [false, true]) {
          final repository = ForgeContentRepository(portable: portable);
          final catalog = await repository.load();
          final lesson = catalog.tutorials
              .singleWhere((tutorial) => tutorial.id == topic.tutorialId)
              .lessons
              .single;
          final example = catalog.examples.singleWhere(
            (example) => example.id == entry.key,
          );

          // Assert raw production lessons first: the legacy adapter's paired
          // example fallback must not hide missing input in generated assets.
          expect(lesson.inputFixtures, {'stdin': entry.value});
          expect(example.inputFixtures, lesson.inputFixtures);
          final tutorial = await LocalContentAdapter.loadTutorial(
            repository: repository,
            language: topic.language,
            displayName: topic.isC ? 'C' : 'C++',
          );
          expect(tutorial, isNotNull);
          final projected = tutorial!.allLessons.singleWhere(
            (value) => value.id == lesson.id,
          );
          final snippet = await CodeImportService.openInEditor(
            example: ExampleCode(
              id: projected.id,
              type: projected.type,
              language: projected.language,
              level: projected.level,
              title: projected.title,
              summary: projected.summary,
              code: projected.code,
              output: projected.output,
              sourceLessonId: projected.id,
              concepts: projected.concepts,
              inputFixtures: projected.inputFixtures,
            ),
            fileName: topic.isC ? 'main.c' : 'main.cpp',
            location: root.path,
          );
          expect(
            await File(snippet.path).readAsBytes(),
            utf8.encode(topic.code),
          );
          expect(
            await File(p.join(snippet.project.path, 'input.txt')).readAsBytes(),
            utf8.encode(entry.value),
          );
        }
      },
    );
  }

  test('verifier accepts exactly the authored staged inventory and inputs', () {
    final (tutorials, examples) = _staged();
    expect(
      verifier.validateStagedContent(forgeTopics, tutorials, examples),
      isEmpty,
    );
  });

  test('verifier rejects missing, changed and additional stdin fixtures', () {
    final topic = forgeTopics.singleWhere(
      (topic) => topic.exampleId == 'c-example-026',
    );
    for (final kind in ['tutorial', 'example']) {
      for (final fixtures in <Object?>[
        null,
        {'stdin': '${topic.input}\r'},
        {'stdin': topic.input, 'data.txt': 'unowned data'},
        ['not a fixture map'],
      ]) {
        final (tutorials, examples) = _staged();
        final row = kind == 'tutorial'
            ? (tutorials[topic.tutorialId]!['lessons'] as List).single as Map
            : examples[topic.exampleId]!;
        row['inputFixtures'] = fixtures;
        expect(
          verifier.validateStagedContent(forgeTopics, tutorials, examples),
          contains('${topic.exampleId}: $kind inputFixtures mismatch'),
        );
      }
    }
    final (tutorials, examples) = _staged();
    examples['c-example-001']!['inputFixtures'] = {'stdin': 'unexpected\n'};
    expect(
      verifier.validateStagedContent(forgeTopics, tutorials, examples),
      contains('c-example-001: example inputFixtures mismatch'),
    );
  });

  test(
    'verifier rejects equal-count substitutions and duplicate authored IDs',
    () {
      final (tutorials, examples) = _staged();
      final removed = examples.remove('c-example-001')!;
      examples['c-example-999'] = {...removed, 'id': 'c-example-999'};
      final errors = verifier.validateStagedContent(
        forgeTopics,
        tutorials,
        examples,
      );
      expect(errors, contains('Missing authored example c-example-001'));
      expect(errors, contains('Unexpected staged example c-example-999'));

      final (completeTutorials, completeExamples) = _staged();
      expect(
        verifier.validateStagedContent(
          [...forgeTopics, forgeTopics.first],
          completeTutorials,
          completeExamples,
        ),
        contains('Duplicate authored topic c-example-001'),
      );
    },
  );

  test(
    'staged document reader rejects duplicate IDs instead of overwriting',
    () {
      for (final kind in ['tutorials', 'examples']) {
        final file = File(p.join(root.path, '$kind.json'));
        file.writeAsStringSync(
          jsonEncode({
            'entries': [
              {'id': 'duplicate', 'code': 'first'},
              {'id': 'duplicate', 'code': 'second'},
            ],
          }),
        );
        expect(
          () => verifier.readEntries(file, kind),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Duplicate $kind id duplicate',
            ),
          ),
        );
      }
    },
  );

  test(
    'verifier rejects jointly truncated authors and matching staged assets',
    () {
      final reduced = [
        for (final language in ['c', 'cpp'])
          for (final level in ['beginner', 'intermediate', 'advanced'])
            forgeTopics.firstWhere(
              (topic) => topic.language == language && topic.level == level,
            ),
      ];
      final (tutorials, examples) = _staged();
      final errors = verifier.validateStagedContent(
        reduced,
        {
          for (final topic in reduced)
            topic.tutorialId: tutorials[topic.tutorialId]!,
        },
        {
          for (final topic in reduced)
            topic.exampleId: examples[topic.exampleId]!,
        },
      );
      expect(
        errors,
        contains('Missing original authored example c-example-002'),
      );
      expect(
        errors,
        contains('Missing original authored example cpp-example-002'),
      );
    },
  );
}

(Map<String, Map<String, Object?>>, Map<String, Map<String, Object?>>)
_staged() => (
  verifier.readEntries(File(ForgeContentRepository.tutorialAsset), 'tutorials'),
  verifier.readEntries(File(ForgeContentRepository.exampleAsset), 'examples'),
);
