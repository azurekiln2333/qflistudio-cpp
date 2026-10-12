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
Future<void> initializeStudioStorage() async {}
Future<void> flushStudioStorage() async {}
