// Native implementation: the existing `dart:io` API is re-exported verbatim so
// desktop/mobile behavior is identical to a direct `dart:io` import.
import 'dart:io';

export 'dart:io';

File studioFile(String path) => File(path);
Directory studioDirectory(String path) => Directory(path);
Directory get studioCurrentDirectory => Directory.current;
Directory get studioSystemTemp => Directory.systemTemp;
Future<FileSystemEntityType> studioEntityType(
  String path, {
  bool followLinks = true,
}) => FileSystemEntity.type(path, followLinks: followLinks);
FileSystemEntityType studioEntityTypeSync(
  String path, {
  bool followLinks = true,
}) => FileSystemEntity.typeSync(path, followLinks: followLinks);

/// No initialization is required on platforms with a real filesystem.
Future<void> initializeStudioStorage() async {}

/// Writes are synchronous on native platforms, so there is nothing to flush.
Future<void> flushStudioStorage() async {}
