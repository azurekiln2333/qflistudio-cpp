import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'forge_development_tools.dart';
import 'forge_integer_tools.dart';

class ForgeToolsPage extends StatelessWidget {
  const ForgeToolsPage({super.key, this.onOpenTerminal});

  final VoidCallback? onOpenTerminal;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('C/C++ 工具')),
    body: ForgeToolsBody(onOpenTerminal: onOpenTerminal),
  );
}

/// Direct tools-tab content. The host supplies its own Scaffold and navigation.
class ForgeToolsBody extends StatelessWidget {
  const ForgeToolsBody({super.key, this.onOpenTerminal});

  final VoidCallback? onOpenTerminal;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('forge-tools-scroll'),
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final columns = constraints.maxWidth >= 900 * scale ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('所有工具均在本机计算。直接输入即可转换、检查或复制结果。'),
                if (onOpenTerminal != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onOpenTerminal,
                      icon: const Icon(Icons.terminal),
                      label: const Text('打开终端'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final tool in const <Widget>[
                      _ToolSection(
                        key: ValueKey('integer-section'),
                        title: '进制转换',
                        icon: Icons.numbers,
                        child: _IntegerTool(calculate: false),
                      ),
                      _ToolSection(
                        key: ValueKey('bit-section'),
                        title: '位运算',
                        icon: Icons.calculate_outlined,
                        child: _IntegerTool(calculate: true),
                      ),
                      _ToolSection(
                        key: ValueKey('string-section'),
                        title: 'UTF-8 / C 字符串',
                        icon: Icons.data_object,
                        child: _CStringTool(),
                      ),
                      _ToolSection(
                        key: ValueKey('layout-section'),
                        title: '类型与结构体布局',
                        icon: Icons.view_agenda_outlined,
                        child: _CLayoutTool(),
                      ),
                      _ToolSection(
                        key: ValueKey('ascii-section'),
                        title: 'ASCII',
                        icon: Icons.text_fields,
                        child: _AsciiTool(),
                      ),
                    ])
                      SizedBox(width: width, child: tool),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('已复制')));
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final option in options.entries)
        ChoiceChip(
          label: Text(option.value),
          selected: selected == option.key,
          onSelected: (_) => onChanged(option.key),
          showCheckmark: false,
        ),
    ],
  );
}

class _CopyResult extends StatelessWidget {
  const _CopyResult({
    required this.label,
    required this.value,
    this.tooltip,
    this.enabled = true,
  });
  final String label;
  final String value;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tooltip ?? '复制$label',
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: enabled ? () => _copy(context, value) : null,
            ),
          ],
        ),
      ),
    ],
  );
}

class _IntegerTool extends StatefulWidget {
  const _IntegerTool({required this.calculate});
  final bool calculate;

  @override
  State<_IntegerTool> createState() => _IntegerToolState();
}

class _IntegerToolState extends State<_IntegerTool> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  int _width = 32;
  BitOperation _operation = BitOperation.and;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IntegerWord? result;
    String? errorA;
    String? errorB;
    if (_a.text.trim().isNotEmpty) {
      try {
        result = IntegerWord(parseToolInteger(_a.text), width: _width);
      } on FormatException catch (error) {
        errorA = error.message;
      }
    }
    if (widget.calculate && result != null) {
      if (_operation == BitOperation.not) {
        result = result.apply(_operation);
      } else if (_b.text.trim().isEmpty) {
        result = null;
      } else {
        try {
          result = result.apply(_operation, operand: parseToolInteger(_b.text));
        } on FormatException catch (error) {
          errorB = error.message;
          result = null;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('字宽 · 二进制补码'),
        const SizedBox(height: 8),
        _Options<int>(
          options: const {8: '8 位', 16: '16 位', 32: '32 位', 64: '64 位'},
          selected: _width,
          onChanged: (value) => setState(() => _width = value),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('integer-a'),
          controller: _a,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: widget.calculate ? '整数 A' : '整数',
            helperText: '十进制或 0x / 0b / 0o 前缀',
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            errorText: errorA,
            errorMaxLines: 4,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (widget.calculate) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<BitOperation>(
                  key: const ValueKey('bit-operation'),
                  initialValue: _operation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '运算',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final operation in BitOperation.values)
                      DropdownMenuItem(
                        value: operation,
                        child: Text(switch (operation) {
                          BitOperation.and => '& AND',
                          BitOperation.or => '| OR',
                          BitOperation.xor => '^ XOR',
                          BitOperation.not => '~ NOT',
                          BitOperation.leftShift => '<< 左移',
                          BitOperation.logicalRightShift => '>> 逻辑右移',
                          BitOperation.arithmeticRightShift => '>> 算术右移',
                        }, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _operation = value);
                  },
                ),
              ),
              IconButton(
                tooltip: '交换操作数',
                icon: const Icon(Icons.swap_vert),
                onPressed: _operation.isBinary
                    ? () => setState(() {
                        final text = _a.text;
                        _a.text = _b.text;
                        _b.text = text;
                      })
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('integer-b'),
            controller: _b,
            enabled: _operation != BitOperation.not,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: _operation.isShift ? '移位量' : '整数 B',
              border: const OutlineInputBorder(),
              errorText: errorB,
              errorMaxLines: 4,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 20),
        for (final entry in <String, String>{
          '有符号十进制': result?.signed.toString() ?? '',
          '无符号十进制': result?.pattern.toString() ?? '',
          '十六进制': result?.hexadecimal ?? '',
          '八进制': result?.octal ?? '',
          '二进制': result?.binary ?? '',
        }.entries)
          _CopyResult(
            label: entry.key,
            value: entry.value,
            enabled: result != null,
          ),
      ],
    );
  }
}

class _CStringTool extends StatefulWidget {
  const _CStringTool();

  @override
  State<_CStringTool> createState() => _CStringToolState();
}

class _CStringToolState extends State<_CStringTool> {
  final _text = TextEditingController();
  final _literal = TextEditingController();
  CStringStyle _style = CStringStyle.readable;

  @override
  void dispose() {
    _text.dispose();
    _literal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? encoded;
    String? encodeError;
    List<int>? bytes;
    String? decodeError;
    String? decoded;
    String? utf8Error;
    try {
      encoded = encodeCString(_text.text, style: _style);
    } on FormatException catch (error) {
      encodeError = error.message;
    }
    if (_literal.text.isNotEmpty) {
      try {
        bytes = decodeCString(_literal.text);
        try {
          decoded = utf8.decode(bytes);
        } on FormatException {
          utf8Error = '字节序列不是有效 UTF-8；仍可复制原始字节。';
        }
      } on FormatException catch (error) {
        decodeError = error.message;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('按 UTF-8 编码，字节数不含 C 字符串隐含的结尾 NUL。数值转义按 8 位字节检查。'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('c-string-text'),
          controller: _text,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '要编码的文本',
            border: const OutlineInputBorder(),
            errorText: encodeError,
            errorMaxLines: 4,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _Options<CStringStyle>(
          options: const {
            CStringStyle.readable: '可读转义',
            CStringStyle.hexadecimal: '全十六进制',
            CStringStyle.octal: '全八进制',
          },
          selected: _style,
          onChanged: (value) => setState(() => _style = value),
        ),
        const SizedBox(height: 8),
        _CopyResult(
          label: 'C 字符串',
          value: encoded ?? '',
          enabled: encoded != null,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('c-string-literal'),
          controller: _literal,
          minLines: 2,
          maxLines: 5,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '要解码的 C 字符串',
            helperText:
                r'例如 "\xC3\xA9" "A"。支持相邻普通字符串、简单转义、\ooo、\xHH；不解析宏、注释、宽字符串、Unicode 转义或续行。',
            helperMaxLines: 20,
            border: const OutlineInputBorder(),
            errorText: decodeError,
            errorMaxLines: 6,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (utf8Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              utf8Error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text('字节数：${bytes?.length ?? '—'}（不含隐含结尾 NUL）'),
        const SizedBox(height: 8),
        _CopyResult(
          label: 'UTF-8 文本',
          value: decoded ?? '',
          enabled: decoded != null,
        ),
        _CopyResult(
          label: '字节列表',
          value: bytes == null ? '' : cByteList(bytes),
          enabled: bytes != null,
        ),
      ],
    );
  }
}

class _CLayoutTool extends StatefulWidget {
  const _CLayoutTool();

  @override
  State<_CLayoutTool> createState() => _CLayoutToolState();
}

class _CLayoutToolState extends State<_CLayoutTool> {
  final _members = TextEditingController(
    text: 'char tag;\nlong count;\nvoid *data;',
  );
  final _type = TextEditingController(text: 'long');
  CLayoutTarget _target = CLayoutTarget.wasi32;

  @override
  void dispose() {
    _members.dispose();
    _type.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CStructLayout? layout;
    CTypeLayout? type;
    String? error;
    String? typeError;
    if (_members.text.trim().isNotEmpty) {
      try {
        layout = calculateCStructLayout(_members.text, _target);
      } on FormatException catch (failure) {
        error = failure.message;
      }
    }
    if (_type.text.trim().isNotEmpty) {
      try {
        type = cTypeLayout(_type.text, _target);
      } on FormatException catch (failure) {
        typeError = failure.message;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Options<CLayoutTarget>(
          options: {
            for (final target in CLayoutTarget.values) target: target.label,
          },
          selected: _target,
          onChanged: (value) => setState(() => _target = value),
        ),
        const SizedBox(height: 8),
        Text(_target.assumptions),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('c-layout-type'),
          controller: _type,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '查询类型，例如 long / double / void *',
            border: const OutlineInputBorder(),
            errorText: typeError,
            errorMaxLines: 4,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _CopyResult(
          label: '类型大小 / 对齐',
          value: type == null
              ? ''
              : 'sizeof=${type.size}, alignof=${type.alignment}',
          enabled: type != null,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('c-layout-members'),
          controller: _members,
          minLines: 3,
          maxLines: 8,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '结构体成员，每行一个',
            helperText:
                '支持基础类型、定宽整数、指针及固定数组（如 int grid[2][3];）。数组长度使用十进制、0 前缀八进制或 0x 十六进制整数。按自然对齐计算；不支持打包、位域、union、嵌套结构、空结构体或 C++ 继承。本工具的对象大小计算上限为目标 PTRDIFF_MAX。',
            helperMaxLines: 30,
            border: const OutlineInputBorder(),
            errorText: error,
            errorMaxLines: 6,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (layout != null) ...[
          for (final member in layout.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    member.declaration,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  Text(
                    '偏移 ${member.offset} · 大小 ${member.size} · 对齐 ${member.alignment} · 前置填充 ${member.paddingBefore}',
                  ),
                ],
              ),
            ),
          Text(
            '总大小 ${layout.size} 字节 · 对齐 ${layout.alignment} · 尾部填充 ${layout.trailingPadding}',
            key: const ValueKey('c-layout-summary'),
          ),
          const SizedBox(height: 8),
        ],
        _CopyResult(
          label: '布局报告',
          value: layout?.report ?? '',
          enabled: layout != null,
        ),
      ],
    );
  }
}

class _AsciiTool extends StatefulWidget {
  const _AsciiTool();

  @override
  State<_AsciiTool> createState() => _AsciiToolState();
}

class _AsciiToolState extends State<_AsciiTool> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _update(VoidCallback update) {
    setState(update);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries =
        [for (var code = 0; code < 128; code++) AsciiCharacter(code)].where((
          entry,
        ) {
          if (_filter == 1 && entry.isControl) return false;
          if (_filter == 2 && !entry.isControl) return false;
          return query.isEmpty ||
              [
                entry.name,
                '${entry.code}',
                '0x${entry.hex}',
                entry.literal,
              ].any((text) => text.toLowerCase().contains(query));
        }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('ascii-search'),
          controller: _search,
          decoration: InputDecoration(
            labelText: '搜索 ASCII',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    icon: const Icon(Icons.clear),
                    onPressed: () => _update(_search.clear),
                  ),
          ),
          onChanged: (_) => _update(() {}),
        ),
        const SizedBox(height: 8),
        _Options<int>(
          options: const {0: '全部', 1: '可打印', 2: '控制字符'},
          selected: _filter,
          onChanged: (value) => _update(() => _filter = value),
        ),
        const SizedBox(height: 8),
        Text('${entries.length} 个匹配字符 · DEC / HEX / C 常量'),
        const SizedBox(height: 8),
        SizedBox(
          key: const ValueKey('ascii-results'),
          height: 280,
          child: entries.isEmpty
              ? const Center(child: Text('无匹配字符'))
              : Scrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    key: const ValueKey('ascii-list'),
                    controller: _scroll,
                    primary: false,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _CopyResult(
                        label: '${entry.code} / ${entry.hex} · ${entry.name}',
                        value: entry.literal,
                        tooltip: '复制 ${entry.name} 常量',
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
