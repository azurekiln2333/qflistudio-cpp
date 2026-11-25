import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_integer_tools.dart';
import 'package:qfli_c/forge_tools_page.dart';
import 'package:qfli_c/main.dart' show forgeProfile;

void main() {
  test('Forge contributes a tools page to the existing navigation', () {
    expect(forgeProfile.toolsPageBuilder, isNotNull);
  });

  group('Integer tools', () {
    test('64-bit patterns retain all digits and expose signed values', () {
      final word = IntegerWord(
        parseToolInteger('18446744073709551615'),
        width: 64,
      );
      expect(word.signed, BigInt.from(-1));
      expect(word.hexadecimal, '0xFFFFFFFFFFFFFFFF');
      expect(word.binary, '0b${List.filled(64, '1').join()}');
      expect(IntegerWord(BigInt.from(-1), width: 64).pattern, word.pattern);
    });

    test('signed minimum and unsigned maximum fit, overflow is rejected', () {
      expect(IntegerWord(BigInt.from(-128), width: 8).hexadecimal, '0x80');
      expect(IntegerWord(BigInt.from(255), width: 8).signed, BigInt.from(-1));
      for (final value in [-129, 256]) {
        expect(
          () => IntegerWord(BigInt.from(value), width: 8),
          throwsFormatException,
        );
      }
    });

    test('decimal and prefixed input are parsed with a single sign', () {
      expect(parseToolInteger(' -0XFF '), BigInt.from(-255));
      expect(parseToolInteger('+0b1010'), BigInt.from(10));
      expect(parseToolInteger('0o17'), BigInt.from(15));
      for (final value in ['0x', '0b12', '--1', '+-1', '0x-1', '1.5']) {
        expect(() => parseToolInteger(value), throwsFormatException);
      }
    });

    test(
      'logical and arithmetic shifts produce different fixed-width patterns',
      () {
        final word = IntegerWord(BigInt.from(128), width: 8);
        expect(
          word
              .apply(BitOperation.logicalRightShift, operand: BigInt.one)
              .pattern,
          BigInt.from(64),
        );
        expect(
          word
              .apply(BitOperation.arithmeticRightShift, operand: BigInt.one)
              .signed,
          BigInt.from(-64),
        );
        expect(
          IntegerWord(
            BigInt.from(255),
            width: 8,
          ).apply(BitOperation.leftShift, operand: BigInt.one).pattern,
          BigInt.from(254),
        );
        for (final count in [-1, 8]) {
          expect(
            () =>
                word.apply(BitOperation.leftShift, operand: BigInt.from(count)),
            throwsFormatException,
          );
        }
      },
    );

    test('bitwise operands and complement stay within their word width', () {
      final word = IntegerWord(BigInt.from(0xF0), width: 8);
      expect(word.apply(BitOperation.not).pattern, BigInt.from(0x0F));
      expect(
        word.apply(BitOperation.and, operand: BigInt.from(0xAA)).pattern,
        BigInt.from(0xA0),
      );
      expect(
        word.apply(BitOperation.or, operand: BigInt.from(0x0F)).pattern,
        BigInt.from(0xFF),
      );
      expect(
        word.apply(BitOperation.xor, operand: BigInt.from(-1)).pattern,
        BigInt.from(0x0F),
      );
    });
  });

  test('ASCII control and quote constants are valid C escape sequences', () {
    expect(const AsciiCharacter(10).name, 'LF');
    expect(const AsciiCharacter(10).literal, r"'\n'");
    expect(const AsciiCharacter(39).literal, r"'\''");
    expect(const AsciiCharacter(92).literal, r"'\\'");
    expect(const AsciiCharacter(127).literal, r"'\x7F'");
    expect(const AsciiCharacter(32).isControl, isFalse);
  });

  for (final width in [320.0, 1024.0]) {
    testWidgets('tools work without overflow at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: ForgeToolsPage()));
      await tester.tap(find.text('64 位').first);
      await tester.enterText(
        find.byKey(const ValueKey('integer-a')).first,
        '-1',
      );
      await tester.pumpAndSettle();
      expect(find.text('18446744073709551615'), findsOneWidget);
      final copy = find.byTooltip('复制十六进制').first;
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, '0xFFFFFFFFFFFFFFFF');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('位运算'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('integer-a')).last,
        '0xFF',
      );
      await tester.enterText(find.byKey(const ValueKey('integer-b')), '0x0F');
      await tester.pumpAndSettle();
      expect(find.text('0x0000000F'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ASCII'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索 ASCII'), 'LF');
      await tester.pumpAndSettle();
      expect(find.text('0A'), findsOneWidget);
      expect(find.text(r"'\n'"), findsOneWidget);
      await tester.tap(find.byTooltip('复制 LF 常量'));
      await tester.pumpAndSettle();
      expect(copied, r"'\n'");
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('进制转换'));
      await tester.pumpAndSettle();
      expect(find.text('18446744073709551615'), findsOneWidget);
    });
  }
}
