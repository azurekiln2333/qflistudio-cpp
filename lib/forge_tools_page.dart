import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'forge_integer_tools.dart';

class ForgeToolsPage extends StatelessWidget {
  const ForgeToolsPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('C/C++ 工具'),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.numbers), text: '进制转换'),
            Tab(icon: Icon(Icons.calculate_outlined), text: '位运算'),
            Tab(icon: Icon(Icons.text_fields), text: 'ASCII'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _IntegerTool(calculate: false),
          _IntegerTool(calculate: true),
          _AsciiTool(),
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

class _IntegerTool extends StatefulWidget {
  const _IntegerTool({required this.calculate});
  final bool calculate;

  @override
  State<_IntegerTool> createState() => _IntegerToolState();
}

class _IntegerToolState extends State<_IntegerTool>
    with AutomaticKeepAliveClientMixin {
  final _a = TextEditingController();
  final _b = TextEditingController();
  int _width = 32;
  BitOperation _operation = BitOperation.and;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('字宽'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final width in const [8, 16, 32, 64])
                    ButtonSegment(value: width, label: Text('$width 位')),
                ],
                selected: {_width},
                onSelectionChanged: (value) =>
                    setState(() => _width = value.single),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('integer-a'),
                controller: _a,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: widget.calculate ? '整数 A' : '整数',
                  border: const OutlineInputBorder(),
                  errorText: errorA,
                  errorMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.calculate) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<BitOperation>(
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
                              }),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _operation = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 24),
              _IntegerResult(word: result),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegerResult extends StatelessWidget {
  const _IntegerResult({required this.word});
  final IntegerWord? word;

  @override
  Widget build(BuildContext context) {
    final values = <String, String>{
      '有符号十进制': word?.signed.toString() ?? '',
      '无符号十进制': word?.pattern.toString() ?? '',
      '十六进制': word?.hexadecimal ?? '',
      '八进制': word?.octal ?? '',
      '二进制': word?.binary ?? '',
    };
    return Column(
      children: [
        for (final entry in values.entries) ...[
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(width: 98, child: Text(entry.key)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      entry.value,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制${entry.key}',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: word == null
                      ? null
                      : () => _copy(context, entry.value),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AsciiTool extends StatefulWidget {
  const _AsciiTool();

  @override
  State<_AsciiTool> createState() => _AsciiToolState();
}

class _AsciiToolState extends State<_AsciiTool>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
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
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('全部')),
                  ButtonSegment(value: 1, label: Text('可打印')),
                  ButtonSegment(value: 2, label: Text('控制字符')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.single),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 44, child: Text('DEC')),
              SizedBox(width: 48, child: Text('HEX')),
              Expanded(child: Text('字符')),
              SizedBox(width: 100, child: Text('C 常量')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('无匹配字符'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(width: 44, child: Text('${entry.code}')),
                            SizedBox(width: 48, child: Text(entry.hex)),
                            Expanded(child: Text(entry.name)),
                            SizedBox(
                              width: 60,
                              child: Text(
                                entry.literal,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            IconButton(
                              tooltip: '复制 ${entry.name} 常量',
                              icon: const Icon(Icons.copy_outlined, size: 20),
                              onPressed: () => _copy(context, entry.literal),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
