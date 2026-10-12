/// Public CLI entry for the C/C++ curriculum verifier.
///
/// The implementation lives beside the authored topics under
/// `tool/forge_content/`; this thin entry keeps the documented command
/// (`dart run tool/verify_forge_content.dart`) working.
///
///   dart run tool/generate_forge_content.dart
///   dart run tool/verify_forge_content.dart        # native compile+run all 200
///   dart run tool/verify_forge_content.dart --no-native   # staged checks only
library;

export 'forge_content/verify_forge_content.dart' show main;
