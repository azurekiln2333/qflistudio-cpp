BigInt parseToolInteger(String source) {
  var text = source.trim();
  var negative = false;
  if (text.startsWith('-') || text.startsWith('+')) {
    negative = text.startsWith('-');
    text = text.substring(1);
  }
  final prefix = text.length >= 2 ? text.substring(0, 2).toLowerCase() : '';
  final radix = switch (prefix) {
    '0x' => 16,
    '0b' => 2,
    '0o' => 8,
    _ => 10,
  };
  if (radix != 10) text = text.substring(2);
  if (text.startsWith('-') || text.startsWith('+')) {
    throw const FormatException('整数格式无效');
  }
  final value = BigInt.tryParse(text, radix: radix);
  if (value == null) throw const FormatException('整数格式无效');
  return negative ? -value : value;
}

enum BitOperation {
  and,
  or,
  xor,
  not,
  leftShift,
  logicalRightShift,
  arithmeticRightShift;

  bool get isShift => index >= leftShift.index;
  bool get isBinary => index <= xor.index;
}

class IntegerWord {
  factory IntegerWord(BigInt value, {required int width}) {
    if (!const [8, 16, 32, 64].contains(width)) {
      throw ArgumentError.value(width, 'width');
    }
    final limit = BigInt.one << width;
    if (value < -(limit >> 1) || value >= limit) {
      throw FormatException('数值超出 $width 位整数范围');
    }
    return IntegerWord._(value & (limit - BigInt.one), width);
  }

  const IntegerWord._(this.pattern, this.width);

  final BigInt pattern;
  final int width;
  BigInt get mask => (BigInt.one << width) - BigInt.one;
  BigInt get signed => pattern >= (BigInt.one << (width - 1))
      ? pattern - (BigInt.one << width)
      : pattern;
  String get hexadecimal =>
      '0x${pattern.toRadixString(16).toUpperCase().padLeft(width ~/ 4, '0')}';
  String get octal => '0${pattern.toRadixString(8)}';
  String get binary => '0b${pattern.toRadixString(2).padLeft(width, '0')}';

  IntegerWord apply(BitOperation operation, {BigInt? operand}) {
    if (operation == BitOperation.not) {
      return IntegerWord._(~pattern & mask, width);
    }
    if (operand == null) throw ArgumentError.notNull('operand');
    if (operation.isShift) {
      if (operand < BigInt.zero || operand >= BigInt.from(width)) {
        throw FormatException('移位量必须在 0 到 ${width - 1} 之间');
      }
      final shift = operand.toInt();
      final value = switch (operation) {
        BitOperation.leftShift => pattern << shift,
        BitOperation.logicalRightShift => pattern >> shift,
        BitOperation.arithmeticRightShift => signed >> shift,
        _ => throw StateError('Invalid shift operation'),
      };
      return IntegerWord._(value & mask, width);
    }
    final right = IntegerWord(operand, width: width).pattern;
    final value = switch (operation) {
      BitOperation.and => pattern & right,
      BitOperation.or => pattern | right,
      BitOperation.xor => pattern ^ right,
      _ => throw StateError('Invalid bit operation'),
    };
    return IntegerWord._(value, width);
  }
}

class AsciiCharacter {
  const AsciiCharacter(this.code) : assert(code >= 0 && code <= 127);

  static const _controls = [
    'NUL',
    'SOH',
    'STX',
    'ETX',
    'EOT',
    'ENQ',
    'ACK',
    'BEL',
    'BS',
    'HT',
    'LF',
    'VT',
    'FF',
    'CR',
    'SO',
    'SI',
    'DLE',
    'DC1',
    'DC2',
    'DC3',
    'DC4',
    'NAK',
    'SYN',
    'ETB',
    'CAN',
    'EM',
    'SUB',
    'ESC',
    'FS',
    'GS',
    'RS',
    'US',
  ];

  final int code;
  bool get isControl => code < 32 || code == 127;
  String get hex => code.toRadixString(16).toUpperCase().padLeft(2, '0');
  String get name => code < 32
      ? _controls[code]
      : code == 127
      ? 'DEL'
      : code == 32
      ? 'SPACE'
      : String.fromCharCode(code);
  String get literal {
    final escaped = switch (code) {
      0 => r'\0',
      7 => r'\a',
      8 => r'\b',
      9 => r'\t',
      10 => r'\n',
      11 => r'\v',
      12 => r'\f',
      13 => r'\r',
      39 => r"\'",
      92 => r'\\',
      _ => isControl ? '\\x$hex' : String.fromCharCode(code),
    };
    return "'$escaped'";
  }
}
