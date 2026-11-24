import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_c/toolchain/compiler_candidate.dart';
import 'package:qfli_c/toolchain/toolchain_lookup.dart';

import 'toolchain_fake_process.dart';

/// Version texts that a probe answers. The first line is the reported version.
const String gnuGccVersion =
    'gcc.exe (MinGW-W64 x86_64-ucrt-mcf-seh, built by Brecht Sanders, r2) '
    '15.2.0\r\nCopyright (C) 2025 Free Software Foundation, Inc.\r\n';

const String clangVersion =
    'clang version 20.1.8\r\nTarget: x86_64-w64-windows-gnu\r\n';

/// LLVM-MinGW ships a `gcc.exe` that is Clang.
const String llvmMinGwGccVersion =
    'clang version 20.1.8\r\nTarget: x86_64-w64-windows-gnu\r\n';

/// `gcc` on macOS is Apple Clang and names `gcc` in its second line.
const String appleClangVersion =
    'Apple clang version 16.0.0 (clang-1600.0.26.6)\r\n'
    'Target: x86_64-apple-darwin23.6.0\r\n';

/// A fake computer for [ToolchainLookup]: real files, no real process.
///
/// [versions] answers the `--version` text per executable path or bare name,
/// [broken] fails the compile of every standard, and [started] records every
/// process, so a test can prove that an executable was probed once.
class FakeCompilerHost {
  FakeCompilerHost({
    required this.isWindows,
    Map<String, String>? environment,
    this.executableDirectory,
    String? projectPath,
    String? devCpp,
  }) : environment = environment ?? <String, String>{},
       _projectPath = projectPath,
       _devCpp = devCpp;

  final bool isWindows;
  final Map<String, String> environment;
  final String? executableDirectory;

  final String? _projectPath;

  /// Base of the relative Dev-Cpp candidates. A test that names one gets that
  /// directory instead of the `ProgramFiles` of a drive root.
  final String? _devCpp;

  final Map<String, String> versions = {};
  final Set<String> broken = {};
  final List<String> started = [];

  Directory? _root;

  /// Temporary directory of this test, created on first use.
  Directory get root =>
      _root ??= Directory.systemTemp.createTempSync('qfli_toolchain_test_');

  /// Base of the project. Inside [root], so no place points at a real drive.
  String get projectPath => _projectPath ?? p.join(root.path, 'project');

  /// The Windows `ProgramFiles` of place 7, or null for the drive root.
  String? get devCpp => _devCpp;

  void dispose() {
    final directory = _root;
    if (directory != null && directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  /// Creates the file `<root>/bin/<name>` and returns its path.
  String addFile(String root, String name) {
    final file = File(p.join(root, 'bin', name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
    return file.path;
  }

  /// Creates the file `<directory>/<name>` and returns its path. Used for a
  /// `bin` directory that is [root] itself, and for a `PATH` entry.
  String addBinFile(String directory, String name) {
    final file = File(p.join(directory, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
    return file.path;
  }

  /// Creates the candidates of one toolchain root and returns its path.
  String addRoot({String name = 'toolchain'}) =>
      p.join(root.path, name);

  /// Test seam: the `ProgramFiles` directory of place 7, so a test keeps that
  /// place inside its own temporary directory.
  String? devCppOverride;

  /// Lookup of this host. [pathDirectories] replaces `PATH`.
  ToolchainLookup lookup({List<String>? pathDirectories}) {
    final pathKey = isWindows ? 'Path' : 'PATH';
    return ToolchainLookup(
      isWindows: isWindows,
      environment: {
        ...environment,
        if (pathDirectories != null)
          pathKey: pathDirectories.join(isWindows ? ';' : ':'),
      },
      executableDirectory: executableDirectory,
      projectPath: projectPath,
      devCpp: devCppOverride ?? _devCpp,
      processStarter: start,
    );
  }

  /// Process factory of the lookup.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    started.add(executable);
    final name = p.basename(executable).toLowerCase();
    if (arguments.first == '--version') {
      final text = versions[executable] ?? versions[name];
      if (text == null) throw ProcessException(executable, arguments);
      // A real Clang prints its version to stderr and a real GCC to stdout.
      // The lookup reads both, so this process answers on stdout only.
      return fakeProcess(stdout: text);
    }
    final output = arguments.indexOf('-o');
    if (broken.contains(executable) || broken.contains(name)) {
      return fakeProcess(stderr: 'probe.cpp:1:1: error', exitCode: 1);
    }
    if (output >= 0) {
      final target = File(arguments[output + 1]);
      target.parent.createSync(recursive: true);
      target.writeAsStringSync('binary');
    }
    return fakeProcess();
  }

  /// Records that [root] holds a compiler of [language] with [version].
  String addCompiler(
    String root,
    CompilerLanguage language, {
    String? fileName,
    String? version,
  }) {
    final names = compilerFileNames(language, isWindows: isWindows);
    final path = addFile(root, fileName ?? names.first);
    versions[path] = version ?? gnuGccVersion;
    versions[p.basename(path).toLowerCase()] = version ?? gnuGccVersion;
    return path;
  }

  /// Count of processes that started [executable].
  int count(String executable) =>
      started.where((entry) => entry == executable).length;
}
