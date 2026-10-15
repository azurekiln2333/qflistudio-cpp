import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'forge_topic.dart';
import 'forge_topics.dart';

/// Emits the C/C++ replacement rows into a **local staging** directory.
///
/// This generator never writes the shared core. It reads the authored
/// [forgeTopics] and writes two aggregate-shaped documents plus a manifest under
/// `tool/forge_content/staging/`. The coordinator-gated merge step (owned by the
/// C++ track) copies only the `{c, cpp}` rows from these files into
/// `qfli_studio_core/assets/content/{tutorials,examples}.json` as a coordinated,
/// freshness-checked, fingerprint-guarded write.
///
/// Run from `qfli_c`:
///
///   dart run tool/forge_content/generate_forge_content.dart
Future<void> main(List<String> args) async {
  // Resolve staging against the repository root (the directory that contains
  // `pubspec.yaml`), not the entry script path, so running either the public
  // entry (`tool/generate_forge_content.dart`) or this file lands in the same
  // `tool/forge_content/staging/`.
  final staging = Directory(
    p.join(_repoRoot(), 'tool', 'forge_content', 'staging'),
  )..createSync(recursive: true);

  final topics = forgeTopics;
  _check(topics);

  final stamp = _stamp();
  final tutorialRows = <Map<String, dynamic>>[
    for (final t in topics) _tutorialEntry(t, stamp),
  ];
  final exampleRows = <Map<String, dynamic>>[
    for (final t in topics) _exampleEntry(t, stamp),
  ];

  await _writeJson(
    File(p.join(staging.path, 'forge_tutorials.json')),
    <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'tutorials',
      'updatedAt': stamp,
      'entries': tutorialRows,
    },
  );
  await _writeJson(
    File(p.join(staging.path, 'forge_examples.json')),
    <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'examples',
      'updatedAt': stamp,
      'entries': exampleRows,
    },
  );

  final c = topics.where((t) => t.isC).length;
  final cpp = topics.length - c;
  await _writeJson(
    File(p.join(staging.path, 'forge_manifest.json')),
    <String, dynamic>{
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'tutorialCount': tutorialRows.length,
      'exampleCount': exampleRows.length,
      'cCount': c,
      'cppCount': cpp,
      'standards': <String, int>{
        for (final s in topics.map((t) => t.standard).toSet())
          s: topics.where((t) => t.standard == s).length,
      },
      'tutorialIds': <String>[for (final t in topics) t.tutorialId],
      'exampleIds': <String>[for (final t in topics) t.exampleId],
    },
  );

  stdout.writeln(
    'Staged ${tutorialRows.length} tutorials + ${exampleRows.length} examples '
    '($c C, $cpp C++) into ${p.relative(staging.path, from: Directory.current.path)}.',
  );
}

void _check(List<ForgeTopic> topics) {
  if (topics.isEmpty) throw StateError('No topics authored');
  final ids = <String>{};
  final titles = <String>{};
  final codes = <String>{};
  for (final t in topics) {
    if (!ids.add(t.tutorialId)) {
      throw StateError('Duplicate tutorial id ${t.tutorialId}');
    }
    if (!titles.add('${t.language}:${t.title}')) {
      throw StateError('Duplicate title within ${t.language}: ${t.title}');
    }
    if (t.code.trim().split('\n').length < 2) {
      throw StateError('Topic ${t.exampleId} code is not multi-line');
    }
    if (t.code.contains('weighted=')) {
      throw StateError('Topic ${t.exampleId} looks like placeholder padding');
    }
    if (!codes.add(t.code)) {
      throw StateError('Duplicate code body for ${t.exampleId}');
    }
    if (t.output.trim().isEmpty) {
      throw StateError('Topic ${t.exampleId} has empty output');
    }
    if (t.objective.trim().isEmpty ||
        t.pitfalls.isEmpty ||
        t.concepts.isEmpty ||
        t.standard.trim().isEmpty) {
      throw StateError('Topic ${t.exampleId} is missing required fields');
    }
  }
}

Map<String, dynamic> _tutorialEntry(ForgeTopic t, String stamp) =>
    <String, dynamic>{
      'id': t.tutorialId,
      'language': t.language,
      'type': t.language,
      'locale': 'zh-CN',
      'level': t.level,
      'title': t.title,
      'summary': t.summary,
      'concepts': t.concepts,
      'source': t.isC ? 'QFLI C 教程（原创）' : 'QFLI C++ 教程（原创）',
      'license': 'Original QFLI curriculum. CC BY 4.0',
      'updatedAt': stamp,
      'lessons': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '${t.tutorialId}-lesson',
          'title': t.title,
          'summary': t.summary,
          'concepts': t.concepts,
          'objective': t.objective,
          'prerequisites': t.prerequisites,
          'explain': t.explain,
          'code': t.code,
          'output': t.output,
          if (t.portableOutput != null) 'portableOutput': t.portableOutput,
          'pitfalls': t.pitfalls,
          'exercises': <Map<String, String>>[
            for (final task in t.tasks)
              <String, String>{
                'prompt': task.prompt,
                'hint': task.hint,
                'answer': task.answer,
              },
          ],
        },
      ],
    };

Map<String, dynamic> _exampleEntry(ForgeTopic t, String stamp) =>
    <String, dynamic>{
      'id': t.exampleId,
      'language': t.language,
      'type': t.language,
      'locale': 'zh-CN',
      'level': t.level,
      'title': '示例 ${t.paddedId}：${_topicName(t.title)}',
      'summary': t.summary,
      'concepts': <String>[...t.concepts, '标准：${t.standard}'],
      'source': t.isC ? 'QFLI C 示例（原创）' : 'QFLI C++ 示例（原创）',
      'license': 'Original QFLI curriculum. CC BY 4.0',
      'updatedAt': stamp,
      'code': t.code,
      'expectedOutput': t.output,
      if (t.portableOutput != null) 'portableExpectedOutput': t.portableOutput,
      'inputFixtures': t.input == null
          ? <String, String>{}
          : <String, String>{'stdin': t.input!},
      'templateType': t.language,
      'sourceLessonId': '${t.tutorialId}-lesson',
    };

/// `C 001：第一个程序` -> `第一个程序`.
String _topicName(String title) {
  final index = title.indexOf('：');
  return index >= 0 ? title.substring(index + 1).trim() : title;
}

String _stamp() {
  final now = DateTime.now().toUtc();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Future<void> _writeJson(File file, Map<String, dynamic> doc) async {
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(doc)}\n', flush: true);
}

/// Walks up from the current directory until a `pubspec.yaml` is found, so the
/// generator is location-independent (both CLI entry points agree).
String _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.absolute.path;
    dir = parent;
  }
}
