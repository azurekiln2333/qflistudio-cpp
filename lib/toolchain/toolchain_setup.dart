import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'toolchain_downloader.dart';
import 'toolchain_environment.dart';
import 'toolchain_installer_platform.dart';
import 'toolchain_lookup.dart';
import 'windows_toolchain_packages.dart';

/// Receives progress of one setup action.
typedef ToolchainProgressSink = void Function(ToolchainSetupProgress progress);

/// What a setup action may ask of the environment that owns it.
///
/// The setup object never touches the settings file, never starts a second
/// action and never reports to a page directly.
abstract class ToolchainSetupHost {
  /// Settings that the lookup reads.
  ToolchainSettings get settings;

  /// Listeners to notify after the installed toolchains changed.
  void notifyChanged();

  /// Probe used by the `detecting` step.
  Future<List<DetectedCompiler>> detectCompilers();

  /// The lookup of the shared candidate list.
  ToolchainLookup createLookup();
}

/// One setup action of the current platform.
///
/// Windows downloads a pinned archive and unpacks it. Linux runs the package
/// manager through `pkexec`. macOS opens the command-line-tools installer. No
/// subclass writes beside an executable, changes `PATH`, the registry or a
/// shell profile.
abstract class ToolchainSetup {
  ToolchainSetup(this.host);

  final ToolchainSetupHost host;

  /// Option id, for example `windows-llvm-mingw`.
  String get id;

  /// True once [initialize] ran.
  bool get ready;

  /// Reads the installed state. Called before [options] and before [run].
  Future<void> initialize();

  /// Option of this action for the page.
  ToolchainSetupOption get option;

  /// True when [remove] can delete the result of this action.
  bool get removable;

  /// Runs the action and reports progress. The first final event ends it.
  Stream<ToolchainSetupProgress> run();

  /// Stops [run]. Does nothing when none runs.
  Future<void> cancel();

  /// Deletes the installed directory. Notifies the listeners when it existed.
  Future<void> remove();
}

/// Downloads one pinned Windows archive and unpacks it into the storage
/// directory.
///
/// Flow: download to `<archive>.part` → compare size and SHA-256 → unpack into
/// a temporary directory beside the target → rename to the final directory →
/// write the marker → `detecting` → `done`. A failure or a cancel in any step
/// leaves a directory that [readInstalledRoot] still finds.
class WindowsArchiveSetup extends ToolchainSetup {
  WindowsArchiveSetup(
    super.host, {
    required this.package,
    required this.storageDirectory,
    required this.windows,
    required this.downloader,
    required this.platform,
  });

  final WindowsToolchainPackage package;

  /// Root of the managed toolchains: `<storage>/toolchains`.
  final String storageDirectory;

  final bool windows;
  final ToolchainDownloader downloader;
  final ToolchainInstallerPlatform platform;

  /// Directory that holds the unpacked toolchain, under [storageDirectory].
  String get targetDirectory => p.join(storageDirectory, package.optionId);

  /// Archive of this action. Kept in a temporary directory, because a second
  /// action must not reuse an archive of another toolchain.
  String get archiveDirectory => p.join(storageDirectory, '.cache');

  bool _ready = false;
  bool _installed = false;
  bool _cancelRequested = false;
  bool _running = false;

  @override
  String get id => package.optionId;

  @override
  bool get ready => _ready;

  @override
  bool get removable => _installed;

  @override
  ToolchainSetupOption get option => ToolchainSetupOption(
    id: id,
    title: package.title,
    summary: package.summary,
    detail:
        '下载地址：${package.url}\n'
        '下载大小：${formatBytes(package.bytes)}（${package.bytes} 字节）\n'
        '校验值：SHA-256 ${package.sha256}\n'
        '安装目录：$targetDirectory\n'
        '解压后约 ${formatBytes(_estimatedDiskBytes)}，不修改系统 PATH。',
    downloadBytes: package.bytes,
    needsAdministrator: false,
    installed: _installed,
    // The runner puts `<toolchain>/bin` on the PATH of the child, so the DLLs
    // of the toolchain stay inside its own directory. Removing the directory
    // therefore breaks no other program.
    removable: _installed,
  );

  /// Unpacked size. A measured value, or the archive size times three when
  /// nobody measured it.
  int get _estimatedDiskBytes => _measuredDiskBytes ?? package.bytes * 3;
  int? _measuredDiskBytes;

  /// Sets the measured unpacked size for [detail] and for the disk check.
  void debugSetDiskBytes(int? bytes) => _measuredDiskBytes = bytes;

  @override
  Future<void> initialize() async {
    _installed =
        await readInstalledRoot(
          storageDirectory,
          package: package,
          isWindows: windows,
        ) !=
        null;
    _ready = true;
  }

  /// Toolchain root of [package] under [storageDirectory], or null when its
  /// compiler is absent.
  static Future<String?> readInstalledRoot(
    String storageDirectory, {
    required WindowsToolchainPackage package,
    required bool isWindows,
  }) async {
    final root = package.rootUnder(p.join(storageDirectory, package.optionId));
    final compiler = p.join(
      root,
      'bin',
      isWindows ? package.compilerFile : package.compilerFile,
    );
    return await FileSystemEntity.type(compiler) == FileSystemEntityType.file
        ? root
        : null;
  }

  /// Managed roots of every option that [readInstalledRoot] reports.
  static Future<List<String>> installedRoots(
    String storageDirectory, {
    required bool isWindows,
  }) async => [
    for (final package in windowsToolchainPackages)
      if (await readInstalledRoot(
            storageDirectory,
            package: package,
            isWindows: isWindows,
          )
          case final String root)
        root,
  ];

  @override
  Stream<ToolchainSetupProgress> run() {
    if (_running) {
      return Stream<ToolchainSetupProgress>.value(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '已有一个配置动作在运行，请等待它结束。',
        ),
      );
    }
    _running = true;
    _cancelRequested = false;
    final controller = StreamController<ToolchainSetupProgress>();
    unawaited(_execute(controller));
    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    if (!_running) return;
    _cancelRequested = true;
    await downloader.cancel();
  }

  @override
  Future<void> remove() async {
    if (_running) {
      throw const ToolchainCommandException(
        command: 'remove',
        code: -1,
        output: '配置动作正在运行，请先取消。',
      );
    }
    await _deleteIfPresent(Directory(targetDirectory));
    await _deleteIfPresent(Directory(archiveDirectory));
    _installed = false;
    host.notifyChanged();
  }

  Future<void> _execute(
    StreamController<ToolchainSetupProgress> controller,
  ) async {
    void report(ToolchainSetupProgress progress) {
      if (!controller.isClosed) controller.add(progress);
    }

    String? temporary;
    var targetWasReplaced = false;
    try {
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.preparing,
          message: '正在准备下载。',
        ),
      );
      if (!windows) {
        throw const ToolchainCommandException(
          command: 'setup',
          code: -1,
          output: '该动作只在 Windows 上可用。',
        );
      }
      final space = await platform.diskSpace(storageDirectory);
      if (!space.fits(_estimatedDiskBytes)) {
        throw ToolchainCommandException(
          command: 'disk check',
          code: -1,
          output:
              '磁盘剩余 ${formatBytes(space.freeBytes ?? 0)}，'
              '需要 ${formatBytes(_estimatedDiskBytes)}。',
        );
      }
      final archive = p.join(archiveDirectory, p.basename(package.url));
      await Directory(archiveDirectory).create(recursive: true);
      final partFile = File('$archive.part');
      final received = await partFile.exists() ? await partFile.length() : 0;
      // A `.part` file from an earlier attempt is only useful when the server
      // answers a range request. The size and the SHA-256 below still decide.
      final resume = received > 0 && received < package.bytes ? received : 0;
      var lastMegabyte = -1;
      downloader.onReceived = (bytes) {
        final megabyte = bytes ~/ (1 << 20);
        // One message per MiB keeps a page smooth on a slow line.
        if (megabyte == lastMegabyte) return;
        lastMegabyte = megabyte;
        report(
          ToolchainSetupProgress(
            phase: ToolchainSetupPhase.downloading,
            message:
                '正在下载：${formatBytes(bytes)} / ${formatBytes(package.bytes)}',
            received: bytes,
            total: package.bytes,
          ),
        );
      };
      await downloader.download(
        package.url,
        File(archive),
        cancel: () => _cancelRequested,
        offset: resume,
      );
      downloader.onReceived = null;
      _throwIfCancelled();
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.verifying,
          message: '正在校验大小和 SHA-256。',
        ),
      );
      await _verify(File(archive));
      _throwIfCancelled();
      temporary =
          '$targetDirectory.unpacking'
          '-${DateTime.now().microsecondsSinceEpoch}';
      await _deleteIfPresent(Directory(temporary));
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.extracting,
          message: '正在解压到 $targetDirectory',
        ),
      );
      await platform.extractZip(
        archive,
        temporary,
        onLine: (line) => report(
          ToolchainSetupProgress(
            phase: ToolchainSetupPhase.extracting,
            message: line,
          ),
        ),
      );
      _throwIfCancelled();
      final unpacked = package.rootUnder(temporary);
      final compiler = p.join(unpacked, 'bin', package.compilerFile);
      if (await FileSystemEntity.type(compiler) != FileSystemEntityType.file) {
        throw ToolchainCommandException(
          command: 'archive check',
          code: -1,
          output: '压缩包中没有 ${package.compilerFile}，已停止安装。',
        );
      }
      // Keep the archive root below the managed option directory.
      // `readInstalledRoot` and the lookup both resolve `targetDirectory`
      // through `package.archiveRoot`, so moving only the inner directory
      // would make every non-empty archive root undiscoverable.
      await _deleteIfPresent(Directory(targetDirectory));
      targetWasReplaced = true;
      await Directory(temporary).rename(targetDirectory);
      await _deleteIfPresent(Directory(temporary));
      temporary = null;
      await _deleteIfPresent(File(archive));
      await File(
        p.join(targetDirectory, _markerName),
      ).writeAsString(_markerContent, flush: true);
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.detecting,
          message: '正在检测编译器。',
        ),
      );
      final detected = await host.detectCompilers();
      final usable = detected.where(
        (compiler) => p.isWithin(targetDirectory, compiler.executable),
      );
      if (usable.isEmpty) {
        throw const ToolchainCommandException(
          command: 'detect',
          code: -1,
          output: '安装完成，但没有找到可用的编译器。',
        );
      }
      _installed = true;
      host.notifyChanged();
      final first = usable.first;
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.done,
          message: first.version.isEmpty
              ? '已安装 ${package.title}：${first.executable}'
              : '已安装 ${package.title}：${first.version}',
        ),
      );
    } on ToolchainDownloadException catch (error) {
      await _deleteIfPresent(temporary == null ? null : Directory(temporary));
      if (targetWasReplaced) await _deleteIfPresent(Directory(targetDirectory));
      report(
        ToolchainSetupProgress(
          phase: error.cancelled
              ? ToolchainSetupPhase.cancelled
              : ToolchainSetupPhase.failed,
          message: error.cancelled ? '已取消。未安装任何工具链。' : error.message,
        ),
      );
    } on ToolchainCommandException catch (error) {
      await _deleteIfPresent(temporary == null ? null : Directory(temporary));
      if (targetWasReplaced) await _deleteIfPresent(Directory(targetDirectory));
      report(
        ToolchainSetupProgress(
          phase: _cancelRequested
              ? ToolchainSetupPhase.cancelled
              : ToolchainSetupPhase.failed,
          message: error.message,
        ),
      );
    } on FileSystemException catch (error) {
      await _deleteIfPresent(temporary == null ? null : Directory(temporary));
      if (targetWasReplaced) await _deleteIfPresent(Directory(targetDirectory));
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '文件操作失败：${error.message}',
        ),
      );
    } finally {
      downloader.onReceived = null;
      _running = false;
      if (!controller.isClosed) unawaited(controller.close());
    }
  }

  /// Adds the `_throwIfCancelled` helper used by the steps below.
  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const ToolchainDownloadException('已取消。', cancelled: true);
    }
  }

  Future<void> _verify(File archive) async {
    final length = await archive.length();
    if (length != package.bytes) {
      await _deleteIfPresent(archive);
      await _deleteIfPresent(File('${archive.path}.part'));
      throw ToolchainCommandException(
        command: 'sha256',
        code: -1,
        output: '压缩包大小不对：收到 $length 字节，应为 ${package.bytes} 字节。',
      );
    }
    final digest = await sha256.bind(archive.openRead()).first;
    if (digest.toString() != package.sha256) {
      await _deleteIfPresent(archive);
      await _deleteIfPresent(File('${archive.path}.part'));
      throw ToolchainCommandException(
        command: 'sha256',
        code: -1,
        output: '压缩包校验失败：SHA-256 不一致，已删除。',
      );
    }
  }

  static Future<void> _deleteIfPresent(FileSystemEntity? entity) async {
    if (entity == null) return;
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } on FileSystemException {
      // A directory that is already gone needs no second removal.
    }
  }

  static const String _markerName = '.qfli-managed-toolchain';
  static const String _markerContent =
      '本目录由 QFLIForge 的「环境配置」创建。删除它即可移除这套工具链。\n';
}

/// Format of a byte count for the page, for example `151.6 MiB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KiB', 'MiB', 'GiB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// A Linux package option, run through `pkexec`.
class LinuxPackageSetup extends ToolchainSetup {
  LinuxPackageSetup(
    super.host, {
    required this.packageManager,
    required this.pkexec,
    required this.family,
    required this.packages,
    required this.platform,
    required this.commandLine,
  });

  /// `apt-get`, `dnf`, `pacman` or `zypper`. Null when none was found.
  final String? packageManager;

  /// Absolute path of `pkexec`, or null when the computer has none.
  final String? pkexec;

  /// Compiler family that the option installs.
  final CompilerFamily family;

  /// Package names, in the order of [commandLine].
  final List<String> packages;

  final ToolchainInstallerPlatform platform;

  /// Exact command, without `pkexec`.
  final List<String> commandLine;

  bool _ready = false;
  bool _installed = false;
  bool _running = false;
  bool _cancelRequested = false;

  /// True when the action can run at all.
  bool get runnable => packageManager != null && pkexec != null;

  @override
  String get id => 'linux-${family.name}';

  @override
  bool get ready => _ready;

  @override
  bool get removable => false;

  @override
  ToolchainSetupOption get option => ToolchainSetupOption(
    id: id,
    title: family == CompilerFamily.clang ? 'Clang' : 'GCC',
    summary: runnable
        ? '用管理员权限安装 ${packages.join(' ')}，安装后重新检测。'
        : '未找到可用的包管理器或 pkexec，无法自动安装。',
    detail: runnable
        ? '命令：$pkexec ${ToolchainInstallerPlatform.commandLine(packageManager!, commandLine)}\n'
              '需要管理员密码，安装到系统目录。'
        : '需要 ${packageManager ?? 'apt-get、dnf、pacman 或 zypper'} 和 pkexec。'
              '请在终端手动安装 ${packages.join(' ')}。',
    downloadBytes: null,
    needsAdministrator: true,
    installed: _installed,
    removable: false,
  );

  @override
  Future<void> initialize() async {
    final detected = await host.detectCompilers();
    _installed = detected.any((compiler) => compiler.family == family);
    _ready = true;
  }

  @override
  Stream<ToolchainSetupProgress> run() {
    if (!runnable) {
      return Stream<ToolchainSetupProgress>.value(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: option.detail,
        ),
      );
    }
    if (_running) {
      return Stream<ToolchainSetupProgress>.value(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '已有一个配置动作在运行，请等待它结束。',
        ),
      );
    }
    _running = true;
    _cancelRequested = false;
    final controller = StreamController<ToolchainSetupProgress>();
    unawaited(_execute(controller));
    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    if (!_running) return;
    _cancelRequested = true;
  }

  @override
  Future<void> remove() async {}

  Future<void> _execute(
    StreamController<ToolchainSetupProgress> controller,
  ) async {
    void report(ToolchainSetupProgress progress) {
      if (!controller.isClosed) controller.add(progress);
    }

    try {
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.running,
          message: '正在运行：${pkexec!} ${commandLine.join(' ')}',
        ),
      );
      await platform.run(
        pkexec!,
        commandLine,
        onLine: (line) => report(
          ToolchainSetupProgress(
            phase: ToolchainSetupPhase.running,
            message: line,
          ),
        ),
      );
      if (_cancelRequested) {
        report(
          const ToolchainSetupProgress(
            phase: ToolchainSetupPhase.cancelled,
            message: '已取消。',
          ),
        );
        return;
      }
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.detecting,
          message: '正在检测编译器。',
        ),
      );
      final detected = await host.detectCompilers();
      _installed = detected.any((compiler) => compiler.family == family);
      report(
        _installed
            ? ToolchainSetupProgress(
                phase: ToolchainSetupPhase.done,
                message: '已安装 ${packages.join(' ')}。',
              )
            : const ToolchainSetupProgress(
                phase: ToolchainSetupPhase.failed,
                message: '包已安装，但没有在 PATH 中找到该编译器。',
              ),
      );
    } on ToolchainCommandException catch (error) {
      report(
        ToolchainSetupProgress(
          phase: _cancelRequested
              ? ToolchainSetupPhase.cancelled
              : ToolchainSetupPhase.failed,
          message: error.message,
        ),
      );
    } finally {
      _running = false;
      if (!controller.isClosed) unawaited(controller.close());
    }
  }
}

/// The command-line-tools installer of macOS.
///
/// `xcode-select --install` opens a system dialog and returns at once, so the
/// action reports that the user has to finish the dialog and hints at a
/// second detect.
class MacCommandLineToolsSetup extends ToolchainSetup {
  MacCommandLineToolsSetup(
    super.host, {
    required this.xcodeSelect,
    required this.platform,
    bool installed = false,
  }) : _installed = installed;
  final String? xcodeSelect;
  final ToolchainInstallerPlatform platform;

  bool _installed;
  bool _running = false;
  bool _ready = false;

  @override
  String get id => 'macos-command-line-tools';

  @override
  bool get ready => _ready;

  @override
  bool get removable => false;

  @override
  ToolchainSetupOption get option => ToolchainSetupOption(
    id: id,
    title: 'Xcode 命令行工具',
    summary: '安装 Apple 的 Clang 和系统头文件。',
    detail: xcodeSelect == null
        ? '未找到 xcode-select，无法启动安装。'
        : '命令：$xcodeSelect --install\n'
              '系统会打开一个对话框，请在对话框中完成安装，然后点「重新检测」。',
    needsAdministrator: false,
    installed: _installed,
    removable: false,
  );

  @override
  Future<void> initialize() async {
    _ready = true;
  }

  @override
  Stream<ToolchainSetupProgress> run() {
    if (xcodeSelect == null) {
      return Stream<ToolchainSetupProgress>.value(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '未找到 xcode-select。',
        ),
      );
    }
    if (_running) {
      return Stream<ToolchainSetupProgress>.value(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: '已有一个配置动作在运行，请等待它结束。',
        ),
      );
    }
    _running = true;
    final controller = StreamController<ToolchainSetupProgress>();
    unawaited(_execute(controller));
    return controller.stream;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> remove() async {}

  Future<void> _execute(
    StreamController<ToolchainSetupProgress> controller,
  ) async {
    void report(ToolchainSetupProgress progress) {
      if (!controller.isClosed) controller.add(progress);
    }

    try {
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.running,
          message: '已打开安装对话框：$xcodeSelect --install',
        ),
      );
      await platform.launch(xcodeSelect!, const ['--install']);
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.running,
          message: '请在系统对话框中点「安装」并等待它结束，然后点「重新检测」。',
        ),
      );
      report(
        const ToolchainSetupProgress(
          phase: ToolchainSetupPhase.detecting,
          message: '正在检测编译器。',
        ),
      );
      final detected = await host.detectCompilers();
      _installed = detected.any(
        (compiler) => compiler.family == CompilerFamily.clang,
      );
      report(
        ToolchainSetupProgress(
          phase: _installed
              ? ToolchainSetupPhase.done
              : ToolchainSetupPhase.failed,
          message: _installed
              ? '已找到 Apple Clang。'
              : '对话框还在进行或已取消。完成安装后点「重新检测」。',
        ),
      );
    } on ToolchainCommandException catch (error) {
      report(
        ToolchainSetupProgress(
          phase: ToolchainSetupPhase.failed,
          message: error.message,
        ),
      );
    } finally {
      _running = false;
      if (!controller.isClosed) unawaited(controller.close());
    }
  }
}
