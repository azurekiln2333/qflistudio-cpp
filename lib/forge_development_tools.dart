import 'dart:convert';

enum CStringStyle { readable, hexadecimal, octal }

/// Encodes UTF-8 bytes, independent of the host's execution character set.
/// Octal escapes have exactly three digits; hexadecimal mode escapes every
/// byte, so a following hexadecimal character cannot extend an escape.
String encodeCString(
  String text, {
  CStringStyle style = CStringStyle.readable,
}) {
  _validateUnicode(text);
  return encodeCBytes(utf8.encode(text), style: style);
}

String encodeCBytes(
  List<int> bytes, {
  CStringStyle style = CStringStyle.readable,
}) {
  final result = StringBuffer('"');
  for (final byte in bytes) {
    if (byte < 0 || byte > 255) {
      throw const FormatException('字节必须在 0 到 255 之间');
    }
    if (style == CStringStyle.hexadecimal) {
      result.write(
        '\\x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
      );
    } else if (style == CStringStyle.octal) {
      result.write('\\${byte.toRadixString(8).padLeft(3, '0')}');
    } else {
      result.write(switch (byte) {
        7 => r'\a',
        8 => r'\b',
        9 => r'\t',
        10 => r'\n',
        11 => r'\v',
        12 => r'\f',
        13 => r'\r',
        34 => r'\"',
        // Avoid C17 trigraph preprocessing even when enabled by a compiler.
        63 => r'\?',
        92 => r'\\',
        >= 32 && <= 126 => String.fromCharCode(byte),
        _ => '\\${byte.toRadixString(8).padLeft(3, '0')}',
      });
    }
  }
  return (result..write('"')).toString();
}

/// Parses a strict subset of ordinary C/C++ narrow string literals. Adjacent
/// literals are allowed, but comments, macros, prefixes and preprocessing are
/// intentionally excluded. Numerical escapes must denote an 8-bit byte.
List<int> decodeCString(String source) {
  _validateUnicode(source);
  // C17 trigraph replacement happens before escape parsing, including a
  // sequence whose first question mark appears to belong to a \? escape.
  final trigraph = RegExp(r"\?\?[=/'()!<>-]").firstMatch(source);
  if (trigraph != null) {
    throw FormatException(
      r'不接受三字符组，请分别用 \? 转义问号'
      '（位置 ${trigraph.start + 1}）',
    );
  }
  final bytes = <int>[];
  var position = 0;
  var literals = 0;
  void fail(String message) =>
      throw FormatException('$message（位置 ${position + 1}）');
  while (true) {
    while (position < source.length &&
        const [9, 10, 11, 12, 13, 32].contains(source.codeUnitAt(position))) {
      position++;
    }
    if (position == source.length) break;
    if (source[position] != '"') fail('请输入普通双引号字符串，可用空白拼接多个字符串');
    position++;
    literals++;
    var closed = false;
    while (position < source.length) {
      final unit = source.codeUnitAt(position++);
      if (unit == 34) {
        closed = true;
        break;
      }
      if (unit == 10 || unit == 13 || unit < 32 || unit == 127) {
        fail('控制字符必须使用转义，不支持续行');
      }
      if (unit != 92) {
        var character = String.fromCharCode(unit);
        if (unit >= 0xD800 && unit <= 0xDBFF) {
          character += source[position++];
        }
        bytes.addAll(utf8.encode(character));
        continue;
      }
      if (position == source.length) fail('转义不完整');
      final escape = source[position++];
      const simple = {
        'a': 7,
        'b': 8,
        't': 9,
        'n': 10,
        'v': 11,
        'f': 12,
        'r': 13,
        '"': 34,
        "'": 39,
        '?': 63,
        r'\': 92,
      };
      if (simple.containsKey(escape)) {
        bytes.add(simple[escape]!);
      } else if (RegExp(r'[0-7]').hasMatch(escape)) {
        var digits = escape;
        while (digits.length < 3 &&
            position < source.length &&
            RegExp(r'[0-7]').hasMatch(source[position])) {
          digits += source[position++];
        }
        final value = int.parse(digits, radix: 8);
        if (value > 255) fail('八进制转义超出 8 位字节范围');
        bytes.add(value);
      } else if (escape == 'x') {
        final start = position;
        while (position < source.length &&
            RegExp(r'[0-9a-fA-F]').hasMatch(source[position])) {
          position++;
        }
        if (position == start) fail(r'\x 后至少需要一位十六进制数字');
        final value = BigInt.parse(
          source.substring(start, position),
          radix: 16,
        );
        if (value > BigInt.from(255)) {
          fail(r'十六进制转义超出 8 位范围；\x 会读取所有连续的十六进制数字，请拆成相邻字符串');
        }
        bytes.add(value.toInt());
      } else {
        fail(r'不支持的转义；请使用简单转义、\ooo 或 \xHH');
      }
    }
    if (!closed) fail('缺少字符串结束双引号');
  }
  if (literals == 0) fail('请输入至少一个双引号字符串，空字符串写作 ""');
  return List.unmodifiable(bytes);
}

void _validateUnicode(String text) {
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (++index >= text.length ||
          text.codeUnitAt(index) < 0xDC00 ||
          text.codeUnitAt(index) > 0xDFFF) {
        throw const FormatException('文本包含未配对的 UTF-16 代理项');
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      throw const FormatException('文本包含未配对的 UTF-16 代理项');
    }
  }
}

String cByteList(List<int> bytes) => bytes
    .map((byte) => '0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}')
    .join(', ');

enum CLayoutTarget {
  wasi32,
  systemV64;

  String get label => switch (this) {
    wasi32 => 'OHOS / WASI32',
    systemV64 => '桌面 / LP64',
  };

  String get assumptions => switch (this) {
    wasi32 =>
      'OHOS 打包工具链的 wasm32-WASI ILP32：8 位字节；指针、long、size_t 为 4 字节；'
          'long long / double 对齐 8，long double 为 16 / 16。不是 OHOS 原生 ARM64 ABI。',
    systemV64 =>
      'x86_64 System V LP64（Linux / 常见 Unix）：8 位字节；指针、long、size_t 为 8 字节；'
          'long double 为 16 / 16。不适用于 Windows LLP64、其他架构或自定义编译选项。',
  };

  int get pointerSize => this == wasi32 ? 4 : 8;

  /// A conservative object bound that keeps every offset within PTRDIFF_MAX.
  BigInt get maximumObjectSize =>
      (BigInt.one << (pointerSize * 8 - 1)) - BigInt.one;
}

class CTypeLayout {
  const CTypeLayout(this.size, this.alignment);
  final BigInt size;
  final int alignment;
}

/// Scalar types and pointers only: this is an explicit ABI calculator, not a C
/// parser. Pointer pointee spelling is restricted to supported scalar types.
CTypeLayout cTypeLayout(String type, CLayoutTarget target) {
  final normalized = type.trim().replaceAll(RegExp(r'\s+'), ' ');
  final firstStar = normalized.indexOf('*');
  final pointer = firstStar >= 0;
  if (pointer &&
      !RegExp(
        r'^(?:\*\s*(?:(?:const|volatile)\b\s*)*)+$',
      ).hasMatch(normalized.substring(firstStar))) {
    throw FormatException('不支持的指针声明：$type');
  }
  final base = (pointer ? normalized.substring(0, firstStar) : normalized)
      .trim()
      .split(' ')
      .where((token) => token != 'const' && token != 'volatile')
      .join(' ');
  const byteTypes = [
    'char',
    'signed char',
    'unsigned char',
    'int8_t',
    'uint8_t',
  ];
  const shortTypes = [
    'short',
    'short int',
    'signed short',
    'signed short int',
    'unsigned short',
    'unsigned short int',
    'int16_t',
    'uint16_t',
  ];
  const intTypes = [
    'int',
    'signed',
    'signed int',
    'unsigned',
    'unsigned int',
    'int32_t',
    'uint32_t',
  ];
  const longTypes = [
    'long',
    'long int',
    'signed long',
    'signed long int',
    'unsigned long',
    'unsigned long int',
  ];
  const longLongTypes = [
    'long long',
    'long long int',
    'signed long long',
    'signed long long int',
    'unsigned long long',
    'unsigned long long int',
    'int64_t',
    'uint64_t',
  ];
  final (size, alignment) = switch (base) {
    'bool' || '_Bool' => (1, 1),
    'float' => (4, 4),
    'double' => (8, 8),
    'long double' => (16, 16),
    'size_t' ||
    'ptrdiff_t' ||
    'intptr_t' ||
    'uintptr_t' => (target.pointerSize, target.pointerSize),
    _ when byteTypes.contains(base) => (1, 1),
    _ when shortTypes.contains(base) => (2, 2),
    _ when intTypes.contains(base) => (4, 4),
    _ when longTypes.contains(base) => (target.pointerSize, target.pointerSize),
    _ when longLongTypes.contains(base) => (8, 8),
    'void' when pointer => (0, 1),
    _ => throw FormatException('不支持的类型：$type'),
  };
  return pointer
      ? CTypeLayout(BigInt.from(target.pointerSize), target.pointerSize)
      : CTypeLayout(BigInt.from(size), alignment);
}

class CMemberLayout {
  const CMemberLayout({
    required this.declaration,
    required this.name,
    required this.offset,
    required this.size,
    required this.alignment,
    required this.paddingBefore,
  });
  final String declaration;
  final String name;
  final BigInt offset;
  final BigInt size;
  final int alignment;
  final BigInt paddingBefore;
}

class CStructLayout {
  const CStructLayout({
    required this.members,
    required this.size,
    required this.alignment,
    required this.trailingPadding,
  });
  final List<CMemberLayout> members;
  final BigInt size;
  final int alignment;
  final BigInt trailingPadding;

  String get report => [
    for (final member in members)
      '${member.declaration}: offset=${member.offset}, size=${member.size}, '
          'align=${member.alignment}, padding=${member.paddingBefore}',
    'sizeof=$size, alignof=$alignment, trailing padding=$trailingPadding',
  ].join('\n');
}

final _cMemberKeywords = {
  ...('alignas alignof and and_eq asm auto bitand bitor bool break case catch '
          'char char8_t char16_t char32_t class compl concept const consteval '
          'constexpr constinit const_cast continue co_await co_return co_yield '
          'decltype default delete do double dynamic_cast else enum explicit export '
          'extern false float for friend goto if inline int long mutable namespace '
          'new noexcept not not_eq nullptr operator or or_eq private protected public '
          'register reinterpret_cast requires restrict return short signed sizeof '
          'static static_assert static_cast struct switch template this thread_local '
          'throw true try typedef typeid typename union unsigned using virtual void '
          'volatile wchar_t while xor xor_eq _Alignas _Alignof _Atomic _Bool _Complex '
          '_Generic _Imaginary _Noreturn _Static_assert _Thread_local')
      .split(' '),
};

/// Computes an unpacked aggregate with natural member alignment. Accepted
/// grammar is one scalar/pointer member per line, optionally with fixed arrays.
/// No bitfields, unions, nested declarations, packing or C++ object ABI.
CStructLayout calculateCStructLayout(
  String declarations,
  CLayoutTarget target,
) {
  final members = <CMemberLayout>[];
  final names = <String>{};
  var offset = BigInt.zero;
  var structAlignment = 1;
  final lines = declarations.split('\n');
  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    var line = lines[lineNumber].trim();
    if (line.isEmpty) continue;
    if (line.endsWith(';')) line = line.substring(0, line.length - 1).trim();
    try {
      final match = RegExp(
        r'^(.+?[\s*])([a-zA-Z_][a-zA-Z_0-9]*)\s*((?:\[\s*(?:0[xX][0-9a-fA-F]+|[0-9]+)\s*\]\s*)*)$',
      ).firstMatch(line);
      if (match == null) {
        throw const FormatException('每行填写一个成员，例如 int count; 或 char name[16];');
      }
      final name = match[2]!;
      if (_cMemberKeywords.contains(name)) {
        throw FormatException('成员名不能使用 C/C++ 关键字：$name');
      }
      if (!names.add(name)) throw FormatException('成员名重复：$name');
      final type = cTypeLayout(match[1]!, target);
      var size = type.size;
      for (final dimension in RegExp(
        r'\[\s*(0[xX][0-9a-fA-F]+|[0-9]+)\s*\]',
      ).allMatches(match[3]!)) {
        final spelling = dimension[1]!;
        final hexadecimal = spelling.toLowerCase().startsWith('0x');
        final radix = hexadecimal
            ? 16
            : spelling.startsWith('0')
            ? 8
            : 10;
        final count = BigInt.tryParse(
          hexadecimal ? spelling.substring(2) : spelling,
          radix: radix,
        );
        if (count == null) {
          throw const FormatException('数组长度不是有效的 C 整数常量');
        }
        if (count <= BigInt.zero) {
          throw const FormatException('数组长度必须是正整数，不支持柔性或零长数组');
        }
        size *= count;
        if (size > target.maximumObjectSize) {
          throw const FormatException('数组大小超过目标 PTRDIFF_MAX 计算上限');
        }
      }
      final aligned = _alignUp(offset, type.alignment);
      if (aligned + size > target.maximumObjectSize) {
        throw const FormatException('结构体大小超过目标 PTRDIFF_MAX 计算上限');
      }
      members.add(
        CMemberLayout(
          declaration: line,
          name: name,
          offset: aligned,
          size: size,
          alignment: type.alignment,
          paddingBefore: aligned - offset,
        ),
      );
      offset = aligned + size;
      if (type.alignment > structAlignment) structAlignment = type.alignment;
    } on FormatException catch (error) {
      throw FormatException('第 ${lineNumber + 1} 行：${error.message}');
    }
  }
  if (members.isEmpty) throw const FormatException('请输入至少一个成员');
  final total = _alignUp(offset, structAlignment);
  if (total > target.maximumObjectSize) {
    throw const FormatException('包含尾部填充后超过目标 PTRDIFF_MAX 计算上限');
  }
  return CStructLayout(
    members: List.unmodifiable(members),
    size: total,
    alignment: structAlignment,
    trailingPadding: total - offset,
  );
}

BigInt _alignUp(BigInt offset, int alignment) {
  final divisor = BigInt.from(alignment);
  return (offset + divisor - BigInt.one) ~/ divisor * divisor;
}
