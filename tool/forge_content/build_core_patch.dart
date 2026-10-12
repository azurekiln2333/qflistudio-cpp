import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'merge_forge_content.dart' as merge;

/// Builds a **C/C++-rows-only** patch for the shared core aggregate assets.
///
/// The coordinator must be able to commit only this task's change without
/// staging foreign-language edits other agents have in their working tree.
/// This helper produces that narrow change by reusing the peer's authoritative
/// `scopedMerge` (no duplicated ownership/replacement logic):
///
///   1. Reads the asset **exactly as recorded in the git index**
///      (`git show :assets/content/<name>`) and keeps those raw bytes as the
///      patch baseline, so foreign rows already committed by others are the base
///      and nothing is reserialized.
///   2. Parses the baseline only to compute the merged document via
///      `scopedMerge`, which replaces `{c, cpp}` rows in place and touches no
///      metadata (including `updatedAt`).
///   3. Emits a `git diff --no-index` patch with `a/<core-relative>` /
///      `b/<core-relative>` headers so it applies to the real asset path.
///
/// It never writes the shared core and never stages anything (preparation only).
/// Any git index failure or invalid staging is a hard error (non-zero exit).
///
/// Run from `qfli_c`:
///
///   dart run tool/forge_content/build_core_patch.dart
///   dart run tool/forge_content/build_core_patch.dart --core ../qfli_studio_core
Future<void> main(List<String> args) async {
  final core = Directory(
    _option(args, '--core') ??
        p.normalize(p.join(Directory.current.path, '..', 'qfli_studio_core')),
  );
  if (!core.existsSync()) {
    stderr.writeln('core not found: ${core.path}');
    exitCode = 2;
    return;
  }
  final staging = Directory(
    p.join(Directory.current.path, 'tool', 'forge_content', 'staging'),
  );
  final stagedTutorials = File(p.join(staging.path, 'forge_tutorials.json'));
  final stagedExamples = File(p.join(staging.path, 'forge_examples.json'));
  if (!stagedTutorials.existsSync() || !stagedExamples.existsSync()) {
    stderr.writeln('staged rows missing; run generate_forge_content.dart first');
    exitCode = 2;
    return;
  }

  final outDir = Directory(p.join(staging.path, 'core-patch'))
    ..createSync(recursive: true);
  final report = StringBuffer();
  var failed = false;

  for (final name in const ['tutorials.json', 'examples.json']) {
    final relPath = 'assets/content/$name';
    final staged = _decode(
      name == 'tutorials.json' ? stagedTutorials : stagedExamples,
    );
    final kind = name == 'tutorials.json' ? 'tutorials' : 'examples';

    // Reject invalid staging before doing anything else.
    final problems = merge.validateStaging(staged, kind);
    if (problems.isNotEmpty) {
      stderr.writeln('INVALID staging for $name: ${problems.join('; ')}');
      failed = true;
      continue;
    }

    // Raw index bytes are the baseline; a git failure is a hard error.
    final baselineBytes = await _gitShowIndexBytes(core, relPath);
    if (baselineBytes == null) {
      stderr.writeln('git index read failed for $relPath');
      failed = true;
      continue;
    }
    final baselineFile = File(p.join(outDir.path, '$name.index'))
      ..writeAsBytesSync(baselineBytes);
    final baselineDoc =
        jsonDecode(utf8.decode(baselineBytes)) as Map<String, dynamic>;

    final scoped = merge.scopedMerge(baselineDoc, staged);
    if (!_sameList(
      scoped.foreignBefore.cast<String>(),
      scoped.foreignAfter.cast<String>(),
    )) {
      stderr.writeln('scopedMerge changed foreign rows for $name; aborting');
      failed = true;
      continue;
    }
    final mergedFile = File(p.join(outDir.path, '$name.merged'))
      ..writeAsStringSync(_encode(scoped.merged));

    final diff = Process.runSync('git', [
      'diff',
      '--no-index',
      '--no-color',
      '--',
      baselineFile.path,
      mergedFile.path,
    ], workingDirectory: core.path, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (diff.exitCode != 0 && diff.exitCode != 1) {
      stderr.writeln('git diff failed for $name (exit ${diff.exitCode})');
      failed = true;
      continue;
    }
    final patchFile = File(p.join(outDir.path, '$name.patch'))
      ..writeAsStringSync(_rewriteHeaders(diff.stdout as String, relPath));
    report.writeln(
      'WROTE ${p.relative(patchFile.path, from: Directory.current.path)} '
      '(${_ownedCount(baselineDoc)} -> ${_ownedCount(scoped.merged)} C/C++ rows)',
    );
  }

  if (failed) {
    stderr.writeln('C/C++ patch build FAILED; nothing to apply.');
    exitCode = 1;
    return;
  }
  report.writeln(
    'C/C++-only patches staged under '
    '${p.relative(outDir.path, from: Directory.current.path)}. '
    'Nothing was staged or written to the shared core.',
  );
  stdout.write(report.toString());
}

Map<String, dynamic> _decode(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

String _encode(Map<String, dynamic> doc) =>
    '${const JsonEncoder.withIndent('  ').convert(doc)}\n';

/// Raw bytes of an index file, or null on any git failure.
Future<List<int>?> _gitShowIndexBytes(Directory core, String relPath) async {
  // `stdoutEncoding: null` keeps the exact bytes so large UTF-8 assets are not
  // re-encoded through the system codepage.
  final proc = await Process.run('git', [
    'show',
    ':$relPath',
  ], workingDirectory: core.path, stdoutEncoding: null);
  if (proc.exitCode != 0) return null;
  final out = proc.stdout;
  if (out is List<int>) return out;
  if (out is String) return utf8.encode(out);
  return null;
}

int _ownedCount(Map<String, dynamic> doc) {
  final entries = doc['entries'];
  if (entries is! List) return 0;
  return entries.whereType<Map>().where((row) {
    final lang = (row['language'] ?? '').toString().toLowerCase();
    return lang == 'c' || lang == 'cpp';
  }).length;
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Rewrites `git diff --no-index` headers so the patch applies to the real
/// core path (`a/assets/content/<name>`), not the absolute temp file paths.
String _rewriteHeaders(String diff, String relPath) {
  final lines = diff.split('\n');
  final out = <String>[];
  for (final line in lines) {
    if (line.startsWith('diff --git ')) {
      out.add('diff --git a/$relPath b/$relPath');
    } else if (line.startsWith('--- ')) {
      out.add('--- a/$relPath');
    } else if (line.startsWith('+++ ')) {
      out.add('+++ b/$relPath');
    } else {
      out.add(line);
    }
  }
  return out.join('\n');
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return null;
}
