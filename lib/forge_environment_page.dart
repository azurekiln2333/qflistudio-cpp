import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qfli_studio_core/widgets/settings_section.dart';

import 'toolchain/toolchain_environment.dart';

/// 桌面编译器环境页：显示当前编译器、首选编译器、工具链目录和一键配置。
///
/// 只在 [environment] 的 `supported` 为 true 时由工具页打开。页面本身不判断
/// 平台，也不直接访问文件系统或网络，全部动作交给 [environment]。
class ForgeEnvironmentPage extends StatefulWidget {
  const ForgeEnvironmentPage({
    super.key,
    required this.environment,
    this.pickDirectory,
  });

  final ToolchainEnvironment environment;

  /// 选择工具链目录。为 null 时使用系统目录选择器。
  ///
  /// 测试传入假实现，因此这里不做缓存，每次点击都重新取值。
  final Future<String?> Function()? pickDirectory;

  @override
  State<ForgeEnvironmentPage> createState() => _ForgeEnvironmentPageState();
}

/// 一次检测的结果，或者检测前的状态。
class _Detection {
  const _Detection() : running = false, compilers = const [];

  const _Detection.running() : running = true, compilers = const [];

  const _Detection.found(this.compilers) : running = false;

  /// 为 true 时页面显示检测进度。检测期间 [compilers] 仍为上一次的结果。
  final bool running;

  /// 按语言分组前的顺序就是 `detect()` 的顺序，每种语言的第一项为在用编译器。
  final List<DetectedCompiler> compilers;

  List<DetectedCompiler> of(String language) => [
    for (final c in compilers)
      if (c.language == language) c,
  ];
}

/// 正在运行的一键配置动作。
class _SetupRun {
  _SetupRun(this.option, this.events, this.progress);

  final ToolchainSetupOption option;
  final Stream<ToolchainSetupProgress> events;

  /// 当前阶段和最近的输出行。
  ToolchainSetupProgress progress;
  List<String> log = const [];

  /// 用户点过「取消」，等待环境的 `cancelled` 事件。
  bool requestedCancel = false;
}

class _ForgeEnvironmentPageState extends State<ForgeEnvironmentPage> {
  ToolchainEnvironment get _environment => widget.environment;

  _Detection _detection = const _Detection();
  List<ToolchainSetupOption>? _setupOptions;
  _SetupRun? _setup;
  StreamSubscription<ToolchainSetupProgress>? _setupSubscription;

  /// 正在切换的首选编译器，null 表示空闲。
  CompilerPreference? _preferenceBusy;

  /// 正在进行的目录或移除动作。非空时禁用对应入口。
  bool _directoryBusy = false;
  String? _removing;

  /// 上一次目录修改的结果提示。
  String? _directoryMessage;
  bool _directoryMessageIsError = false;

  /// 用户点过「重新检测」：此次检测完成后用提示条说明结果。
  bool _announceDetection = false;

  /// `load()` 已完成。之后环境的通知不再触发首次检测。
  bool _loaded = false;

  /// 新请求取代了上一次检测。
  int _detectRun = 0;

  @override
  void initState() {
    super.initState();
    _environment.addListener(_onEnvironmentChanged);
    unawaited(_startLoad());
  }

  @override
  void dispose() {
    _environment.removeListener(_onEnvironmentChanged);
    _setupSubscription?.cancel();
    super.dispose();
  }

  /// 环境变化（包括一键配置或移除的结果，以及加载完成）时重建，并重新检测。
  ///
  /// 离开页面不取消动作：取消订阅不会停止动作（见接口注释），
  /// 所以订阅保留到流关闭，结果由环境自己保存并通知其他听众。
  void _onEnvironmentChanged() {
    if (!mounted) return;
    setState(() {});
    if (_loaded) {
      unawaited(_detect());
    } else if (!_detection.running) {
      // 加载自行发出了通知：环境已经就绪，不必等待 `load()` 的完成。
      _loaded = true;
      unawaited(_detect());
    }
  }

  Future<void> _startLoad() async {
    try {
      await _environment.load();
    } on Object catch (error) {
      if (mounted) _showMessage('读取环境设置失败：$error');
    }
    if (!mounted) return;
    if (_loaded) return;
    _loaded = true;
    await Future.wait([_detect(), _loadSetupOptions()]);
  }

  Future<void> _detect() async {
    final run = ++_detectRun;
    setState(() => _detection = const _Detection.running());
    final announce = _announceDetection;
    _announceDetection = false;
    List<DetectedCompiler> found;
    try {
      found = await _environment.detect();
    } on Object catch (error) {
      if (!mounted || run != _detectRun) return;
      setState(() => _detection = const _Detection());
      _showMessage('重新检测失败：$error');
      return;
    }
    if (!mounted || run != _detectRun) return;
    setState(() => _detection = _Detection.found(List.unmodifiable(found)));
    if (!announce) return;
    final c = _detection.of('c');
    final cpp = _detection.of('cpp');
    _showMessage(
      c.isEmpty && cpp.isEmpty
          ? '重新检测完成：没有找到编译器。'
          : '重新检测完成：C ${_familyName(c)}, C++ ${_familyName(cpp)}。',
    );
  }

  static String _familyName(List<DetectedCompiler> found) =>
      found.isEmpty ? '无' : _familyLabel(found.first.family);

  Future<void> _loadSetupOptions() async {
    List<ToolchainSetupOption> options;
    try {
      options = await _environment.setupOptions();
    } on Object catch (error) {
      if (mounted) _showMessage('读取一键配置失败：$error');
      options = const [];
    }
    if (!mounted) return;
    setState(() => _setupOptions = List.unmodifiable(options));
  }

  Future<void> _setPreference(CompilerPreference preference) async {
    if (_preferenceBusy != null) return;
    setState(() => _preferenceBusy = preference);
    try {
      await _environment.setPreference(preference);
    } on Object catch (error) {
      if (mounted) _showMessage('保存首选编译器失败：$error');
    }
    if (!mounted) return;
    setState(() => _preferenceBusy = null);
    await _detect();
  }

  Future<String?> _chooseDirectory() async {
    final picker = widget.pickDirectory ?? getDirectoryPath;
    try {
      return await picker();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _directoryMessage = '打开目录选择器失败：$error';
          _directoryMessageIsError = true;
        });
      }
      return null;
    }
  }

  Future<void> _applyDirectory(String? directory) async {
    if (_directoryBusy) return;
    setState(() {
      _directoryBusy = true;
      _directoryMessage = null;
      _directoryMessageIsError = false;
    });
    try {
      await _environment.setDirectory(directory);
      if (!mounted) return;
      await _detect();
      if (!mounted) return;
      // 以环境里的设置为准：加载完成前它可能已经变成其他值。
      final saved = _environment.settings.directory;
      if (saved == null) {
        setState(() {
          _directoryBusy = false;
          _directoryMessage = '已清除工具链目录。';
          _directoryMessageIsError = false;
        });
        return;
      }
      final used = _configuredCompilers();
      setState(() {
        _directoryBusy = false;
        if (used.isNotEmpty) {
          final first = used.first;
          _directoryMessage =
              '此工具链目录可用：${_familyLabel(first.family)} ${first.executable}';
          _directoryMessageIsError = false;
        } else {
          _directoryMessage = '这个工具链目录中没有找到编译器。目录里需要有 bin/ 子目录。';
          _directoryMessageIsError = true;
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _directoryBusy = false;
        _directoryMessage = '保存工具链目录失败：$error';
        _directoryMessageIsError = true;
      });
    }
  }

  /// 来自 `工具链目录` 的编译器：有它就是目录可用的证据。
  List<DetectedCompiler> _configuredCompilers() => [
    for (final compiler in _detection.compilers)
      if (compiler.source == CompilerSource.configuredDirectory) compiler,
  ];

  Future<void> _pickDirectory() async {
    final picked = await _chooseDirectory();
    if (!mounted || picked == null) return;
    await _applyDirectory(picked);
  }

  Future<void> _editDirectory() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (context) =>
          _DirectoryDialog(initial: _environment.settings.directory),
    );
    if (!mounted || typed == null) return;
    await _applyDirectory(typed.isEmpty ? null : typed);
  }

  /// 阶段为终态时收到事件：按最终状态收尾。
  void _onSetupEvent(_SetupRun run, ToolchainSetupProgress event) {
    if (!mounted) return;
    if (run.progress.isFinal) {
      // 终态之后到达的事件不再影响界面。
      return;
    }
    final log = event.message.isEmpty
        ? run.log
        : <String>[...run.log, event.message];
    setState(() {
      run.log = log.length > 50 ? log.sublist(log.length - 50) : log;
      run.progress = event;
    });
    // 终态之后重新读取列表：失败和取消也可能留下部分结果。
    switch (event.phase) {
      case ToolchainSetupPhase.done:
        unawaited(_applySetupDone(run));
      case ToolchainSetupPhase.failed:
      case ToolchainSetupPhase.cancelled:
        unawaited(_loadSetupOptions());
      case ToolchainSetupPhase.preparing:
      case ToolchainSetupPhase.downloading:
      case ToolchainSetupPhase.verifying:
      case ToolchainSetupPhase.extracting:
      case ToolchainSetupPhase.running:
      case ToolchainSetupPhase.detecting:
        break;
    }
  }

  /// 流的终点只决定订阅本身，界面状态由最后一个事件决定。
  void _onSetupDone(_SetupRun run) {
    if (!mounted) return;
    if (run.progress.isFinal) return;
    // 没有任何终态事件就关闭的流按失败处理，避免界面一直停在运行中。
    _onSetupEvent(
      run,
      const ToolchainSetupProgress(
        phase: ToolchainSetupPhase.failed,
        message: '一键配置提前结束，没有返回结果。',
      ),
    );
  }

  Future<void> _applySetupDone(_SetupRun run) async {
    await _loadSetupOptions();
    if (!mounted) return;
    await _detect();
    if (!mounted) return;
    _showMessage('${run.option.title}已完成。');
  }

  void _closeSetup() {
    unawaited(_setupSubscription?.cancel());
    _setupSubscription = null;
    setState(() => _setup = null);
  }

  Future<void> _cancelSetup() async {
    try {
      await _environment.cancelSetup();
    } on Object catch (error) {
      if (mounted) _showMessage('取消失败：$error');
    }
    if (!mounted) return;
    final run = _setup;
    if (run == null || run.progress.isFinal) return;
    // 只标出“已请求取消”：真正的终态由环境的 `cancelled` 事件给出。
    setState(() => run.requestedCancel = true);
  }

  Future<void> _remove(ToolchainSetupOption option) async {
    if (_removing != null || _setup != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('移除 ${option.title}'),
        content: Text(
          '这会删除一键配置安装的工具链「${option.title}」。'
          '之后需要重新配置才能使用它。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _removing = option.id);
    try {
      await _environment.remove(option.id);
    } on Object catch (error) {
      if (mounted) _showMessage('移除失败：$error');
    }
    if (!mounted) return;
    setState(() => _removing = null);
    await _loadSetupOptions();
    if (!mounted) return;
    await _detect();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = _environment.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('环境配置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _compilerSection(context),
              _preferenceSection(context, settings),
              _directorySection(context, settings),
              _setupSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compilerSection(BuildContext context) {
    final theme = Theme.of(context);
    final running = _detection.running;
    return SettingsSection(
      title: '当前编译器',
      children: [
        for (final language in const ['c', 'cpp'])
          _compilerTile(context, language, _detection.of(language)),
        if (running)
          ListTile(
            key: const ValueKey('environment-detecting'),
            leading: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            title: const Text('正在检测编译器…'),
            subtitle: const Text('检测可能需要几十秒，可以继续使用页面上的其他入口。'),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('environment-redetect'),
              onPressed: running
                  ? null
                  : () {
                      _announceDetection = true;
                      unawaited(_detect());
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('重新检测'),
            ),
          ),
        ),
        if (!running)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '首次运行会按首选编译器查找。没有编译器时，可以在下面的「一键配置」'
              '安装，或在「工具链目录」中选择已有工具链。',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _compilerTile(
    BuildContext context,
    String language,
    List<DetectedCompiler> found,
  ) {
    final theme = Theme.of(context);
    final title = language == 'c' ? 'C' : 'C++';
    final key = ValueKey('environment-compiler-$language');
    if (found.isEmpty) {
      final text = _detection.running
          ? '$title：正在查找…'
          : '$title：没有找到编译器。请在下方「一键配置」安装，或在「工具链目录」中选择已有工具链。';
      return ListTile(
        key: key,
        leading: const Icon(Icons.build_outlined),
        title: Text(text),
        subtitle: _detection.running
            ? const LinearProgressIndicator(minHeight: 2)
            : null,
      );
    }
    final active = found.first;
    final others = found.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$title（在用）', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          _compilerDetails(context, active, keyPrefix: key),
          if (others.isNotEmpty)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('environment-compiler-$language-others'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text('另外找到 ${others.length} 个'),
                children: [
                  for (final item in others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _compilerDetails(
                        context,
                        item,
                        keyPrefix: ValueKey(
                          'environment-compiler-$language-${item.executable}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compilerDetails(
    BuildContext context,
    DetectedCompiler compiler, {
    required Key keyPrefix,
  }) => Column(
    key: keyPrefix,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LabelledValue(
        label: '类型',
        value:
            '${_familyLabel(compiler.family)}'
            '${compiler.standard.isEmpty ? '' : ' · ${compiler.standard}'}',
      ),
      if (compiler.version.isNotEmpty)
        _LabelledValue(label: '版本', value: compiler.version),
      _LabelledValue(
        label: '路径',
        value: compiler.executable,
        copyValue: compiler.executable,
      ),
      _LabelledValue(label: '来源', value: _sourceLabel(compiler.source)),
    ],
  );

  Widget _preferenceSection(BuildContext context, ToolchainSettings settings) {
    final busy = _preferenceBusy != null;
    return SettingsSection(
      title: '首选编译器',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preference in CompilerPreference.values)
                ChoiceChip(
                  key: ValueKey('environment-preference-${preference.name}'),
                  label: Text(_preferenceLabel(preference)),
                  showCheckmark: false,
                  selected: settings.preference == preference,
                  onSelected: busy || settings.preference == preference
                      ? null
                      : (_) => _setPreference(preference),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _preferenceHint(settings.preference),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _directorySection(BuildContext context, ToolchainSettings settings) {
    final directory = settings.directory;
    final theme = Theme.of(context);
    return SettingsSection(
      title: '工具链目录',
      children: [
        ListTile(
          key: const ValueKey('environment-directory'),
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('当前工具链目录'),
          subtitle: Text(
            directory ?? '未选择工具链目录',
            key: const ValueKey('environment-directory-value'),
          ),
          trailing: directory == null
              ? null
              : IconButton(
                  key: const ValueKey('environment-directory-copy'),
                  tooltip: '复制工具链目录',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: () => _copy(context, directory),
                ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('目录内需要有 bin/ 子目录，其中包含 gcc、g++、clang 或 clang++。'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('environment-directory-pick'),
              onPressed: _directoryBusy ? null : _pickDirectory,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('选择目录'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('environment-directory-edit'),
              onPressed: _directoryBusy ? null : _editDirectory,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('输入路径'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('environment-directory-clear'),
              onPressed: _directoryBusy || directory == null
                  ? null
                  : () => _applyDirectory(null),
              icon: const Icon(Icons.clear),
              label: const Text('清除'),
            ),
          ],
        ),
        if (_directoryBusy)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_directoryMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _directoryMessage!,
              key: const ValueKey('environment-directory-message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _directoryMessageIsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _setupSection(BuildContext context) {
    final theme = Theme.of(context);
    final options = _setupOptions;
    final run = _setup;
    return SettingsSection(
      title: '一键配置',
      children: [
        if (options == null)
          const ListTile(
            key: ValueKey('environment-setup-loading'),
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            title: Text('正在读取可用的一键配置…'),
          )
        else if (options.isEmpty)
          const ListTile(
            key: ValueKey('environment-setup-empty'),
            leading: Icon(Icons.info_outline),
            title: Text('当前平台没有可用的一键配置。请手动安装编译器，然后在上方选择工具链目录。'),
          )
        else
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _setupOptionTile(context, options[index], run),
          ],
        if (run != null) ...[
          const Divider(height: 1),
          _setupProgress(context, run),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            '一键配置不会修改 PATH、注册表或系统设置。安装后的工具链由本应用管理，'
            '可以在同一列表中移除。关闭页面或取消下载不会停止已经开始的配置。',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// 一行一键配置。点击打开对话框：对话框完整显示说明，确认后开始。
  Widget _setupOptionTile(
    BuildContext context,
    ToolchainSetupOption option,
    _SetupRun? run,
  ) {
    final busy = run != null;
    final markers = <String>[
      if (option.installed) '已安装',
      if (option.needsAdministrator) '需要管理员权限',
      if (option.downloadBytes != null) _formatBytes(option.downloadBytes!),
    ];
    return Column(
      key: ValueKey('environment-setup-${option.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            option.installed
                ? Icons.check_circle_outline
                : Icons.download_outlined,
          ),
          title: Text(option.title),
          subtitle: Text(
            markers.isEmpty
                ? option.summary
                : '${option.summary}\n${markers.join(' · ')}',
          ),
          isThreeLine: markers.isNotEmpty,
          selected: run?.option.id == option.id,
          trailing: option.removable && option.installed
              ? IconButton(
                  key: ValueKey('environment-remove-${option.id}'),
                  tooltip: '移除 ${option.title}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy || _removing != null
                      ? null
                      : () => _remove(option),
                )
              : null,
          enabled: !busy,
          onTap: busy ? null : () => _startSetup(option),
        ),
        if (option.removable && option.installed && _removing == option.id)
          const Padding(
            padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// 列表入口直接进入确认对话框：用户在任何动作开始前就能看到完整命令或地址。
  Future<void> _startSetup(ToolchainSetupOption option) async {
    if (_setup != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _SetupConfirmDialog(option: option),
    );
    if (!mounted || confirmed != true || _setup != null) return;
    await _setupSubscription?.cancel();
    if (!mounted) return;
    final run = _SetupRun(
      option,
      _environment.runSetup(option.id),
      const ToolchainSetupProgress(phase: ToolchainSetupPhase.preparing),
    );
    setState(() => _setup = run);
    _setupSubscription = run.events.listen(
      (event) => _onSetupEvent(run, event),
      onError: (Object error) => _onSetupEvent(
        run,
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '一键配置中断：$error',
        ),
      ),
      onDone: () => _onSetupDone(run),
    );
  }

  Widget _setupProgress(BuildContext context, _SetupRun run) {
    final theme = Theme.of(context);
    final progress = run.progress;
    final phase = progress.phase;
    final received = progress.received;
    final total = progress.total;
    final determinate = received != null && total != null && total > 0;
    return Padding(
      key: const ValueKey('environment-setup-progress'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${run.option.title} · ${_phaseLabel(phase)}',
            key: const ValueKey('environment-setup-phase'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (determinate)
            LinearProgressIndicator(
              key: const ValueKey('environment-setup-bar'),
              value: (received / total).clamp(0.0, 1.0),
              minHeight: 4,
            )
          else if (!progress.isFinal)
            const LinearProgressIndicator(
              key: ValueKey('environment-setup-bar'),
              minHeight: 4,
            ),
          const SizedBox(height: 8),
          if (determinate)
            Text(
              '${_formatBytes(received)} / ${_formatBytes(total)}',
              style: theme.textTheme.bodySmall,
            ),
          if (run.log.isNotEmpty) ...[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  key: const ValueKey('environment-setup-log'),
                  height: 120,
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      primary: false,
                      reverse: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in run.log)
                            Text(
                              line,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!progress.isFinal)
                OutlinedButton.icon(
                  key: const ValueKey('environment-setup-cancel'),
                  onPressed: run.requestedCancel ? null : _cancelSetup,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(run.requestedCancel ? '正在取消' : '取消'),
                )
              else
                OutlinedButton(
                  key: const ValueKey('environment-setup-close'),
                  onPressed: _closeSetup,
                  child: const Text('返回列表'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一个带标签的值，长的路径自动换行，并提供复制按钮。
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({
    required this.label,
    required this.value,
    this.copyValue,
  });

  final String label;
  final String value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
        if (copyValue != null)
          IconButton(
            tooltip: '复制$label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () => _copy(context, copyValue!),
          ),
      ],
    ),
  );
}

/// 输入工具链目录。返回去掉首尾空白的路径，空串表示清除。
class _DirectoryDialog extends StatefulWidget {
  const _DirectoryDialog({this.initial});

  final String? initial;

  @override
  State<_DirectoryDialog> createState() => _DirectoryDialogState();
}

class _DirectoryDialogState extends State<_DirectoryDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('输入工具链目录'),
    content: TextField(
      key: const ValueKey('environment-directory-field'),
      controller: _controller,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: 3,
      minLines: 1,
      decoration: const InputDecoration(
        labelText: '工具链目录',
        helperText: '留空并确认可清除当前工具链目录。',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}

/// 一键配置的确认对话框：在开始前完整显示 [ToolchainSetupOption.detail]。
class _SetupConfirmDialog extends StatelessWidget {
  const _SetupConfirmDialog({required this.option});

  final ToolchainSetupOption option;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(option.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(option.summary),
        if (option.downloadBytes != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('下载大小：${_formatBytes(option.downloadBytes!)}'),
          ),
        if (option.needsAdministrator)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('这一步需要管理员权限，系统会询问。'),
          ),
        const SizedBox(height: 12),
        SelectableText(
          option.detail,
          key: const ValueKey('environment-setup-detail'),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 12),
        const Text('确认后开始。配置过程中可以取消，取消可能不会立即停止已经开始的步骤。'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('开始配置'),
      ),
    ],
  );
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('已复制')));
}

String _familyLabel(CompilerFamily family) => switch (family) {
  CompilerFamily.clang => 'Clang',
  CompilerFamily.gcc => 'GCC',
};

String _sourceLabel(CompilerSource source) => switch (source) {
  CompilerSource.environmentVariable => '环境变量',
  CompilerSource.configuredDirectory => '工具链目录',
  CompilerSource.managedInstall => '一键配置',
  CompilerSource.knownLocation => '已知位置',
  CompilerSource.systemPath => '系统 PATH',
};

String _preferenceLabel(CompilerPreference preference) => switch (preference) {
  CompilerPreference.automatic => '自动',
  CompilerPreference.clang => 'Clang',
  CompilerPreference.gcc => 'GCC',
};

String _preferenceHint(CompilerPreference preference) => switch (preference) {
  CompilerPreference.automatic => '自动：按查找顺序使用第一个可用的编译器。',
  CompilerPreference.clang => '优先使用 Clang，找不到时仍可使用 GCC。',
  CompilerPreference.gcc => '优先使用 GCC，找不到时仍可使用 Clang。',
};

String _phaseLabel(ToolchainSetupPhase phase) => switch (phase) {
  ToolchainSetupPhase.preparing => '准备',
  ToolchainSetupPhase.downloading => '下载',
  ToolchainSetupPhase.verifying => '校验',
  ToolchainSetupPhase.extracting => '解压',
  ToolchainSetupPhase.running => '执行',
  ToolchainSetupPhase.detecting => '检测',
  ToolchainSetupPhase.done => '完成',
  ToolchainSetupPhase.failed => '失败',
  ToolchainSetupPhase.cancelled => '已取消',
};

/// 人类可读的字节数，例如 `28.6 MB`。
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}
