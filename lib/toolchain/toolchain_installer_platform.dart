import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Thrown when a command or an archive step of a setup action fails.
class ToolchainCommandException implements Exception {
  const ToolchainCommandException({
    required this.command,
    required this.code,
    this.output = '',
  });

  /// Exact command line.
  final String command;

  final int code;

  /// Output of the command, or the reason of an archive failure.
  final String output;

  /// Short Chinese reason for the page. Empty lines are skipped, so a trailing
  /// newline cannot hide the real reason.
  String get message {
    final last = output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .lastWhere((line) => line.isNotEmpty, orElse: () => '');
    return last.isEmpty
        ? '命令失败（退出码 $code）：$command'
        : '命令失败（退出码 $code）：$last';
  }

  @override
  String toString() => message;
}

/// Free space of the volume that holds the storage directory.
class DiskSpace {
  const DiskSpace({this.freeBytes});

  /// Free bytes. Null when the volume reports no size.
  final int? freeBytes;

  /// True when [needed] bytes fit.
  ///
  /// An unmeasurable volume does not block the action. A guess must not stop a
  /// user whose disk has room, and a download that runs out of space fails on
  /// its own.
  bool fits(int needed) => freeBytes == null || freeBytes! >= needed;
}

/// One finished output line of a setup step.
typedef ToolchainOutputSink = void Function(String line);

/// Disk, process and archive steps of the setup actions.
///
/// Every member is virtual, so the tests replace the file system, the
/// processes, the mailboxes and the archive without a network and without the
/// real storage directory.
class ToolchainInstallerPlatform {
  const ToolchainInstallerPlatform();

  bool get isWindows => Platform.isWindows;

  /// The directory that holds the `tar.exe` which reads zip.
  ///
  /// On Windows this is `%SystemRoot%\System32` and its `tar.exe` is bsdtar.
  /// `tar` in Git Bash is GNU tar, a different program, so the absolute path
  /// matters.
  String get system32 {
    final root =
        Platform.environment['SystemRoot'] ??
        Platform.environment['windir'] ??
        r'C:\Windows';
    return p.join(root, 'System32');
  }

  /// Free space of the volume that holds [directory].
  ///
  /// Dart has no portable free-space call. On Windows `dir` answers it, and
  /// that command also writes one message for every other platform, so the
  /// page never claims a size that nothing measured.
  Future<DiskSpace> diskSpace(String directory) async {
    if (!isWindows) {
      return const DiskSpace(freeBytes: null);
    }
    try {
      final output = await capture('cmd.exe', ['/c', 'dir', '/-c', directory]);
      return DiskSpace(freeBytes: parseWindowsFreeBytes(output));
    } on ToolchainCommandException {
      return const DiskSpace(freeBytes: null);
    }
  }

  /// Free bytes in the output of `dir /-c`, or null.
  ///
  /// The line looks like `1,234,567,890 bytes free`. The number grouping
  /// follows the locale, so every separator except a digit is removed.
  static int? parseWindowsFreeBytes(String output) {
    final match = RegExp(r'([\d., ]+)\s*bytes free').firstMatch(output);
    if (match == null) return null;
    final digits = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Runs one command and reports every output line through [onLine].
  ///
  /// A command that exits with a non-zero code throws
  /// [ToolchainCommandException]. The child inherits the environment of this
  /// process, which the action only reads.
  Future<void> run(
    String executable,
    List<String> arguments, {
    ToolchainOutputSink? onLine,
    String? workingDirectory,
  }) async {
    final Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw ToolchainCommandException(
        command: commandLine(executable, arguments),
        code: -1,
        output: error.message,
      );
    }
    final controller = StreamController<String>();
    final output = <String>[];
    final subscription = controller.stream.listen((line) {
      output.add(line);
      onLine?.call(line);
    });
    Future<void> read(Stream<List<int>> bytes) async {
      var pending = '';
      await for (final chunk in bytes) {
        pending += _decode(chunk);
        final lines = pending.split(_lineBreak);
        pending = lines.removeLast();
        for (final line in lines) {
          if (line.trim().isNotEmpty) controller.add(line.trim());
        }
      }
      if (pending.trim().isNotEmpty) controller.add(pending.trim());
    }

    await Future.wait([read(process.stdout), read(process.stderr)]);
    final code = await process.exitCode;
    await controller.close();
    await subscription.cancel();
    if (code != 0) {
      throw ToolchainCommandException(
        command: commandLine(executable, arguments),
        code: code,
        output: output.join('\n'),
      );
    }
  }

  /// Runs one command and returns its output, or throws on a failure.
  Future<String> capture(
    String executable,
    List<String> arguments, {
    bool reportFailure = false,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );
      if (result.exitCode != 0 && reportFailure) {
        throw ToolchainCommandException(
          command: commandLine(executable, arguments),
          code: result.exitCode,
          output: '${result.stdout}\n${result.stderr}',
        );
      }
      return '${result.stdout}';
    } on ProcessException catch (error) {
      throw ToolchainCommandException(
        command: commandLine(executable, arguments),
        code: -1,
        output: error.message,
      );
    }
  }

  /// Starts a command and drops the handle at once.
  ///
  /// The macOS installer opens a system dialog and returns, so the action must
  /// not wait for it.
  Future<void> launch(String executable, List<String> arguments) async {
    try {
      await Process.start(executable, arguments);
    } on ProcessException catch (error) {
      throw ToolchainCommandException(
        command: commandLine(executable, arguments),
        code: -1,
        output: error.message,
      );
    }
  }

  /// Unpacks [archive] into [target] and reports the lines of bsdtar.
  ///
  /// bsdtar reads zip, and not xz or 7z. It keeps the top-level directory of
  /// the archive, so a zip with one such directory lands at
  /// `<target>/<that name>`.
  Future<void> extractZip(
    String archive,
    String target, {
    ToolchainOutputSink? onLine,
  }) async {
    await Directory(target).create(recursive: true);
    await run(
      p.join(system32, 'tar.exe'),
      ['-xf', archive, '-C', target],
      onLine: onLine,
    );
  }

  /// Exact command line, for the page and for a failure message.
  static String commandLine(String executable, List<String> arguments) => [
    if (executable.contains(' ')) '"$executable"' else executable,
    for (final argument in arguments)
      argument.contains(' ') ? '"$argument"' : argument,
  ].join(' ');

  static String _decode(List<int> bytes) {
    try {
      return const SystemEncoding().decode(bytes);
    } on FormatException {
      return String.fromCharCodes(bytes);
    }
  }

  /// Line break of a command output; a build tool uses any of the three.
  static final RegExp _lineBreak = RegExp(r'\r\n|\n|\r');
}
