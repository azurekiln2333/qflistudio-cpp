import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/forge_environment_page.dart';
import 'package:qfli_c/toolchain/toolchain_environment.dart';

/// 完成挂起探测的开关。
class _DetectGate {
  Completer<void>? _pending;

  Future<void> wait() => (_pending ??= Completer<void>()).future;

  void release() {
    _pending?.complete();
    _pending = null;
  }
}

/// 可编程的假环境。真实实现在 `lib/toolchain/local_toolchain_environment.dart`，
/// 本包的工作树里它还是 `supported == false` 的桩，所以页面只对假实现验证。
class _FakeEnvironment extends ChangeNotifier implements ToolchainEnvironment {
  @override
  ToolchainSettings? get storedSettings => settings;

  @override
  Future<List<String>>? get managedRoots => null;
  _FakeEnvironment({
    List<DetectedCompiler> compilers = const [],
    List<ToolchainSetupOption> options = const [],
    this.detectIsManual = false,
  }) : _compilers = List.of(compilers),
       _options = List.of(options);

  /// 页面只在桌面打开，假环境与真实桌面实现一样为 true。
  @override
  bool get supported => true;

  ToolchainSettings _settings = const ToolchainSettings();
  List<DetectedCompiler> _compilers;
  List<ToolchainSetupOption> _options;

  /// 为 true 时 [detect] 等待 [completeDetect]，模拟耗时几十秒的探测。
  final bool detectIsManual;
  final _DetectGate gate = _DetectGate();

  int loadCalls = 0;
  final List<int> detectCalls = [];
  final List<CompilerPreference> preferred = [];
  final List<String?> directories = [];
  final List<String> setupRuns = [];
  final List<String> removed = [];
  int cancelCalls = 0;

  /// 每个动作 id 对应的事件流控制器。
  final Map<String, StreamController<ToolchainSetupProgress>> _streams = {};

  @override
  ToolchainSettings get settings => _settings;

  @override
  Future<void> load() async {
    loadCalls++;
  }

  @override
  Future<void> setDirectory(String? directory) async {
    directories.add(directory);
    _settings = ToolchainSettings(
      directory: directory,
      preference: _settings.preference,
    );
    notifyListeners();
  }

  @override
  Future<void> setPreference(CompilerPreference preference) async {
    preferred.add(preference);
    _settings = ToolchainSettings(
      directory: _settings.directory,
      preference: preference,
    );
    notifyListeners();
  }

  @override
  Future<List<DetectedCompiler>> detect() async {
    detectCalls.add(1);
    if (detectIsManual) {
      final pending = gate.wait();
      await pending;
    }
    return List.of(_compilers);
  }

  /// 完成挂起的探测，并换上新结果。
  void completeDetect(List<DetectedCompiler> compilers) {
    _compilers = List.of(compilers);
    gate.release();
  }

  @override
  Future<List<ToolchainSetupOption>> setupOptions() async => List.of(_options);

  void setOptions(List<ToolchainSetupOption> options) {
    _options = List.of(options);
    notifyListeners();
  }

  @override
  Stream<ToolchainSetupProgress> runSetup(String optionId) {
    setupRuns.add(optionId);
    final controller = StreamController<ToolchainSetupProgress>();
    _streams[optionId] = controller;
    return controller.stream;
  }

  StreamController<ToolchainSetupProgress> streamOf(String optionId) =>
      _streams[optionId]!;

  @override
  Future<void> cancelSetup() async {
    cancelCalls++;
  }

  @override
  Future<void> remove(String optionId) async {
    removed.add(optionId);
    _options = [
      for (final option in _options)
        if (option.id == optionId)
          ToolchainSetupOption(
            id: option.id,
            title: option.title,
            summary: option.summary,
            detail: option.detail,
            installed: false,
          )
        else
          option,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _streams.values) {
      controller.close();
    }
    super.dispose();
  }
}

const _cCompiler = DetectedCompiler(
  language: 'c',
  family: CompilerFamily.clang,
  executable: r'C:\Program Files\LLVM\bin\clang.exe',
  version: 'clang version 19.1.0',
  standard: 'c17',
  source: CompilerSource.environmentVariable,
);

DetectedCompiler _cppCompiler({CompilerSource? source}) => DetectedCompiler(
  language: 'cpp',
  family: CompilerFamily.gcc,
  executable: '/usr/bin/g++',
  version: 'g++ (GCC) 13.2.0',
  standard: 'c++20',
  source: source ?? CompilerSource.systemPath,
);

const _setupOptions = [
  ToolchainSetupOption(
    id: 'llvm-mingw',
    title: '安装 Clang（LLVM-MinGW）',
    summary: '下载并解压 Clang 工具链',
    detail: 'https://example.invalid/llvm-mingw.zip 解压到 应用数据目录/toolchains',
    downloadBytes: 28 * 1024 * 1024,
  ),
  ToolchainSetupOption(
    id: 'gcc-ucrt',
    title: '安装 GCC',
    summary: '下载并解压 GCC 工具链',
    detail: r'%SystemRoot%\System32\tar.exe -xf gcc.zip',
    needsAdministrator: true,
    installed: true,
    removable: true,
  ),
  ToolchainSetupOption(
    id: 'gcc-only',
    title: '安装 GCC（不可移除）',
    summary: '系统软件包',
    detail: 'pkexec apt-get install -y gcc g++',
    installed: true,
  ),
];

void main() {
  late String? copied;

  Future<_FakeEnvironment> pumpPage(
    WidgetTester tester, {
    _FakeEnvironment? environment,
    Future<String?> Function()? pickDirectory,
    TextScaler textScaler = TextScaler.noScaling,
    Size size = const Size(1000, 2400),
    bool settle = true,
  }) async {
    final fake = environment ?? _FakeEnvironment();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: ForgeEnvironmentPage(
          environment: fake,
          pickDirectory: pickDirectory,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return fake;
  }

  void mockClipboard(WidgetTester tester) {
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
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(
      tester.element(target),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pump();
  }

  /// 推进一帧，不等动画结束（运行中的动作会持续绘制进度条）。
  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await show(tester, target);
    await tester.tap(target);
    await pump(tester);
  }

  group('current compiler', () {
    testWidgets(
      'a pending detection shows progress and keeps the page usable',
      (tester) async {
        final fake = _FakeEnvironment(
          detectIsManual: true,
          options: _setupOptions,
        );
        await pumpPage(tester, environment: fake, settle: false);

        expect(fake.loadCalls, 1);
        expect(fake.detectCalls, hasLength(1));
        expect(find.byKey(const ValueKey('environment-detecting')), findsOne);
        expect(find.text('正在检测编译器…'), findsOne);

        fake.completeDetect([_cCompiler, _cppCompiler()]);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('environment-detecting')),
          findsNothing,
        );
        expect(find.text('Clang · c17'), findsOne);
        expect(find.text('clang version 19.1.0'), findsOne);
        expect(find.text(r'C:\Program Files\LLVM\bin\clang.exe'), findsOne);
        expect(find.text('环境变量'), findsOne);
        expect(find.text('GCC · c++20'), findsOne);
        expect(find.text('g++ (GCC) 13.2.0'), findsOne);
        expect(find.text('/usr/bin/g++'), findsOne);
        expect(find.text('系统 PATH'), findsOne);
      },
    );

    testWidgets('a language without a compiler shows the empty state', (
      tester,
    ) async {
      await pumpPage(
        tester,
        environment: _FakeEnvironment(compilers: [_cCompiler]),
      );
      expect(find.text('Clang · c17'), findsOne);
      expect(find.textContaining('C++：没有找到编译器'), findsOne);
      expect(find.textContaining('「一键配置」'), findsWidgets);
    });

    testWidgets('the first entry is the compiler in use, others collapse', (
      tester,
    ) async {
      await pumpPage(
        tester,
        environment: _FakeEnvironment(
          compilers: [
            _cCompiler,
            const DetectedCompiler(
              language: 'c',
              family: CompilerFamily.gcc,
              executable: 'gcc',
              version: 'gcc (GCC) 13.2.0',
              standard: 'c17',
              source: CompilerSource.systemPath,
            ),
          ],
        ),
      );
      expect(find.text('C（在用）'), findsOne);
      expect(find.text('另外找到 1 个'), findsOne);
      expect(find.text('gcc (GCC) 13.2.0'), findsNothing);

      await tap(tester, find.text('另外找到 1 个'));
      expect(find.text('gcc (GCC) 13.2.0'), findsOne);
    });

    testWidgets('重新检测 runs a new detection', (tester) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(compilers: [_cCompiler]),
      );
      expect(fake.detectCalls, hasLength(1));
      await tap(tester, find.byKey(const ValueKey('environment-redetect')));
      expect(fake.detectCalls, hasLength(2));
      expect(find.text('重新检测完成：C Clang, C++ 无。'), findsOne);
    });
  });

  group('preference', () {
    testWidgets('each choice calls setPreference once and detects again', (
      tester,
    ) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(compilers: [_cCompiler]),
      );
      expect(fake.detectCalls, hasLength(1));

      await tap(
        tester,
        find.byKey(const ValueKey('environment-preference-clang')),
      );
      expect(fake.preferred, [CompilerPreference.clang]);
      expect(fake.detectCalls.length, greaterThanOrEqualTo(2));

      // 环境在动作完成后自行通知，页面至少再检测一次。
      fake.preferred.clear();
      final callsBefore = fake.detectCalls.length;
      await tap(
        tester,
        find.byKey(const ValueKey('environment-preference-gcc')),
      );
      expect(fake.preferred, [CompilerPreference.gcc]);
      expect(fake.detectCalls.length, greaterThan(callsBefore));

      // 当前选择不再接受点击，其余保持可用。
      final current = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('environment-preference-gcc')),
      );
      expect(current.selected, isTrue);
      expect(current.onSelected, isNull);
      final automatic = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('environment-preference-automatic')),
      );
      expect(automatic.selected, isFalse);
      expect(automatic.onSelected, isNotNull);
    });
  });

  group('toolchain directory', () {
    testWidgets('the chooser result reaches setDirectory and is reported', (
      tester,
    ) async {
      var picks = 0;
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(compilers: [_cCompiler]),
        pickDirectory: () async {
          picks++;
          return r'D:\toolchains\llvm';
        },
      );

      await tap(
        tester,
        find.byKey(const ValueKey('environment-directory-pick')),
      );
      expect(picks, 1);
      expect(fake.directories, [r'D:\toolchains\llvm']);
      expect(find.text('这个工具链目录中没有找到编译器。目录里需要有 bin/ 子目录。'), findsOne);

      // 目录给出的编译器被识别后，页面说明目录可用。
      fake.completeDetect([
        _cCompiler,
        _cppCompiler(source: CompilerSource.configuredDirectory),
      ]);
      await tap(
        tester,
        find.byKey(const ValueKey('environment-directory-pick')),
      );
      expect(find.text('此工具链目录可用：GCC /usr/bin/g++'), findsOne);
    });

    testWidgets('a typed path reaches setDirectory and clear passes null', (
      tester,
    ) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(compilers: [_cCompiler]),
      );

      final clear = find.byKey(const ValueKey('environment-directory-clear'));
      expect(tester.widget<OutlinedButton>(clear).onPressed, isNull);

      await tap(
        tester,
        find.byKey(const ValueKey('environment-directory-edit')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('environment-directory-field')),
        '  /opt/llvm  ',
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(fake.directories, ['/opt/llvm']);
      expect(find.text('/opt/llvm'), findsOne);
      expect(tester.widget<OutlinedButton>(clear).onPressed, isNotNull);

      await tap(tester, clear);
      expect(fake.directories, ['/opt/llvm', null]);
      expect(find.text('已清除工具链目录。'), findsOne);
      expect(find.text('未选择工具链目录'), findsOne);
    });
  });

  group('one-click setup', () {
    testWidgets(
      'the dialog shows the detail and a declined dialog runs nothing',
      (tester) async {
        final fake = await pumpPage(
          tester,
          environment: _FakeEnvironment(
            compilers: [_cCompiler],
            options: _setupOptions,
          ),
        );
        await show(
          tester,
          find.byKey(const ValueKey('environment-setup-llvm-mingw')),
        );
        expect(find.textContaining('28.0 MB'), findsWidgets);
        expect(find.textContaining('需要管理员权限'), findsOne);
        expect(find.textContaining('已安装'), findsWidgets);

        await tap(
          tester,
          find.byKey(const ValueKey('environment-setup-llvm-mingw')),
        );
        expect(
          find.text(
            'https://example.invalid/llvm-mingw.zip 解压到 应用数据目录/toolchains',
          ),
          findsOne,
        );
        expect(find.text('下载大小：28.0 MB'), findsOne);
        expect(find.textContaining('管理员权限'), findsWidgets);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(fake.setupRuns, isEmpty);
        expect(
          find.byKey(const ValueKey('environment-setup-progress')),
          findsNothing,
        );
      },
    );

    testWidgets('progress events update the bar and the log, 取消 cancels', (
      tester,
    ) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(
          compilers: [_cCompiler],
          options: _setupOptions,
        ),
      );

      await tap(
        tester,
        find.byKey(const ValueKey('environment-setup-llvm-mingw')),
      );
      await tester.tap(find.text('开始配置'));
      await pump(tester);
      expect(fake.setupRuns, ['llvm-mingw']);

      // 运行中其他选项不可用。
      final other = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('environment-setup-gcc-ucrt')),
          matching: find.byType(ListTile),
        ),
      );
      expect(other.onTap, isNull);
      expect(other.enabled, isFalse);

      final events = fake.streamOf('llvm-mingw');
      events.add(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.downloading,
          message: '正在下载 llvm-mingw.zip',
          received: 512,
          total: 1024,
        ),
      );
      await pump(tester);
      await show(tester, find.byKey(const ValueKey('environment-setup-phase')));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('environment-setup-bar')),
            )
            .value,
        0.5,
      );
      expect(find.text('512 B / 1.0 KB'), findsOne);
      expect(find.text('正在下载 llvm-mingw.zip'), findsOne);
      expect(find.textContaining('下载'), findsWidgets);

      events.add(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.extracting,
          message: '正在解压',
        ),
      );
      await pump(tester);
      expect(find.text('安装 Clang（LLVM-MinGW） · 解压'), findsOne);
      expect(find.text('正在解压'), findsOne);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('environment-setup-bar')),
            )
            .value,
        isNull,
      );

      await tap(tester, find.byKey(const ValueKey('environment-setup-cancel')));
      expect(fake.cancelCalls, 1);
      expect(find.text('正在取消'), findsOne);

      events.add(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.cancelled,
          message: '已取消',
        ),
      );
      await pump(tester);
      expect(find.text('安装 Clang（LLVM-MinGW） · 已取消'), findsOne);
      expect(
        find.byKey(const ValueKey('environment-setup-cancel')),
        findsNothing,
      );
      await tap(tester, find.byKey(const ValueKey('environment-setup-close')));
      await pump(tester);
      expect(
        find.byKey(const ValueKey('environment-setup-progress')),
        findsNothing,
      );
    });

    testWidgets('done detects again and shows the result', (tester) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(
          compilers: [_cCompiler],
          options: _setupOptions,
        ),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('environment-setup-llvm-mingw')),
      );
      await tester.tap(find.text('开始配置'));
      await pump(tester);

      fake.completeDetect([
        const DetectedCompiler(
          language: 'c',
          family: CompilerFamily.clang,
          executable: 'C:/App/toolchains/clang/bin/clang.exe',
          version: 'clang version 19.1.0',
          standard: 'c17',
          source: CompilerSource.managedInstall,
        ),
        _cppCompiler(source: CompilerSource.managedInstall),
      ]);
      fake
          .streamOf('llvm-mingw')
          .add(
            const ToolchainSetupProgress(
              phase: ToolchainSetupPhase.done,
              message: '完成',
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('一键配置'), findsWidgets);
      expect(find.text('C:/App/toolchains/clang/bin/clang.exe'), findsOne);
    });

    testWidgets('failed shows the message', (tester) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(
          compilers: [_cCompiler],
          options: _setupOptions,
        ),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('environment-setup-llvm-mingw')),
      );
      await tester.tap(find.text('开始配置'));
      await pump(tester);

      fake
          .streamOf('llvm-mingw')
          .add(
            const ToolchainSetupProgress(
              phase: ToolchainSetupPhase.failed,
              message: 'SHA-256 校验失败',
            ),
          );
      await tester.pumpAndSettle();
      await show(
        tester,
        find.byKey(const ValueKey('environment-setup-progress')),
      );

      expect(find.text('安装 Clang（LLVM-MinGW） · 失败'), findsOne);
      expect(find.text('SHA-256 校验失败'), findsOne);
      expect(
        find.byKey(const ValueKey('environment-setup-cancel')),
        findsNothing,
      );
    });

    testWidgets('an empty list states the manual way', (tester) async {
      await pumpPage(tester, environment: _FakeEnvironment());
      expect(find.text('当前平台没有可用的一键配置。请手动安装编译器，然后在上方选择工具链目录。'), findsOne);
    });
  });

  group('remove', () {
    testWidgets('only a removable installed option offers 移除', (tester) async {
      final fake = await pumpPage(
        tester,
        environment: _FakeEnvironment(
          compilers: [_cCompiler],
          options: _setupOptions,
        ),
      );
      expect(
        find.byKey(const ValueKey('environment-remove-llvm-mingw')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('environment-remove-gcc-only')),
        findsNothing,
      );

      final remove = find.byKey(const ValueKey('environment-remove-gcc-ucrt'));
      expect(remove, findsOne);
      await tap(tester, remove);
      expect(find.text('移除 安装 GCC'), findsOne);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(fake.removed, isEmpty);

      await tap(tester, remove);
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pumpAndSettle();
      expect(fake.removed, ['gcc-ucrt']);
      expect(
        find.byKey(const ValueKey('environment-remove-gcc-ucrt')),
        findsNothing,
      );
    });
  });

  testWidgets('the page rebuilds when the environment notifies', (
    tester,
  ) async {
    final fake = await pumpPage(tester, environment: _FakeEnvironment());
    expect(find.text('未选择工具链目录'), findsOne);

    await fake.setDirectory('/opt/toolchain');
    await tester.pumpAndSettle();

    expect(fake.detectCalls.length, greaterThan(1));
    expect(find.text('/opt/toolchain'), findsOne);
  });

  group('layout', () {
    testWidgets('a narrow window, large text and a long path do not overflow', (
      tester,
    ) async {
      mockClipboard(tester);
      final longPath =
          r'C:\Users\Someone\AppData\Local\QFLIForge\toolchains\'
          '${'deep-directory/' * 10}bin\\clang.exe';
      final long = DetectedCompiler(
        language: 'c',
        family: CompilerFamily.clang,
        executable: longPath,
        version: 'clang version 19.1.0 (a very long release string)',
        standard: 'c17',
        source: CompilerSource.managedInstall,
      );
      final fake = _FakeEnvironment(
        detectIsManual: true,
        compilers: [long, _cppCompiler()],
        options: _setupOptions,
      );
      await pumpPage(
        tester,
        environment: fake,
        textScaler: const TextScaler.linear(1.5),
        size: const Size(360, 800),
        settle: false,
      );
      fake.completeDetect([long, _cppCompiler()]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(long.executable.length, greaterThan(100));

      await show(tester, find.text('一键配置'));
      await tap(tester, find.byTooltip('复制路径').first);
      expect(copied, longPath);

      await fake.setDirectory(longPath);
      await pump(tester);
      await show(
        tester,
        find.byKey(const ValueKey('environment-directory-value')),
      );
      await tap(tester, find.byTooltip('复制工具链目录'));
      expect(copied, longPath);
      expect(tester.takeException(), isNull);
    });
  });
}
