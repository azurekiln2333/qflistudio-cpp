import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'toolchain_downloader.dart';
import 'toolchain_environment.dart';
import 'toolchain_environment_base.dart';
import 'toolchain_host_info.dart';import 'toolchain_installer_platform.dart';
import 'toolchain_lookup.dart';
import 'toolchain_setup.dart';
import 'toolchain_settings_file.dart';
import 'windows_toolchain_packages.dart';

/// Compiler environment of a desktop computer.
///
/// Owns the settings file, the setup actions and the one candidate list that
/// the environment page and `ClangProgramRunner` share. Every member that
/// touches the file system, a process or the network sits behind a seam, so a
/// test runs without the real storage directory and without a real compiler.
class LocalToolchainEnvironment extends ToolchainEnvironmentBase
    implements ToolchainSetupHost {
  LocalToolchainEnvironment({
    this.host,
    ToolchainSettingsFile? settingsFile,
    ToolchainDownloaderFactory? downloaderFactory,
    ToolchainInstallerPlatform platform = const ToolchainInstallerPlatform(),
    this.projectPath,
  }) : _settingsFile = settingsFile ?? ToolchainSettingsFile(),
       _downloaderFactory = downloaderFactory ?? ToolchainDownloader.new,
       _platform = platform;

  /// Facts of this computer. Null reads them from the platform at first use.
  final ToolchainHostInfo? host;

  /// Base of the relative Dev-Cpp candidates. Null reads the current
  /// directory when a lookup runs.
  final String? projectPath;

  final ToolchainSettingsFile _settingsFile;
  final ToolchainDownloaderFactory _downloaderFactory;
  final ToolchainInstallerPlatform _platform;

  ToolchainSettings _settings = const ToolchainSettings();
  Future<void>? _loading;
  bool _loaded = false;

  List<ToolchainSetup> _setups = const [];
  Future<List<ToolchainSetup>>? _setupInitialization;
  String? _runningOptionId;

  ToolchainHostInfo? _resolvedHost;

  ToolchainHostInfo get _host =>
      _resolvedHost ??= host ?? ToolchainHostInfo.current();

  @override
  bool get supported => _host.isDesktop;

  @override
  ToolchainSettings get settings => _settings;

  /// Stored settings, or null before [load] finished.
  @override
  ToolchainSettings? get storedSettings => _settings;

  /// Toolchain roots of the managed installs, or none.
  @override
  Future<List<String>> get managedRoots async {
    if (!supported || !_host.isWindows) return const [];
    final storage = await storageDirectory();
    if (storage == null) return const [];
    return WindowsArchiveSetup.installedRoots(
      p.join(storage, 'toolchains'),
      isWindows: _host.isWindows,
    );
  }

  @override
  Future<void> load() {
    if (!supported || _loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    _settings = await _settingsFile.read();
    _loaded = true;
  }

  @override
  Future<void> setDirectory(String? directory) async {
    if (!supported) return;
    await load();
    final value = directory?.trim();
    _settings = ToolchainSettings(
      directory: value == null || value.isEmpty ? null : value,
      preference: _settings.preference,
    );
    await _settingsFile.write(_settings);
    notifyListeners();
  }

  @override
  Future<void> setPreference(CompilerPreference preference) async {
    if (!supported) return;
    await load();
    _settings = ToolchainSettings(
      directory: _settings.directory,
      preference: preference,
    );
    await _settingsFile.write(_settings);
    notifyListeners();
  }

  @override
  ToolchainLookup createLookup() => ToolchainLookup(
    isWindows: _host.isWindows,
    environment: _host.environment,
    executableDirectory: _host.executableDirectory,
    // Windows finds `ProgramFiles` from the root of the drive of the current
    // directory, as the lookup did before this class existed.
    projectPath: projectPath ?? Directory.current.path,
  );

  /// Toolchain roots of the managed installs, or none.
  Future<List<String>> installedRoots() async {
    if (!supported || !_host.isWindows) return const [];
    final storage = await storageDirectory();
    if (storage == null) return const [];
    return WindowsArchiveSetup.installedRoots(
      p.join(storage, 'toolchains'),
      isWindows: _host.isWindows,
    );
  }

  /// Storage directory of the application, or null when it has none.
  Future<String?> storageDirectory() => _settingsFile.store.storageDirectory();

  @override
  Future<List<DetectedCompiler>> detect() async {
    if (!supported) return const [];
    await load();
    return createLookup().detect(
      preference: _settings.preference,
      configuredDirectory: _settings.directory,
      managedRoots: await installedRoots(),
    );
  }

  @override
  Future<List<DetectedCompiler>> detectCompilers() => detect();

  @override
  Future<List<ToolchainSetupOption>> setupOptions() async {
    if (!supported) return const [];
    final setups = await _ensureSetups();
    return [for (final setup in setups) setup.option];
  }

  Future<List<ToolchainSetup>> _ensureSetups() async {
    if (_setups.isNotEmpty) return _setups;
    return _setupInitialization ??= _initializeSetups();
  }

  Future<List<ToolchainSetup>> _initializeSetups() async {
    final setups = <ToolchainSetup>[];
    if (_host.isWindows) {
      final storage = await storageDirectory();
      if (storage != null) {
        for (final package in windowsToolchainPackages) {
          setups.add(
            WindowsArchiveSetup(
              this,
              package: package,
              storageDirectory: p.join(storage, 'toolchains'),
              windows: true,
              downloader: _downloaderFactory(),
              platform: _platform,
            ),
          );
        }
      }
    } else if (_host.isLinux) {
      final manager = findExecutable(const [
        'apt-get',
        'dnf',
        'pacman',
        'zypper',
      ]);
      final pkexec = findExecutable(const ['pkexec']);
      for (final family in const [CompilerFamily.clang, CompilerFamily.gcc]) {
        final command = linuxInstallCommand(manager, family);
        setups.add(
          LinuxPackageSetup(
            this,
            packageManager: manager,
            pkexec: pkexec,
            family: family,
            packages: command.packages,
            commandLine: command.commandLine,
            platform: _platform,
          ),
        );
      }
    } else if (_host.isMacOS) {
      setups.add(
        MacCommandLineToolsSetup(
          this,
          xcodeSelect: findExecutable(const ['xcode-select']),
          platform: _platform,
          installed: _host.environment['QFLI_MAC_CLT_INSTALLED'] == '1',
        ),
      );
    }
    for (final setup in setups) {
      await setup.initialize();
    }
    _setups = List<ToolchainSetup>.unmodifiable(setups);
    return _setups;
  }

  /// Absolute path of the first executable of [names] on `PATH`.
  ///
  /// The extensions come from `PATHEXT` on Windows and are empty on POSIX, so
  /// a test can inject the executables of a Linux computer.
  String? findExecutable(List<String> names) {
    final pathValue = _host.environment['PATH'] ?? _host.environment['Path'];
    if (pathValue == null) return null;
    final extensions = executableExtensions();
    for (final name in names) {
      for (final raw in pathValue.split(_host.isWindows ? ';' : ':')) {
        final directory = raw.trim().replaceAll('"', '');
        if (directory.isEmpty) continue;
        for (final extension in extensions) {
          final candidate = p.join(directory, '$name$extension');
          if (File(candidate).existsSync()) return candidate;
        }
      }
    }
    return null;
  }

  /// Extensions that a bare name tries on this computer.
  List<String> executableExtensions() {
    if (!_host.isWindows) return const [''];
    final raw = _host.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD';
    return [
      '',
      for (final value in raw.split(';'))
        if (value.trim().isNotEmpty)
          value.trim().startsWith('.')
              ? value.trim().toLowerCase()
              : '.${value.trim().toLowerCase()}',
    ];
  }

  /// Package names and command line that [manager] installs [family] with.
  static ({List<String> packages, List<String> commandLine})
  linuxInstallCommand(String? manager, CompilerFamily family) {
    final clang = family == CompilerFamily.clang;
    return switch (manager) {
      'apt-get' => (
        packages: clang ? const ['clang'] : const ['gcc', 'g++'],
        commandLine: [
          'install',
          '-y',
          if (clang) 'clang' else ...['gcc', 'g++'],
        ],
      ),
      'dnf' => (
        packages: clang ? const ['clang'] : const ['gcc', 'gcc-c++'],
        commandLine: [
          'install',
          '-y',
          if (clang) 'clang' else ...['gcc', 'gcc-c++'],
        ],
      ),
      'pacman' => (
        packages: clang ? const ['clang'] : const ['gcc'],
        commandLine: [
          '-S',
          '--needed',
          '--noconfirm',
          if (clang) 'clang' else 'gcc',
        ],
      ),
      'zypper' => (
        packages: clang ? const ['clang'] : const ['gcc', 'gcc-c++'],
        commandLine: [
          '--non-interactive',
          'install',
          if (clang) 'clang' else ...['gcc', 'gcc-c++'],
        ],
      ),
      _ => (packages: const <String>[], commandLine: const <String>[]),
    };
  }

  @override
  Stream<ToolchainSetupProgress> runSetup(String optionId) {
    if (!supported) {
      return Stream<ToolchainSetupProgress>.value(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '此平台不支持环境配置。',
        ),
      );
    }
    final controller = StreamController<ToolchainSetupProgress>();
    unawaited(_runSetup(optionId, controller));
    return controller.stream;
  }

  Future<void> _runSetup(
    String optionId,
    StreamController<ToolchainSetupProgress> controller,
  ) async {
    void fail(String message) {
      if (controller.isClosed) return;
      controller.add(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: message,
        ),
      );
      unawaited(controller.close());
    }

    if (_runningOptionId != null) {
      fail('已有一个配置动作在运行，请等待它结束。');
      return;
    }
    final setups = await _ensureSetups();
    final setup = setups.where((setup) => setup.id == optionId).firstOrNull;
    if (setup == null) {
      fail('本平台没有这个配置动作。');
      return;
    }
    _runningOptionId = optionId;
    try {
      await for (final progress in setup.run()) {
        controller.add(progress);
        if (progress.isFinal) break;
      }
    } finally {
      _runningOptionId = null;
      // The installed state of every option depends on the same detect, so a
      // finished action refreshes the page once.
      for (final setup in _setups) {
        await setup.initialize();
      }
      notifyListeners();
      unawaited(controller.close());
    }
  }

  @override
  Future<void> cancelSetup() async {
    final optionId = _runningOptionId;
    if (optionId == null) return;
    for (final setup in _setups) {
      if (setup.id == optionId) await setup.cancel();
    }
  }

  @override
  Future<void> remove(String optionId) async {
    if (!supported) return;
    final setups = await _ensureSetups();
    final setup = setups.where((setup) => setup.id == optionId).firstOrNull;
    if (setup == null || !setup.removable) return;
    await setup.remove();
  }

  @override
  void notifyChanged() => notifyListeners();
}

/// Factory of the downloader, so a test hands over a loopback client factory.
typedef ToolchainDownloaderFactory = ToolchainDownloader Function();

/// The instance that the runner and the environment page share.
///
/// The conditional import of `local_toolchain_environment.dart` shows the web
/// class instead, where `supported` stays false.
final ToolchainEnvironment forgeToolchainEnvironment =
    LocalToolchainEnvironment();
