import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_integer_tools.dart';
import 'package:qfli_c/forge_tools_page.dart';
import 'package:qfli_c/main.dart' show forgeProfile;

void main() {
  test('Forge contributes a tools page to the existing navigation', () {
    expect(forgeProfile.toolsTabBuilder, isNotNull);
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

  testWidgets('embedded tools body uses host scaffold and terminal callback', (
    tester,
  ) async {
    var terminalOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('宿主工具页')),
          body: ForgeToolsBody(onOpenTerminal: () => terminalOpens++),
        ),
      ),
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('进制转换'), findsOneWidget);
    expect(find.text('UTF-8 / C 字符串'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '打开终端'));
    expect(terminalOpens, 1);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [
    (320.0, 1.0),
    (1024.0, 1.0),
    (320.0, 2.0),
    (1024.0, 2.0),
  ]) {
    testWidgets('direct tools work at width $width and text scale $scale', (
      tester,
    ) async {
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

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ForgeToolsPage(),
        ),
      );
      Finder button(String tooltip) => find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      );
      Future<void> show(Finder target) async {
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.2);
        await tester.pumpAndSettle();
      }

      Future<void> enter(Finder target, String value) async {
        await show(target);
        await tester.enterText(target, value);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder target) async {
        await show(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
      expect(find.text('UTF-8 / C 字符串'), findsOneWidget);
      expect(find.text('类型与结构体布局'), findsOneWidget);
      expect(
        tester.widget<IconButton>(button('复制十六进制').first).onPressed,
        isNull,
      );
      await show(find.text('64 位').first);
      await tester.tap(find.text('64 位').first);
      await enter(find.byKey(const ValueKey('integer-a')).first, '-1');
      expect(find.text('18446744073709551615'), findsOneWidget);
      final copy = button('复制十六进制').first;
      await tap(copy);
      expect(copied, '0xFFFFFFFFFFFFFFFF');
      expect(tester.takeException(), isNull);

      await enter(find.byKey(const ValueKey('integer-a')).last, '0xFF');
      await enter(find.byKey(const ValueKey('integer-b')), '0x0F');
      expect(find.text('0x0000000F'), findsOneWidget);
      await tap(button('交换操作数'));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('integer-a')).last)
            .controller!
            .text,
        '0x0F',
      );
      await enter(find.byKey(const ValueKey('integer-b')), 'not an integer');
      expect(find.text('整数格式无效'), findsOneWidget);
      expect(
        tester.widget<IconButton>(button('复制十六进制').last).onPressed,
        isNull,
      );
      await enter(find.byKey(const ValueKey('integer-b')), '0xFF');
      expect(tester.takeException(), isNull);

      await enter(find.byKey(const ValueKey('c-string-text')), 'éA');
      await tap(find.text('全十六进制'));
      expect(find.text(r'"\xC3\xA9\x41"'), findsOneWidget);
      await tap(button('复制C 字符串'));
      expect(copied, r'"\xC3\xA9\x41"');
      await enter(
        find.byKey(const ValueKey('c-string-literal')),
        r'"\xC3\xA9" "A"',
      );
      await tap(button('复制UTF-8 文本'));
      expect(copied, 'éA');
      await enter(find.byKey(const ValueKey('c-string-literal')), r'"\xFF"');
      expect(find.text('字节序列不是有效 UTF-8；仍可复制原始字节。'), findsOneWidget);
      expect(tester.widget<IconButton>(button('复制UTF-8 文本')).onPressed, isNull);
      await tap(button('复制字节列表'));
      expect(copied, '0xFF');
      await enter(find.byKey(const ValueKey('c-string-literal')), r'"\x41B"');
      expect(find.textContaining('十六进制转义超出 8 位范围'), findsOneWidget);
      expect(tester.widget<IconButton>(button('复制字节列表')).onPressed, isNull);

      await show(find.byKey(const ValueKey('c-layout-summary')));
      expect(find.text('总大小 12 字节 · 对齐 4 · 尾部填充 0'), findsOneWidget);
      await tap(find.text('桌面 / LP64'));
      expect(find.text('总大小 24 字节 · 对齐 8 · 尾部填充 0'), findsOneWidget);
      await tap(button('复制布局报告'));
      expect(
        copied,
        contains('long count: offset=8, size=8, align=8, padding=7'),
      );
      await enter(
        find.byKey(const ValueKey('c-layout-members')),
        'int zero[0];',
      );
      expect(find.textContaining('数组长度必须是正整数'), findsOneWidget);
      expect(tester.widget<IconButton>(button('复制布局报告')).onPressed, isNull);

      final asciiResults = find.byKey(const ValueKey('ascii-results'));
      await show(asciiResults);
      expect(tester.getSize(asciiResults).height, 280);
      expect(find.text('128 个匹配字符 · DEC / HEX / C 常量'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('ascii-list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await enter(find.byKey(const ValueKey('ascii-search')), 'LF');
      expect(find.text('10 / 0A · LF'), findsOneWidget);
      expect(find.text(r"'\n'"), findsOneWidget);
      await tap(button('复制 LF 常量'));
      expect(copied, r"'\n'");
      await tap(find.text('可打印'));
      expect(find.text('无匹配字符'), findsOneWidget);
      await tap(find.text('控制字符'));
      expect(find.text('10 / 0A · LF'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await show(find.byKey(const ValueKey('integer-a')).first);
      expect(find.text('18446744073709551615'), findsOneWidget);
      // A responsive rearrangement keeps every controller, chip and filter.
      tester.view.physicalSize = Size(width == 320 ? 1024 : 320, 800);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('integer-a')).first)
            .controller!
            .text,
        '-1',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('c-string-text')))
            .controller!
            .text,
        'éA',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ascii-search')))
            .controller!
            .text,
        'LF',
      );
      expect(find.text('无匹配字符'), findsNothing);
      expect(find.text('18446744073709551615'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
