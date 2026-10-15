import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_content_repository.dart';
import 'package:qfli_c/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the application owns all 200 tutorial and example pairs', () async {
    final repository = forgeProfile.contentRepositoryFactory!();
    expect(repository, isA<ForgeContentRepository>());
    final catalog = await repository.load();
    expect(catalog.tutorials, hasLength(200));
    expect(catalog.examples, hasLength(200));
    for (final language in ['c', 'cpp']) {
      expect(
        catalog.examples.where((entry) => entry.language == language),
        hasLength(100),
      );
      expect(
        catalog.tutorials.where((entry) => entry.language == language),
        hasLength(100),
      );
    }
  });

  test(
    'portable outputs match their tutorial and preserve native values',
    () async {
      final native = await ForgeContentRepository(portable: false).load();
      final portable = await ForgeContentRepository(portable: true).load();
      for (final (id, expected) in [
        ('067', 'errno=44\nmessage: No such file or directory\nhandled=1\n'),
        ('072', 'os=wasi\n'),
      ]) {
        final example = portable.examples.singleWhere(
          (entry) => entry.id == 'c-example-$id',
        );
        final tutorial = portable.tutorials.singleWhere(
          (entry) => entry.id == 'c-tutorial-$id',
        );
        expect(example.expectedOutput, expected);
        expect(tutorial.lessons.single.output, expected);
        expect(
          native.examples
              .singleWhere((entry) => entry.id == example.id)
              .expectedOutput,
          isNot(expected),
        );
        expect(
          example.code,
          native.examples.singleWhere((entry) => entry.id == example.id).code,
        );
      }
    },
  );
}
