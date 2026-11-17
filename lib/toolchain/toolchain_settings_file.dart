import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/app_paths.dart';

import 'toolchain_environment.dart';

/// Name of the settings file under the storage directory of the application.
const String toolchainSettingsFileName = 'toolchain_environment.json';

/// Readers and writers of the stored text, used as the seam of [ToolchainSettingsFile].
///
/// Production keeps one JSON file under the storage directory of the
/// application. A test hands over a subclass that keeps the text in memory.
class ToolchainSettingsStore {
  const ToolchainSettingsStore();

  /// Directory that holds the file, or null when the application has none.
  Future<String?> storageDirectory() => AppPaths.storageDirectory();

  /// Path of the settings file, for messages and for tests.
  Future<String?> filePath() async {
    final directory = await storageDirectory();
    return directory == null
        ? null
        : p.join(directory, toolchainSettingsFileName);
  }

  /// Stored JSON text, or null when no file exists.
  Future<String?> read() async {
    final path = await filePath();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Replaces the stored text. False when the application has no storage
  /// directory.
  Future<bool> write(String text) async {
    final path = await filePath();
    if (path == null) return false;
    final target = File(path);
    // Temporary file plus rename: an interrupted write never leaves half a
    // file that the next start would read as settings.
    final temporary = File('$path.tmp');
    await target.parent.create(recursive: true);
    await temporary.writeAsString(text, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(path);
    return true;
  }
}

/// Store that keeps the text in memory. A missing text reports no file.
class MemoryToolchainSettingsStore extends ToolchainSettingsStore {
  MemoryToolchainSettingsStore({
    String? text,
    String storageDirectory = '',
  }) : _text = text,
       _storageDirectory = storageDirectory;

  String? _text;
  final String _storageDirectory;

  /// Stored text, or null when the store reported no file.
  String? get text => _text;

  @override
  Future<String?> storageDirectory() async =>
      _storageDirectory.isEmpty ? null : _storageDirectory;

  @override
  Future<String?> read() async => _text;

  @override
  Future<bool> write(String text) async {
    _text = text;
    return true;
  }
}

/// Reads and writes [ToolchainSettings] as one JSON object.
///
/// A missing, unreadable or damaged file gives the defaults. A write goes
/// through a temporary file and a rename, so an interrupted write never
/// becomes the stored file.
class ToolchainSettingsFile {
  ToolchainSettingsFile({ToolchainSettingsStore? store})
    : _store = store ?? const ToolchainSettingsStore();

  static const int _version = 1;

  final ToolchainSettingsStore _store;

  /// Store of this file, for the storage directory of the environment.
  ToolchainSettingsStore get store => _store;

  Future<ToolchainSettings> read() async {
    try {
      final text = await _store.read();
      if (text == null) return const ToolchainSettings();
      return decode(text);
    } on FileSystemException {
      return const ToolchainSettings();
    } on FormatException {
      return const ToolchainSettings();
    }
  }

  /// Stores [settings]. False when the storage directory is unknown or not
  /// writable; the caller keeps the settings in memory in that case.
  Future<bool> write(ToolchainSettings settings) async {
    try {
      return await _store.write(encode(settings));
    } on FileSystemException {
      return false;
    }
  }

  /// JSON text of [settings]. One function writes it, so a round trip stays
  /// symmetric.
  static String encode(ToolchainSettings settings) => '${jsonEncode({
    'version': _version,
    'directory': settings.directory,
    'preference': settings.preference.name,
  })}\n';

  /// Settings of [text]. Another version, a broken object or an unknown
  /// preference gives the defaults of that field.
  static ToolchainSettings decode(String text) {
    final Object? raw = jsonDecode(text);
    if (raw is! Map) return const ToolchainSettings();
    final version = raw['version'];
    if (version is! int || version != _version) {
      return const ToolchainSettings();
    }
    final directory = raw['directory'];
    final preference = raw['preference'];
    return ToolchainSettings(
      directory: directory is String && directory.trim().isNotEmpty
          ? directory.trim()
          : null,
      preference: CompilerPreference.values.firstWhere(
        (value) => value.name == preference,
        orElse: () => CompilerPreference.automatic,
      ),
    );
  }
}
