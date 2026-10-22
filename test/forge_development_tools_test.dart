import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_development_tools.dart';

void main() {
  group('C byte literals', () {
    test(
      'all byte values round trip in each style without escape ambiguity',
      () {
        final bytes = List.generate(256, (index) => index);
        for (final style in CStringStyle.values) {
          expect(decodeCString(encodeCBytes(bytes, style: style)), bytes);
        }
        expect(encodeCBytes([0, 55, 255, 65]), r'"\0007\377A"');
        expect(
          encodeCString('éA', style: CStringStyle.hexadecimal),
          r'"\xC3\xA9\x41"',
        );
        expect(encodeCString('??/'), r'"\?\?/"');
      },
    );

    test(
      'UTF-8 preserves embedded NUL, emoji, newlines, quotes and backslashes',
      () {
        const text = 'NUL\u0000é中😀\n"\\';
        for (final style in CStringStyle.values) {
          final bytes = decodeCString(encodeCString(text, style: style));
          expect(utf8.decode(bytes), text);
          expect(bytes.length, utf8.encode(text).length);
        }
        expect(encodeCString(''), '""');
        expect(decodeCString('""'), isEmpty);
        expect(cByteList([0, 10, 255]), '0x00, 0x0A, 0xFF');
      },
    );

    test('C hex consumes every hex digit, octal consumes at most three', () {
      expect(decodeCString(r'"\x41" "B"'), [65, 66]);
      expect(decodeCString(r'"\x000041"'), [65]);
      expect(() => decodeCString(r'"\x41B"'), throwsFormatException);
      expect(decodeCString(r'"\1017\0A\377"'), [65, 55, 0, 65, 255]);
      expect(decodeCString(r'"\7\77\377"'), [7, 63, 255]);
      expect(() => decodeCString(r'"\400"'), throwsFormatException);
      expect(() => decodeCString(r'"\777"'), throwsFormatException);
    });

    test(
      'adjacent literals concatenate bytes without inserting terminators',
      () {
        expect(decodeCString(' "a"\n\t"b" "" '), [97, 98]);
        expect(
          decodeCString(
            r'"\a\b\t\n\v\f\r\"\?\'
            "'"
            r'\\"',
          ),
          [7, 8, 9, 10, 11, 12, 13, 34, 63, 39, 92],
        );
        expect(decodeCString('"é😀"'), utf8.encode('é😀'));
      },
    );

    test(
      'malformed and unsupported source is rejected rather than guessed',
      () {
        for (final source in [
          '',
          '   ',
          'hello',
          '"missing',
          '"a" trailing',
          '"a" + "b"',
          '"a" /* comment */ "b"',
          'u8"a"',
          'L"a"',
          "'a'",
          '"line\nbreak"',
          r'"\x"',
          r'"\q"',
          r'"\8"',
          r'"\u0041"',
          r'"\U00000041"',
          '"trigraph??/"',
          r'"\??/"',
          '"backslash\\\nline"',
        ]) {
          expect(
            () => decodeCString(source),
            throwsFormatException,
            reason: source,
          );
        }
        expect(() => encodeCBytes([-1]), throwsFormatException);
        expect(() => encodeCBytes([256]), throwsFormatException);
        for (final text in [
          String.fromCharCode(0xD800),
          String.fromCharCode(0xDC00),
        ]) {
          expect(() => encodeCString(text), throwsFormatException);
          expect(() => decodeCString('"$text"'), throwsFormatException);
        }
      },
    );

    test(
      'invalid UTF-8 stays available as raw bytes and is never repaired',
      () {
        final bytes = decodeCString(r'"\xFF\xC0\x80"');
        expect(bytes, [255, 192, 128]);
        expect(() => utf8.decode(bytes), throwsFormatException);
        expect(() => bytes.add(0), throwsUnsupportedError);
      },
    );
  });

  group('Target layouts', () {
    test('WASI and desktop LP64 scalar assumptions are explicit', () {
      for (final target in CLayoutTarget.values) {
        for (final (name, size, alignment) in [
          ('bool', 1, 1),
          ('char', 1, 1),
          ('unsigned short', 2, 2),
          ('int', 4, 4),
          ('uint32_t', 4, 4),
          ('float', 4, 4),
          ('double', 8, 8),
          ('long long', 8, 8),
          ('int64_t', 8, 8),
          ('long double', 16, 16),
          ('long', target.pointerSize, target.pointerSize),
          ('size_t', target.pointerSize, target.pointerSize),
          ('void *', target.pointerSize, target.pointerSize),
          ('char **', target.pointerSize, target.pointerSize),
          ('const char * const *', target.pointerSize, target.pointerSize),
          ('volatile int', 4, 4),
        ]) {
          final type = cTypeLayout(name, target);
          expect(type.size, BigInt.from(size), reason: '$target $name');
          expect(type.alignment, alignment, reason: '$target $name');
        }
      }
      expect(CLayoutTarget.wasi32.assumptions, contains('不是 OHOS 原生 ARM64'));
      expect(CLayoutTarget.systemV64.assumptions, contains('Windows LLP64'));
    });

    test(
      'member offsets, internal and tail padding follow target alignment',
      () {
        const source = 'char tag;\nlong count;\nvoid *data;\nchar end;';
        final wasi = calculateCStructLayout(source, CLayoutTarget.wasi32);
        expect(
          wasi.members.map((m) => m.offset),
          [0, 4, 8, 12].map(BigInt.from),
        );
        expect(
          wasi.members.map((m) => m.paddingBefore),
          [0, 3, 0, 0].map(BigInt.from),
        );
        expect(wasi.size, BigInt.from(16));
        expect(wasi.alignment, 4);
        expect(wasi.trailingPadding, BigInt.from(3));
        final desktop = calculateCStructLayout(source, CLayoutTarget.systemV64);
        expect(
          desktop.members.map((m) => m.offset),
          [0, 8, 16, 24].map(BigInt.from),
        );
        expect(desktop.size, BigInt.from(32));
        expect(desktop.alignment, 8);
        expect(desktop.trailingPadding, BigInt.from(7));
        expect(
          desktop.report,
          contains('void *data: offset=16, size=8, align=8, padding=0'),
        );
      },
    );

    test(
      'array members retain element alignment and multidimensional size',
      () {
        final result = calculateCStructLayout(
          'char a;\nchar label[32];\nint grid[2][3];\nlong double precise;',
          CLayoutTarget.wasi32,
        );
        expect(result.members[1].alignment, 1);
        expect(result.members[1].offset, BigInt.one);
        expect(result.members[2].offset, BigInt.from(36));
        expect(result.members[2].size, BigInt.from(24));
        expect(result.members[3].offset, BigInt.from(64));
        expect(result.size, BigInt.from(80));
        expect(result.alignment, 16);
      },
    );

    test('array lengths follow C decimal, octal and hexadecimal spelling', () {
      final result = calculateCStructLayout(
        'char octal[010];\nchar hex[0x10];\nchar decimal[10];',
        CLayoutTarget.wasi32,
      );
      expect(
        result.members.map((member) => member.size),
        [8, 16, 10].map(BigInt.from),
      );
      expect(result.size, BigInt.from(34));
    });

    test('arithmetic remains exact above JavaScript integer precision', () {
      final result = calculateCStructLayout(
        'char bytes[9007199254740993];\nlong long aligned;',
        CLayoutTarget.systemV64,
      );
      expect(result.members.last.offset, BigInt.parse('9007199254741000'));
      expect(result.size, BigInt.parse('9007199254741008'));
    });

    test(
      'rejects bad arrays, duplicate names, unsupported grammar and overflow',
      () {
        for (final declaration in [
          '',
          'int x[0];',
          'int x[];',
          'int x[-1];',
          'int x[1.5];',
          'int x[08];',
          'int x[1 + 2];',
          'int x[99999999999999999999999999999999];',
          'int x;\nchar x;',
          'int a, b;',
          'int x:3;',
          'struct T t;',
          'void item;',
          'int x = 1;',
          'intx;',
          '#pragma pack(1)',
          'int int;',
          'char class;',
          'int unsigned;',
          'int x[2147483647];',
        ]) {
          expect(
            () => calculateCStructLayout(declaration, CLayoutTarget.wasi32),
            throwsFormatException,
            reason: declaration,
          );
        }
        for (final type in [
          'void',
          'mystery',
          'int[4]',
          'int (*)(void)',
          'int *garbage',
          'unsigned*int',
          'long*long',
        ]) {
          expect(
            () => cTypeLayout(type, CLayoutTarget.wasi32),
            throwsFormatException,
          );
        }
        expect(
          () => calculateCStructLayout(
            'char a[2147483647];\nchar b;',
            CLayoutTarget.wasi32,
          ),
          throwsFormatException,
        );
        expect(
          () => calculateCStructLayout(
            'long long x;\nchar a[2147483639];',
            CLayoutTarget.wasi32,
          ),
          throwsFormatException,
        );
        expect(
          calculateCStructLayout(
            'char a[2147483647];',
            CLayoutTarget.wasi32,
          ).size,
          BigInt.from(2147483647),
        );
      },
    );
  });
}
