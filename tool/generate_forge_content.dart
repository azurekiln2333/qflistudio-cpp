import 'forge_content/generate_forge_content.dart' as impl;

/// Public CLI entry for the C/C++ curriculum generator.
///
/// The real implementation lives under `tool/forge_content/` alongside the
/// authored topics, so this thin entry keeps the documented command short:
///
///   dart run tool/generate_forge_content.dart
///
/// It is exactly equivalent to:
///
///   dart run tool/forge_content/generate_forge_content.dart
Future<void> main(List<String> args) => impl.main(args);
