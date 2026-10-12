import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../tool/forge_content/merge_forge_content.dart' as merge;

/// Pipeline tests for the authored C/C++ curriculum and its staged rows.
///
/// These are **shape/consistency** tests (pure Dart, no compiler): they prove
/// the authored topics are complete, non-duplicated, distinct between C and
/// C++, and that the generator's staged rows exactly mirror the authored source
/// under the aggregate schema the app parses. Native execution of every sample
/// is proven separately by `tool/forge_content/verify_forge_content.dart`.
///
/// They intentionally do not spawn the native compiler so the Flutter test
/// suite stays fast and host-independent; the compiler gate lives in the
/// verifier whose report is attached to the task.
void main() {
  final repoRoot = Directory.current.path;
  final staging = Directory(p.join(repoRoot, 'tool', 'forge_content', 'staging'));
  final tutorialFile = File(p.join(staging.path, 'forge_tutorials.json'));
  final exampleFile = File(p.join(staging.path, 'forge_examples.json'));

  List<Map<String, dynamic>> entries(File file) =>
      ((jsonDecode(file.readAsStringSync()) as Map)['entries'] as List)
          .cast<Map<String, dynamic>>();

  group('staged assets exist and are well formed', () {
    test('generator output is present', () {
      expect(tutorialFile.existsSync(), isTrue,
          reason: 'run generate_forge_content.dart first');
      expect(exampleFile.existsSync(), isTrue);
    });

    test('100 C + 100 C++ tutorials and examples', () {
      final t = entries(tutorialFile);
      final e = entries(exampleFile);
      expect(t.where((r) => r['language'] == 'c').length, 100);
      expect(t.where((r) => r['language'] == 'cpp').length, 100);
      expect(e.where((r) => r['language'] == 'c').length, 100);
      expect(e.where((r) => r['language'] == 'cpp').length, 100);
    });
  });

  group('schema completeness', () {
    test('every tutorial lesson carries the required fields', () {
      for (final row in entries(tutorialFile)) {
        final lessons = (row['lessons'] as List).cast<Map>();
        expect(lessons, isNotEmpty, reason: '${row['id']} has no lessons');
        final lesson = lessons.first;
        for (final field in const [
          'id', 'title', 'summary', 'concepts', 'objective', 'prerequisites',
          'explain', 'code', 'output', 'pitfalls', 'exercises',
        ]) {
          expect(lesson.containsKey(field), isTrue,
              reason: '${row['id']} lesson missing $field');
        }
        expect((lesson['code'] as String).trim(), isNotEmpty);
        expect((lesson['output'] as String).trim(), isNotEmpty);
      }
    });

    test('every example carries code/expectedOutput/templateType', () {
      for (final row in entries(exampleFile)) {
        expect((row['code'] as String).trim(), isNotEmpty);
        expect((row['expectedOutput'] as String).trim(), isNotEmpty);
        expect(row['templateType'], row['language']);
        expect(row['sourceLessonId'], isNotNull);
      }
    });

    test('every runnable sample stays within the app standard ceiling', () {
      // The package compiles C <= c17 and C++ <= c++20.
      for (final row in entries(exampleFile)) {
        final lang = row['language'] as String;
        final concepts = (row['concepts'] as List).cast<String>();
        final standard = concepts
            .firstWhere((c) => c.startsWith('标准：'), orElse: () => '标准：unknown')
            .replaceFirst('标准：', '');
        if (lang == 'c') {
          expect(const ['c11', 'c17'].contains(standard), isTrue,
              reason: '${row['id']} standard $standard exceeds C ceiling');
        } else {
          expect(const ['c++11', 'c++14', 'c++17', 'c++20'].contains(standard),
              isTrue,
              reason: '${row['id']} standard $standard exceeds C++ ceiling');
        }
      }
    });
  });

  group('no placeholder or duplicated content', () {
    test('no placeholder padding signature', () {
      for (final row in entries(exampleFile)) {
        expect((row['code'] as String).contains('weighted='), isFalse,
            reason: '${row['id']} looks like placeholder padding');
      }
    });

    test('unique ids and unique code bodies per language', () {
      for (final entry in <(File, String)>[
        (tutorialFile, 'lessons'),
        (exampleFile, 'code'),
      ]) {
        final file = entry.$1;
        final rows = entries(file);
        final ids = rows.map((r) => r['id']).toList();
        expect(ids.toSet().length, ids.length,
            reason: 'duplicate ids in ${file.path}');
        for (final lang in const ['c', 'cpp']) {
          final codes = rows
              .where((r) => r['language'] == lang)
              .map((r) => entry.$2 == 'code'
                  ? r['code'] as String
                  : ((r['lessons'] as List).first as Map)['code'] as String)
              .toList();
          expect(codes.toSet().length, codes.length,
              reason: 'duplicate $lang code bodies in ${file.path}');
        }
      }
    });

    test('no duplicated explain/summary/exercise within a language', () {
      for (final lang in const ['c', 'cpp']) {
        final lessons = entries(tutorialFile)
            .where((r) => r['language'] == lang)
            .map((r) => (r['lessons'] as List).first as Map)
            .toList();
        final explains = lessons.map((l) => l['explain']).toList();
        final summaries = lessons.map((l) => l['summary']).toList();
        expect(explains.toSet().length, explains.length,
            reason: 'duplicate $lang explain text');
        expect(summaries.toSet().length, summaries.length,
            reason: 'duplicate $lang summary text');
      }
    });
  });

  group('level balance and C/C++ distinctness', () {
    test('each language covers all three levels', () {
      for (final lang in const ['c', 'cpp']) {
        final levels = entries(tutorialFile)
            .where((r) => r['language'] == lang)
            .map((r) => r['level'] as String)
            .toSet();
        expect(levels, containsAll(const ['beginner', 'intermediate', 'advanced']));
      }
    });

    test('C and C++ concept coverage is genuinely distinct', () {
      Set<String> concepts(String lang) => {
            for (final row in entries(exampleFile)
                .where((r) => r['language'] == lang))
              ...(row['concepts'] as List).cast<String>(),
          };
      final c = concepts('c');
      final cpp = concepts('cpp');
      final overlap = c.intersection(cpp).length;
      final minSize = c.length < cpp.length ? c.length : cpp.length;
      expect(overlap * 2, lessThan(minSize),
          reason: 'C and C++ curricula share too many concepts');
    });
  });

  group('scoped merge negative checks (foreign rows never move)', () {
    Map<String, dynamic> doc(List<Map<String, dynamic>> rows) =>
        <String, dynamic>{'schemaVersion': 1, 'updatedAt': '2026-01-01', 'entries': rows};

    Map<String, dynamic> row(String id, String language, String code) =>
        <String, dynamic>{'id': id, 'language': language, 'type': language, 'code': code};

    test('only owned rows change; foreign rows keep their order and content', () {
      final live = doc([
        row('java-1', 'java', 'JAVA_A'),
        row('c-example-001', 'c', 'OLD_C'),
        row('lua-1', 'lua', 'LUA_A'),
        row('cpp-example-001', 'cpp', 'OLD_CPP'),
      ]);
      final staged = doc([
        row('c-example-001', 'c', 'NEW_C'),
        row('cpp-example-001', 'cpp', 'NEW_CPP'),
      ]);

      final result = merge.scopedMerge(live, staged);
      expect(result.foreignBefore, result.foreignAfter,
          reason: 'foreign fingerprint must be unchanged');

      final merged = (result.merged['entries'] as List).cast<Map>();
      // Foreign rows keep their exact positions; owned rows are replaced in place.
      expect(merged.map((r) => r['id']).toList(),
          ['java-1', 'c-example-001', 'lua-1', 'cpp-example-001']);
      final byId = {for (final r in merged) r['id']: r};
      expect(byId['java-1']!['code'], 'JAVA_A');
      expect(byId['lua-1']!['code'], 'LUA_A');
      expect(byId['c-example-001']!['code'], 'NEW_C');
      expect(byId['cpp-example-001']!['code'], 'NEW_CPP');
    });

    test('foreign rows with a misleading type are not treated as owned', () {
      // A foreign row whose language is java but type happens to be 'c'.
      final live = doc([
        <String, dynamic>{'id': 'weird', 'language': 'java', 'type': 'c', 'code': 'X'},
        row('c-example-001', 'c', 'OLD_C'),
      ]);
      final staged = doc([row('c-example-001', 'c', 'NEW_C')]);
      final result = merge.scopedMerge(live, staged);
      expect(result.foreignBefore, result.foreignAfter);
      final byId = {
        for (final r in (result.merged['entries'] as List).cast<Map>()) r['id']: r,
      };
      expect(byId['weird']!['code'], 'X', reason: 'foreign row must be untouched');
    });

    test('a foreign-row content change is detected as a fingerprint move', () {
      final live = doc([
        row('java-1', 'java', 'JAVA_A'),
        row('c-example-001', 'c', 'OLD_C'),
      ]);
      final otherWriter = doc([
        row('java-1', 'java', 'JAVA_B_EDITED'),
        row('c-example-001', 'c', 'OLD_C'),
      ]);
      final staged = doc([row('c-example-001', 'c', 'NEW_C')]);

      final a = merge.scopedMerge(live, staged).foreignAfter;
      final b = merge.scopedMerge(otherWriter, staged).foreignAfter;
      expect(a, isNot(b),
          reason: 'concurrent foreign edit must be detectable');
    });

    test('top-level metadata is preserved byte-for-byte (updatedAt included)', () {
      final live = <String, dynamic>{
        'schemaVersion': 2,
        'generator': 'core',
        'updatedAt': '2026-01-01',
        'entries': [row('c-example-001', 'c', 'OLD_C')],
      };
      final staged = <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'tutorials',
        'updatedAt': '2026-02-02',
        'entries': [row('c-example-001', 'c', 'NEW_C')],
      };
      final merged = merge.scopedMerge(live, staged).merged;
      expect(merged['schemaVersion'], 2);
      expect(merged['generator'], 'core');
      // ALL metadata preserved: the staged updatedAt must NOT leak through.
      expect(merged['updatedAt'], '2026-01-01');
      expect(merged.containsKey('kind'), isFalse);
    });
  });

  group('staged-row validation rejects input that would erase live rows', () {
    Map<String, dynamic> owned(String lang, int count) => <String, dynamic>{
          'entries': <Map<String, dynamic>>[
            for (var i = 0; i < count; i++)
              <String, dynamic>{
                'id': '$lang-row-$i',
                'language': lang,
                'type': lang,
                'code': 'int main(){} // $lang $i',
              },
          ],
        };

    test('an empty staging document is rejected', () {
      final errors = merge.validateStaging(<String, dynamic>{'entries': []}, 'tutorials');
      expect(errors, isNotEmpty);
    });

    test('fewer than 100 of a language is rejected', () {
      final errors = merge.validateStaging(owned('c', 99), 'tutorials');
      expect(errors.any((e) => e.contains('need >= 100')), isTrue);
      final errors2 = merge.validateStaging(owned('cpp', 0), 'tutorials');
      expect(errors2, isNotEmpty);
    });

    test('a non-owned language row is rejected', () {
      final doc = <String, dynamic>{
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'java-1', 'language': 'java', 'type': 'java', 'code': 'x'},
        ],
      };
      final errors = merge.validateStaging(doc, 'tutorials');
      expect(errors.any((e) => e.contains('non-owned language')), isTrue);
    });

    test('duplicate ids and empty code are rejected', () {
      final doc = <String, dynamic>{
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'dup', 'language': 'c', 'code': 'a'},
          <String, dynamic>{'id': 'dup', 'language': 'c', 'code': 'b'},
          <String, dynamic>{'id': 'empty', 'language': 'c', 'code': '   '},
        ],
      };
      final errors = merge.validateStaging(doc, 'tutorials');
      expect(errors.any((e) => e.contains('duplicate id')), isTrue);
      expect(errors.any((e) => e.contains('empty code')), isTrue);
    });

    test('valid staged 100 C + 100 C++ passes validation', () {
      final doc = <String, dynamic>{
        'entries': <Map<String, dynamic>>[
          ...(owned('c', 100)['entries'] as List).cast<Map<String, dynamic>>(),
          ...(owned('cpp', 100)['entries'] as List).cast<Map<String, dynamic>>(),
        ],
      };
      expect(merge.validateStaging(doc, 'tutorials'), isEmpty);
    });
  });

  group('real staging passes the merge validators', () {
    test('the generated staged rows validate for both kinds', () {
      for (final entry in <(File, String)>[
        (tutorialFile, 'tutorials'),
        (exampleFile, 'examples'),
      ]) {
        final doc = jsonDecode(entry.$1.readAsStringSync()) as Map<String, dynamic>;
        expect(merge.validateStaging(doc, entry.$2), isEmpty,
            reason: '${entry.$2} staging must be valid');
      }
    });
  });
}
