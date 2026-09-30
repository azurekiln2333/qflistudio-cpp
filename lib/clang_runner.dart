import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'android_clang_runner.dart';

/// Native C/C++ compiler backend for QFLIForge.
///
/// Desktop builds use an installed or bundled compiler. Android streams native
/// compilation and execution through its platform bridge.
class ClangProgramRunner implements ProgramRunner {
  ClangProgramRunner({
    ProcessSupervisor? supervisor,
    String? toolchainDirectory,
  }) : _supervisor = supervisor ?? ProcessSupervisor(),
       _toolchainDirectory = toolchainDirectory;

  static const _nativeChannel = MethodChannel('qfli_forge/native');
  static const _extensions = <String>{
    '.c',
    '.cpp',
    '.cc',
    '.cxx',
    '.h',
    '.hpp',
    '.hh',
  };

  final ProcessSupervisor _supervisor;
  final String? _toolchainDirectory;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final extension = p.extension(entryFile).toLowerCase();
    if (!_extensions.contains(extension)) return null;
    final type = extension == '.c' || extension == '.h' ? 'c' : 'cpp';
    if (Platform.isAndroid) {
      return AndroidClangRunner().run(
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
      );
    }
    if (AppPaths.isDesktop) {
      final compiler = await _findCompiler(type, projectPath);
      if (compiler == null) {
        return _unavailable('未找到可用的 C/C++ 编译工具链。');
      }
      return _runDesktop(
        compiler: compiler,
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
      );
    }
    return _runNative(
      type: type,
      projectPath: projectPath,
      entryFile: entryFile,
    );
  }

  Future<_Compiler?> _findCompiler(String type, String projectPath) async {
    final isC = type == 'c';
    final names = isC ? const ['clang', 'gcc'] : const ['clang++', 'g++'];
    final configured = [
      Platform.environment[isC ? 'QFLI_CLANG' : 'QFLI_CLANGXX'],
      Platform.environment[isC ? 'QFLI_CC' : 'QFLI_CXX'],
    ];
    final roots = <String>[
      ?_toolchainDirectory,
      if (Platform.environment['QFLI_TOOLCHAIN_HOME'] case final String home)
        home,
      p.join(p.dirname(Platform.resolvedExecutable), 'toolchain'),
      if (Platform.isWindows) ...[
        p.join(
          p.rootPrefix(p.absolute(projectPath)),
          'ProgramFiles',
          'Dev-Cpp',
          'MinGW64',
        ),
        p.join(
          p.rootPrefix(Platform.resolvedExecutable),
          'ProgramFiles',
          'Dev-Cpp',
          'MinGW64',
        ),
        p.join(
          Platform.environment['ProgramFiles'] ?? '',
          'Dev-Cpp',
          'MinGW64',
        ),
      ],
    ];
    final candidates = <String>{
      ...configured.whereType<String>().where((value) => value.isNotEmpty),
      for (final root in roots)
        for (final name in names)
          p.join(root, 'bin', Platform.isWindows ? '$name.exe' : name),
      ...names,
    };
    for (final candidate in candidates) {
      if (p.isAbsolute(candidate) && !File(candidate).existsSync()) continue;
      final compiler = await _probeCompiler(candidate, type);
      if (compiler != null) return compiler;
    }
    return null;
  }

  Future<_Compiler?> _probeCompiler(String executable, String type) async {
    final temporary = await Directory.systemTemp.createTemp(
      'qfli_compiler_probe_',
    );
    try {
      final source = File(
        p.join(temporary.path, type == 'c' ? 'probe.c' : 'probe.cpp'),
      );
      await source.writeAsString(
        type == 'c'
            ? '#include <stdio.h>\nint main(void) { puts("ok"); return 0; }\n'
            : '#include <iostream>\nint main() { std::cout << "ok"; return 0; }\n',
      );
      final output = p.join(
        temporary.path,
        Platform.isWindows ? 'probe.exe' : 'probe',
      );
      final standards = type == 'c'
          ? const ['c17', 'c11']
          : const ['c++20', 'c++17', 'c++14', 'c++11'];
      for (final standard in standards) {
        try {
          final process = await Process.start(executable, [
            '-std=$standard',
            source.path,
            '-o',
            output,
          ]);
          final stdoutDone = process.stdout.drain<void>();
          final stderrDone = process.stderr.drain<void>();
          int code;
          try {
            code = await process.exitCode.timeout(const Duration(seconds: 20));
          } on TimeoutException {
            process.kill();
            await process.exitCode;
            return null;
          }
          await Future.wait([stdoutDone, stderrDone]);
          if (code == 0 && File(output).existsSync()) {
            return _Compiler(executable, standard);
          }
        } on ProcessException {
          return null;
        }
      }
    } finally {
      await temporary.delete(recursive: true);
    }
    return null;
  }

  ProgramRunResult _runDesktop({
    required _Compiler compiler,
    required String type,
    required String projectPath,
    required String entryFile,
  }) {
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final exitCode = Completer<int>();
    var cancelled = false;
    ManagedProcess? current;
    final done = Completer<void>();

    Future<void> start() async {
      try {
        final sources = _collectSources(projectPath, type);
        final build = Directory(p.join(projectPath, '.qfli', 'build', 'forge'))
          ..createSync(recursive: true);
        final output = p.join(
          build.path,
          Platform.isWindows ? 'program.exe' : 'program',
        );
        if (sources.isEmpty) {
          stderr.add('工程中没有可编译的源文件。');
          return _finish(exitCode, kProgramNotRunExitCode);
        }
        final includeArgs = <String>['-I', projectPath];
        final includeDir = Directory(p.join(projectPath, 'include'));
        if (includeDir.existsSync()) {
          includeArgs.addAll(['-I', includeDir.path]);
        }
        _Compiler? cCompiler;
        if (type == 'cpp' &&
            sources.any(
              (source) => p.extension(source).toLowerCase() == '.c',
            )) {
          cCompiler = await _findCompiler('c', projectPath);
          if (cCompiler == null) {
            stderr.add('工程包含 C 源文件，但未找到可用的 C 编译器。');
            return _finish(exitCode, kProgramNotRunExitCode);
          }
        }
        final objects = <String>[];
        for (var index = 0; index < sources.length; index++) {
          final source = sources[index];
          final driver = p.extension(source).toLowerCase() == '.c'
              ? cCompiler ?? compiler
              : compiler;
          final object = p.join(build.path, 'unit_$index.o');
          objects.add(object);
          final compile = await _supervisor.start(driver.executable, [
            '-std=${driver.standard}',
            ...includeArgs,
            '-c',
            source,
            '-o',
            object,
          ], workingDirectory: projectPath);
          current = compile;
          if (cancelled) {
            await compile.cancel();
            return _finish(exitCode, 130);
          }
          await Future.wait([
            _pipe(compile.stdout, stderr),
            _pipe(compile.stderr, stderr),
          ]);
          final compileCode = await compile.exitCode;
          if (compileCode != 0) return _finish(exitCode, compileCode);
        }
        final link = await _supervisor.start(compiler.executable, [
          ...objects,
          '-o',
          output,
        ], workingDirectory: projectPath);
        current = link;
        if (cancelled) {
          await link.cancel();
          return _finish(exitCode, 130);
        }
        await Future.wait([
          _pipe(link.stdout, stderr),
          _pipe(link.stderr, stderr),
        ]);
        final linkCode = await link.exitCode;
        if (linkCode != 0) return _finish(exitCode, linkCode);

        final program = await _supervisor.start(
          output,
          const [],
          workingDirectory: projectPath,
        );
        current = program;
        if (cancelled) {
          await program.cancel();
          return _finish(exitCode, 130);
        }
        final input = File(p.join(projectPath, 'input.txt'));
        if (input.existsSync()) program.stdin.write(await input.readAsString());
        await program.stdin.close();
        await Future.wait([
          _pipe(program.stdout, stdout),
          _pipe(program.stderr, stderr),
        ]);
        _finish(exitCode, await program.exitCode);
      } on ProcessException catch (error) {
        stderr.add(error.message);
        _finish(exitCode, kProgramNotRunExitCode);
      } catch (error) {
        stderr.add('$error');
        _finish(exitCode, kProgramNotRunExitCode);
      } finally {
        unawaited(stdout.close());
        unawaited(stderr.close());
        if (!done.isCompleted) done.complete();
      }
    }

    unawaited(start());
    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（${compiler.label} $type）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exitCode.future,
      cancel: () async {
        cancelled = true;
        await current?.cancel();
        await done.future;
      },
    );
  }

  Future<ProgramRunResult?> _runNative({
    required String type,
    required String projectPath,
    required String entryFile,
  }) async {
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final result = Completer<int>();
    var fallbackToC = false;
    try {
      final raw = await _nativeChannel.invokeMethod<Object?>('run', {
        'type': type,
        'projectPath': projectPath,
        'entryFile': entryFile,
      });
      if (raw is Map && raw['available'] == true) {
        _addLines(stdout, '${raw['output'] ?? ''}');
        _addLines(stderr, '${raw['error'] ?? ''}');
        result.complete(
          raw['exitCode'] is num ? (raw['exitCode'] as num).toInt() : 0,
        );
      } else {
        fallbackToC = type == 'c';
        if (!fallbackToC) {
          _addLines(stderr, '无法加载 C++ 编译工具链。');
          result.complete(kProgramNotRunExitCode);
        }
      }
    } on MissingPluginException {
      fallbackToC = type == 'c';
      if (!fallbackToC) {
        _addLines(stderr, '无法加载 C++ 编译工具链。');
        result.complete(kProgramNotRunExitCode);
      }
    } on PlatformException catch (error) {
      _addLines(stderr, error.message ?? error.code);
      result.complete(kProgramNotRunExitCode);
    } finally {
      unawaited(stdout.close());
      unawaited(stderr.close());
    }
    if (fallbackToC) return null;
    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（HarmonyOS Clang $type）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: result.future,
    );
  }

  List<String> _collectSources(String projectPath, String type) {
    final extensions = type == 'c'
        ? const {'.c'}
        : const {'.cpp', '.cc', '.cxx', '.c'};
    final root = Directory(projectPath);
    final sources = <String>[];
    if (!root.existsSync()) return sources;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is File &&
          extensions.contains(p.extension(entity.path).toLowerCase())) {
        sources.add(entity.path);
      }
    }
    sources.sort();
    return sources;
  }

  Future<void> _pipe(
    Stream<List<int>> bytes,
    StreamController<String> target,
  ) async {
    await for (final line
        in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
      if (!target.isClosed) target.add(line);
    }
  }

  void _addLines(StreamController<String> target, String text) {
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if (line.isNotEmpty) target.add(line);
    }
  }

  ProgramRunResult _unavailable(String message) {
    final stderr = StreamController<String>();
    scheduleMicrotask(
      () => stderr
        ..add(message)
        ..close(),
    );
    return ProgramRunResult(
      title: '编译工具链不可用',
      stdout: const Stream<String>.empty(),
      stderr: stderr.stream,
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  void _finish(Completer<int> completer, int code) {
    if (!completer.isCompleted) completer.complete(code);
  }
}

class _Compiler {
  const _Compiler(this.executable, this.standard);

  final String executable;
  final String standard;

  String get label =>
      p.basenameWithoutExtension(executable).toLowerCase().contains('clang')
      ? 'Clang'
      : 'GCC';
}
