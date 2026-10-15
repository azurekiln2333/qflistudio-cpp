import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qfli_studio_core/content/content_repository.dart';

import 'platform/platform_io.dart';

/// The Forge catalog belongs to this app, including target-specific output.
class ForgeContentRepository implements ContentRepository {
  ForgeContentRepository({AssetBundle? bundle, bool? portable})
    : _bundle = bundle ?? rootBundle,
      _portable = portable ?? (!kIsWeb && Platform.operatingSystem == 'ohos');

  static const tutorialAsset =
      'tool/forge_content/staging/forge_tutorials.json';
  static const exampleAsset = 'tool/forge_content/staging/forge_examples.json';

  final AssetBundle _bundle;
  final bool _portable;
  Future<ContentCatalog>? _catalog;

  @override
  Future<ContentCatalog> load() => _catalog ??= _load();

  Future<ContentCatalog> _load() async {
    final sources = await Future.wait([
      _bundle.loadString(tutorialAsset),
      _bundle.loadString(exampleAsset),
    ]);
    return compute(_parseCatalog, (sources, _portable));
  }

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async => (await load()).tutorials.where(filter.matches).toList();

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async => (await load()).examples.where(filter.matches).toList();
}

ContentCatalog _parseCatalog((List<String>, bool) input) {
  final (sources, portable) = input;
  if (!portable) {
    return ContentCatalog.fromJson(
      tutorialsSource: sources[0],
      examplesSource: sources[1],
    );
  }
  final tutorials = jsonDecode(sources[0]) as Map<String, dynamic>;
  final examples = jsonDecode(sources[1]) as Map<String, dynamic>;
  for (final entry in tutorials['entries'] as List<dynamic>) {
    for (final lesson in entry['lessons'] as List<dynamic>) {
      if (lesson['portableOutput'] case final String output) {
        lesson['output'] = output;
      }
    }
  }
  for (final entry in examples['entries'] as List<dynamic>) {
    if (entry['portableExpectedOutput'] case final String output) {
      entry['expectedOutput'] = output;
    }
  }
  return ContentCatalog.fromJson(
    tutorialsSource: jsonEncode(tutorials),
    examplesSource: jsonEncode(examples),
  );
}
