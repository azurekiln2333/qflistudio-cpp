import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Coordinates a **scoped, freshness-checked** merge of the authored C/C++ rows
/// into the shared core aggregate content files.
///
/// Safety contract (`.trellis/tasks/10-12-c-cpp-substantive-curriculum/design.md` §2):
///   * Reads the **live** core files each run; never restores from backup.
///   * Ownership is strictly `language in {c, cpp}` — there is no `type` shortcut.
///   * Replaces only owned rows **in place**, preserving the exact position and
///     content of every foreign row, and preserving **all** top-level metadata
///     (nothing, including `updatedAt`, is overwritten).
///   * Validates the staged input before touching anything: it must carry
///     >= 100 C and >= 100 C++ rows, all owned, with unique ids and non-empty
///     code. Invalid staging aborts and can never erase live rows.
///   * Freshness check: re-reads the **complete** live document (metadata and row
///     order included) immediately before writing, and aborts if it changed
///     since the initial read (a concurrent writer).
///   * Backs up **only the owned C/C++ rows** under this task's own tool output
///     (`qfli_c/tool/forge_content/merge-backups/`), never inside the shared core.
///   * Refuses to write unless `--apply` is passed; the default is a dry run.
///     The actual external write is executed by the coordinator escalation gate,
///     never by this script during authoring.
///
/// Run from `qfli_c`:
///
///   dart run tool/forge_content/merge_forge_content.dart            # dry run
///   dart run tool/forge_content/merge_forge_content.dart --apply    # write
///
/// The core path defaults to `../qfli_studio_core`; override with `--core <path>`.
Future<void> main(List<String> args) async {
  final apply = args.contains('--apply');
  final coreArg = _option(args, '--core');
  final repoRoot = Directory.current.path;
  final core = Directory(
    coreArg ?? p.normalize(p.join(repoRoot, '..', 'qfli_studio_core')),
  );

  final staging = Directory(p.join(repoRoot, 'tool', 'forge_content', 'staging'));
  final stagedTutorials = File(p.join(staging.path, 'forge_tutorials.json'));
  final stagedExamples = File(p.join(staging.path, 'forge_examples.json'));
  if (!stagedTutorials.existsSync() || !stagedExamples.existsSync()) {
    stderr.writeln('staged rows missing; run generate_forge_content.dart first');
    exitCode = 2;
    return;
  }

  if (!core.existsSync()) {
    stderr.writeln('core not found: ${core.path}');
    exitCode = 2;
    return;
  }
  final contentDir = Directory(p.join(core.path, 'assets', 'content'));
  final liveTutorials = File(p.join(contentDir.path, 'tutorials.json'));
  final liveExamples = File(p.join(contentDir.path, 'examples.json'));
  if (!liveTutorials.existsSync() || !liveExamples.existsSync()) {
    stderr.writeln('live core aggregates not found under ${contentDir.path}');
    exitCode = 2;
    return;
  }

  // Own-row backups stay inside THIS repo's task tool output, never the core.
  final backupDir = Directory(
    p.join(repoRoot, 'tool', 'forge_content', 'merge-backups'),
  );
  final reportDir = Directory(
    p.join(
      repoRoot,
      '.trellis',
      'tasks',
      '10-12-c-cpp-substantive-curriculum',
      'research',
    ),
  );

  final result = await _merge(
    stagedTutorials: stagedTutorials,
    stagedExamples: stagedExamples,
    liveTutorials: liveTutorials,
    liveExamples: liveExamples,
    backupDir: backupDir,
    reportDir: reportDir,
    apply: apply,
  );

  stdout.writeln(result.summary);
  if (result.reportPath != null) {
    stdout.writeln('Report: ${result.reportPath}');
  }
  if (result.aborted) exitCode = 3;
}

class MergeResult {
  MergeResult(this.summary, {this.aborted = false, this.reportPath});
  final String summary;
  final bool aborted;
  final String? reportPath;
}

Future<MergeResult> _merge({
  required File stagedTutorials,
  required File stagedExamples,
  required File liveTutorials,
  required File liveExamples,
  required Directory backupDir,
  required Directory reportDir,
  required bool apply,
}) async {
  final stagedTutRaw = stagedTutorials.readAsStringSync();
  final stagedExRaw = stagedExamples.readAsStringSync();
  final stagedTut = jsonDecode(stagedTutRaw) as Map<String, dynamic>;
  final stagedEx = jsonDecode(stagedExRaw) as Map<String, dynamic>;

  // --- Validate staging BEFORE any read/write of live files. ---
  final stagingErrors = <String>[
    ..._validateStaging(stagedTut, 'tutorials'),
    ..._validateStaging(stagedEx, 'examples'),
  ];
  if (stagingErrors.isNotEmpty) {
    return MergeResult(
      'ABORTED: invalid staged rows (${stagingErrors.length}):\n'
      '  - ${stagingErrors.take(15).join('\n  - ')}',
      aborted: true,
    );
  }

  // --- Snapshot the COMPLETE live documents at read time. ---
  final liveTutSnapshot = liveTutorials.readAsStringSync();
  final liveExSnapshot = liveExamples.readAsStringSync();
  final liveTut = jsonDecode(liveTutSnapshot) as Map<String, dynamic>;
  final liveEx = jsonDecode(liveExSnapshot) as Map<String, dynamic>;

  final ownedBeforeTut = _ownedRows(liveTut);
  final ownedBeforeEx = _ownedRows(liveEx);
  final foreignBeforeTut = _foreignRows(liveTut).length;
  final foreignBeforeEx = _foreignRows(liveEx).length;

  final mergedTut = _replaceOwned(liveTut, stagedTut);
  final mergedEx = _replaceOwned(liveEx, stagedEx);

  // Prove the merge is scoped: foreign rows and all metadata are unchanged.
  final scopeErrors = <String>[
    ..._checkScoped(liveTut, mergedTut, 'tutorials'),
    ..._checkScoped(liveEx, mergedEx, 'examples'),
  ];
  if (scopeErrors.isNotEmpty) {
    return MergeResult(
      'ABORTED: merge is not scoped (${scopeErrors.length}):\n'
      '  - ${scopeErrors.take(15).join('\n  - ')}',
      aborted: true,
    );
  }

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'mode': apply ? 'apply' : 'dry-run',
    'stagedTutorials': _ownedRows(stagedTut).length,
    'stagedExamples': _ownedRows(stagedEx).length,
    'liveOwnedTutorialsBefore': ownedBeforeTut.length,
    'liveOwnedExamplesBefore': ownedBeforeEx.length,
    'liveForeignTutorials': foreignBeforeTut,
    'liveForeignExamples': foreignBeforeEx,
    'stagedTutorialsSha': _stableHash(stagedTutRaw),
    'liveTutorialsSha': _stableHash(liveTutSnapshot),
    'liveExamplesSha': _stableHash(liveExSnapshot),
    'stagingErrors': stagingErrors,
    'scopeErrors': scopeErrors,
  };

  if (!apply) {
    final stub = _stubRepoRoot(backupDir);
    final reportFile = await _writeReport(
      reportDir,
      'forge-merge-dry-run.json',
      <String, Object?>{...report, 'stub': stub, 'result': 'dry-run'},
    );
    return MergeResult(
      'DRY RUN: would replace ${ownedBeforeTut.length} C/C++ tutorial rows with '
      '${_ownedRows(stagedTut).length}, and ${ownedBeforeEx.length} C/C++ example '
      'rows with ${_ownedRows(stagedEx).length}. '
      'Foreign rows preserved: $foreignBeforeTut tutorials, $foreignBeforeEx examples. '
      'Scoped check passed; top-level metadata unchanged. Pass --apply to write.',
      reportPath: reportFile.path,
    );
  }

  // --- Freshness check on the COMPLETE document (metadata + order). ---
  final liveTutAgain = liveTutorials.readAsStringSync();
  final liveExAgain = liveExamples.readAsStringSync();
  if (liveTutAgain != liveTutSnapshot || liveExAgain != liveExSnapshot) {
    final reportFile = await _writeReport(
      reportDir,
      'forge-merge-aborted.json',
      <String, Object?>{
        ...report,
        'result': 'aborted-stale',
        'reason': 'live files changed between read and write',
      },
    );
    return MergeResult(
      'ABORTED: live content changed between read and write; re-run the merge cycle.',
      aborted: true,
      reportPath: reportFile.path,
    );
  }

  // --- Own-row backups (previous C/C++ block only), inside THIS repo. ---
  backupDir.createSync(recursive: true);
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  _writeJson(
    File(p.join(backupDir.path, 'tutorials-owned-$stamp.json')),
    <String, dynamic>{'entries': ownedBeforeTut},
  );
  _writeJson(
    File(p.join(backupDir.path, 'examples-owned-$stamp.json')),
    <String, dynamic>{'entries': ownedBeforeEx},
  );

  _writeJsonAtomic(liveTutorials, mergedTut);
  _writeJsonAtomic(liveExamples, mergedEx);

  final reportFile = await _writeReport(
    reportDir,
    'forge-merge-applied.json',
    <String, Object?>{
      ...report,
      'result': 'applied',
      'backupDir': backupDir.path,
    },
  );
  return MergeResult(
    'APPLIED: replaced C/C++ rows '
    '(${_ownedRows(stagedTut).length} tutorials, ${_ownedRows(stagedEx).length} examples). '
    'Own-row backups in ${backupDir.path}.',
    reportPath: reportFile.path,
  );
}

/// Validates staged rows: every row must be owned (`language in {c,cpp}`),
/// have a unique id and non-empty code, and there must be >= 100 of each.
List<String> _validateStaging(Map<String, dynamic> doc, String kind) {
  final errors = <String>[];
  final entries = doc['entries'];
  if (entries is! List) {
    return <String>['$kind: entries must be an array'];
  }
  final ids = <String>{};
  var c = 0;
  var cpp = 0;
  for (final raw in entries) {
    if (raw is! Map) {
      errors.add('$kind: entry is not an object');
      continue;
    }
    final row = raw.cast<String, dynamic>();
    final language = (row['language'] ?? '').toString().toLowerCase();
    if (language != 'c' && language != 'cpp') {
      errors.add('$kind: row ${row['id']} has non-owned language "$language"');
      continue;
    }
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) {
      errors.add('$kind: row with empty id');
    } else if (!ids.add(id)) {
      errors.add('$kind: duplicate id $id');
    }
    final code = row['code'];
    final tutorialCode = _firstLessonCode(row);
    if ((code is! String || code.trim().isEmpty) &&
        (tutorialCode == null || tutorialCode.trim().isEmpty)) {
      errors.add('$kind: row $id has empty code');
    }
    if (language == 'c') {
      c++;
    } else {
      cpp++;
    }
  }
  if (c < 100) errors.add('$kind: only $c C rows (need >= 100)');
  if (cpp < 100) errors.add('$kind: only $cpp C++ rows (need >= 100)');
  return errors;
}

/// Proves the merge changed only owned rows: foreign rows and every top-level
/// metadata field must be byte-identical after the merge.
List<String> _checkScoped(
  Map<String, dynamic> live,
  Map<String, dynamic> merged,
  String kind,
) {
  final errors = <String>[];
  final liveForeign = _foreignRows(live);
  final mergedForeign = _foreignRows(merged);
  if (liveForeign.length != mergedForeign.length) {
    errors.add('$kind: foreign row count changed '
        '(${liveForeign.length} -> ${mergedForeign.length})');
  } else {
    for (var i = 0; i < liveForeign.length; i++) {
      if (jsonEncode(liveForeign[i]) != jsonEncode(mergedForeign[i])) {
        errors.add('$kind: foreign row ${liveForeign[i]['id']} changed or moved');
      }
    }
  }
  for (final key in live.keys) {
    if (key == 'entries') continue;
    if (jsonEncode(live[key]) != jsonEncode(merged[key])) {
      errors.add('$kind: top-level metadata "$key" changed');
    }
  }
  return errors;
}

List<Map<String, dynamic>> _entries(Map<String, dynamic> doc) {
  final entries = doc['entries'];
  if (entries is! List) return const [];
  return entries.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

List<Map<String, dynamic>> _ownedRows(Map<String, dynamic> doc) => <Map<String, dynamic>>[
  for (final row in _entries(doc))
    if (_isOwned(row)) row,
];

List<Map<String, dynamic>> _foreignRows(Map<String, dynamic> doc) => <Map<String, dynamic>>[
  for (final row in _entries(doc))
    if (!_isOwned(row)) row,
];

/// Ownership is strictly language-based; there is intentionally no `type`
/// shortcut, so a foreign row that happens to carry `type: "c"` is not owned.
bool _isOwned(Map<String, dynamic> row) {
  final lang = (row['language'] ?? '').toString().toLowerCase();
  return lang == 'c' || lang == 'cpp';
}

/// Returns the first lesson's `code` for a tutorial row, or null when the row
/// is not a tutorial shape (examples carry a top-level `code`).
String? _firstLessonCode(Map<String, dynamic> row) {
  final lessons = row['lessons'];
  if (lessons is! List || lessons.isEmpty) return null;
  final first = lessons.first;
  if (first is! Map) return null;
  final code = first['code'];
  return code is String ? code : null;
}

/// Replaces owned rows **in place**, preserving every foreign row's position
/// and all top-level metadata (nothing is overwritten, not even `updatedAt`).
Map<String, dynamic> _replaceOwned(
  Map<String, dynamic> live,
  Map<String, dynamic> staged,
) {
  final stagedOwned = _ownedRows(staged);
  var next = 0;
  final merged = <Map<String, dynamic>>[];
  for (final row in _entries(live)) {
    if (_isOwned(row)) {
      if (next < stagedOwned.length) merged.add(stagedOwned[next++]);
      // Surplus live owned rows (more owned rows live than staged) are dropped;
      // staged validation guarantees a full 100/100 set, so this is defensive.
    } else {
      merged.add(row);
    }
  }
  while (next < stagedOwned.length) {
    merged.add(stagedOwned[next++]);
  }

  final out = Map<String, dynamic>.from(live);
  out['entries'] = merged;
  return out;
}

String _stableHash(String text) {
  var h = 17;
  for (final b in utf8.encode(text)) {
    h = (h * 31 + b) & 0x7fffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void _writeJsonAtomic(File file, Map<String, dynamic> doc) {
  const encoder = JsonEncoder.withIndent('  ');
  final tmp = File('${file.path}.qfli-tmp');
  tmp.writeAsStringSync('${encoder.convert(doc)}\n', flush: true);
  tmp.renameSync(file.path);
}

void _writeJson(File file, Map<String, dynamic> doc) {
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(doc)}\n', flush: true);
}

Future<File> _writeReport(
  Directory dir,
  String name,
  Map<String, Object?> report,
) async {
  dir.createSync(recursive: true);
  final file = File(p.join(dir.path, name));
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  return file;
}

String _stubRepoRoot(Directory backupDir) => backupDir.parent.parent.path;

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return null;
}

/// Pure, testable scoped merge: returns the merged document and the foreign
/// fingerprint so callers can assert foreign rows are byte-identical and all
/// metadata is preserved.
///
/// Exposed for `test/forge_content_pipeline_test.dart`.
({Map<String, dynamic> merged, List<String> foreignBefore, List<String> foreignAfter})
scopedMerge(Map<String, dynamic> live, Map<String, dynamic> staged) {
  final before = <String>[for (final r in _foreignRows(live)) jsonEncode(r)];
  final merged = _replaceOwned(live, staged);
  final after = <String>[for (final r in _foreignRows(merged)) jsonEncode(r)];
  return (merged: merged, foreignBefore: before, foreignAfter: after);
}

/// Testable staged-row validation. Invalid staging must be rejected before any
/// live read/write, so it can never erase live rows.
///
/// Exposed for `test/forge_content_pipeline_test.dart`.
List<String> validateStaging(Map<String, dynamic> staged, String kind) =>
    _validateStaging(staged, kind);
