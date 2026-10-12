import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as native_path;
import 'package:qfli_studio_core/services/platform_io.dart';
import 'package:qfli_studio_core/services/platform_path.dart' as p;

void main() {
  test('native path semantics match the existing path library', () {
    expect(p.style, native_path.style);
    expect(p.current, native_path.current);
    expect(p.separator, native_path.separator);
    expect(
      p.absolute('projects', 'C++'),
      native_path.absolute('projects', 'C++'),
    );
    expect(
      p.join('projects', 'source.c'),
      native_path.join('projects', 'source.c'),
    );
  }, skip: kIsWeb);
  test(
    'platform storage preserves the native filesystem and IO types',
    () async {
      final temporary = await io.Directory.systemTemp.createTemp(
        'qfli-storage-',
      );
      try {
        final file = studioFile('${temporary.path}/binary.dat');
        expect(file, isA<io.File>());
        await file.writeAsBytes([0, 255, 10], flush: true);
        expect(await io.File(file.path).readAsBytes(), [0, 255, 10]);
        expect(studioEntityTypeSync(file.path), io.FileSystemEntityType.file);
        final renamed = await file.rename('${temporary.path}/renamed.dat');
        expect(await renamed.readAsBytes(), [0, 255, 10]);
        expect(await io.File(file.path).exists(), isFalse);
        await flushStudioStorage();
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: kIsWeb,
  );
}
