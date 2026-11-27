@TestOn('browser')
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/platform/platform_io.dart';
import 'package:qfli_c/platform/platform_io_browser.dart' show reloadStudioStorageForTesting;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/models/project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('local facade persists project bytes', () async {
    await initializeStudioStorage();
    await studioDirectory('/workspace/facade-review').create(recursive: true);
    await studioFile('/workspace/facade-review/main.c').writeAsString('int main(void) { return 0; }', flush: true);
    await reloadStudioStorageForTesting();
    expect(await studioFile('/workspace/facade-review/main.c').readAsString(), 'int main(void) { return 0; }');
  });
  test('real shared EditorController opens the local runner filesystem', () async {
    final editor = EditorController(project: Project.create(name: 'Facade Review', path: '/workspace/facade-review'));
    try {
      expect(await editor.openPath('/workspace/facade-review/main.c'), isNull);
    } finally {
      editor.dispose();
    }
  });
}
