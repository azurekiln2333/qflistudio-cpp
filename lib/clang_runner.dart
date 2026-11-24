import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'android_clang_runner.dart';
import 'native_clang_runner.dart';
import 'run_title.dart';
import 'source_selection.dart';
import 'toolchain/compiler_candidate.dart';
import 'toolchain/local_toolchain_environment.dart';
import 'toolchain/toolchain_environment.dart';
import 'toolchain/toolchain_lookup.dart';

/// Native C/C++ compiler backend for QFLIForge.
///
/// Desktop builds use an installed or bundled compiler. Android streams native
/// compilation and execution through its platform bridge. iOS compiles to WASI
/// modules and executes them using its bundled interpreter.
class ClangProgramRunner implements ProgramRunner {
  ClangProgramRunner({
    ProcessSupervisor? supervisor,
    String? toolchainDirectory,
    ToolchainEnvironment? environment,
  }) : _supervisor = supervisor ?? ProcessSupervisor(),
       _toolchainDirectory = toolchainDirectory,
       _environment = environment ?? forgeToolchainEnvironment;

  static const _nativeChannel = MethodChannel('qfli_forge/native');
  static const _extensions = <String>{
    '.c',
    '.cpp',
    '.cc',
    '.cxx',
  };

  /// Header files are readable/editable and are pulled in through `#include`,
  /// but they are never an executable translation unit. Long-pressing one in
  /// the editor must fail explicitly instead of re-selecting a different
  /// program's `main`.
  static const _headerExtensions = <String>{'.h', '.hpp', '.hh'};

  ///
  /// Whether this platform reaches the compiler through the bundled-toolchain
  /// MethodChannel (Android, iOS, OHOS) rather than spawning a local process.
  ///
  /// Exposed for tests and for callers that need to describe the backend.
  /// Deliberately tolerant of OHOS: Flutter has no TargetPlatform value for it,
  /// so the kernel's operating-system string is also consulted.
  ///
  static bool get usesBundledToolchainChannel {
    if (Platform.isAndroid || Platform.isIOS) return true;
    final String os = Platform.operatingSystem;
    return os == 'ohos' || os == 'harmony';
  }

  ///
  /// Builds the channel-backed runner for a bundled-toolchain platform.
  ///
  /// Kept as a factory so tests can inject a mock channel and event stream
  /// without having to fake platform detection.
  ///
  static NativeClangRunner constructNativeRunner({
    required MethodChannel channel,
    required Stream<Object?> events,
    required String backendName,
    required String runIdPrefix,
    bool allowCFallback = false,
    Duration? cancellationExitTimeout,
  }) {
    return NativeClangRunner(
      channel: channel,
      events: events,
      backendName: backendName,
      runIdPrefix: runIdPrefix,
      allowCFallback: allowCFallback,
      cancellationExitTimeout: cancellationExitTimeout,
    );
  }

  final ProcessSupervisor _supervisor;
  final String? _toolchainDirectory;

  /// Settings and managed toolchains of the environment page.
  ///
  /// Read for every run, so a changed setting or a finished setup applies at
  /// the next run without a restart of the application.
  final ToolchainEnvironment _environment;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final extension = p.extension(entryFile).toLowerCase();
    if (_headerExtensions.contains(extension)) {
      return _unavailable(
        '头文件不能单独运行，请在 .c/.cpp 源文件中运行。',
        projectPath: projectPath,
        entryFile: entryFile,
      );
    }
    if (!_extensions.contains(extension)) return null;
    // The entry must be an existing, readable, supported source inside the
    // project. Resolve symlinks on both sides so a link inside the project
    // cannot launch a program outside it. Invalid entries fail with 127 and
    // never fall back to the default main.
    final invalid = _entryError(projectPath, entryFile);
    if (invalid != null) {
      return _unavailable(invalid, projectPath: projectPath, entryFile: entryFile);
    }
    final type = extension == '.c' ? 'c' : 'cpp';
    if (Platform.isAndroid) {
      return AndroidClangRunner().run(
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
        sources: _selectedSources(projectPath, entryFile),
      );
    }
    if (Platform.isIOS) {
      return NativeClangRunner(
        backendName: 'iOS Clang/WASI',
        runIdPrefix: 'ios',
      ).run(
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
        sources: _selectedSources(projectPath, entryFile),
      );
    }
    //
    // OHOS 用与 Android/iOS 相同的通道协议，但走自己那套桥：
    // QfliCNative.ets 调用签名包内的 LLVM 22，将源码编译为 WASI 后解释执行。
    // 因为确实支持 C++20 / 标准库 / 异常，所以不留 C 回退（allowCFallback 保持 false）。
    //
    if (Platform.operatingSystem == 'ohos' ||
        Platform.operatingSystem == 'harmony') {
      final List<String> sources;
      try {
        sources = _selectedSources(projectPath, entryFile);
      } catch (error) {
        return _unavailable('$error', projectPath: projectPath, entryFile: entryFile);
      }
      // OHOS 桥要求 sources 必填且非空；空列表说明工程里没有可编译单元，
      // 必须在这里拦下，不能让桥收到一个会退化成“重新发现所有文件”的请求。
      if (sources.isEmpty) {
        return _unavailable(
          '工程中没有可编译的源文件。',
          projectPath: projectPath,
          entryFile: entryFile,
        );
      }
      return NativeClangRunner(
        backendName: 'OHOS Clang',
        runIdPrefix: 'ohos',
      ).run(
        type: type,
        projectPath: projectPath,
        entryFile: entryFile,
        sources: sources,
      );
    }
    if (AppPaths.isDesktop) {
      final List<String> sources;
      try {
        sources = _selectedSources(projectPath, entryFile);
      } catch (error) {
        return _unavailable(
          '$error',
          projectPath: projectPath,
          entryFile: entryFile,
        );
      }
      final projectType =
          sources.any((source) => p.extension(source).toLowerCase() != '.c')
          ? 'cpp'
          : 'c';
      final compiler = await _findCompiler(projectType, projectPath);
      if (compiler == null) {
        return _unavailable(
          '未找到可用的 C/C++ 编译工具链。请在工具页打开「环境配置」。',
          projectPath: projectPath,
          entryFile: entryFile,
        );
      }
      return _runDesktop(
        compiler: compiler,
        type: projectType,
        sources: sources,
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

  /// Returns an English reason when [entryFile] cannot be run inside
  /// [projectPath], or null when it is a valid in-project C/C++ source.
  String? _entryError(String projectPath, String entryFile) {
    final project = Directory(projectPath);
    if (!project.existsSync()) return '工程目录不可读取。';
    final file = File(entryFile);
    if (!file.existsSync()) return '入口文件不存在。';
    final String root;
    final String resolved;
    try {
      root = project.resolveSymbolicLinksSync();
      resolved = file.resolveSymbolicLinksSync();
    } on FileSystemException {
      return '入口文件不可读取。';
    }
    if (!p.isWithin(root, resolved) && !p.equals(root, resolved)) {
      return '入口文件不在工程内。';
    }
    return null;
  }

  /// Project translation units to compile for [entryFile].
  ///
  /// All `.c/.cc/.cpp/.cxx` units are enumerated, then
  /// [selectRunSources] keeps the requested entry and ordinary helpers and
  /// drops only other unambiguous top-level `main` definitions.
  List<String> _selectedSources(String projectPath, String entryFile) {
    final all = _collectSources(projectPath);
    return selectRunSources(
      entryFile: p.normalize(p.absolute(entryFile)),
      allSources: all.map((path) => p.normalize(p.absolute(path))).toList(),
      readSource: (path) {
        final file = File(path);
        if (!file.existsSync()) return null;
        try {
          return file.readAsStringSync();
        } on FileSystemException {
          return null;
        }
      },
    );
  }

  /// Compiler that the next run of a [type] program uses, or null.
  ///
  /// [ToolchainLookup] holds the one candidate list that the environment page
  /// shows as well, so the page never presents a compiler that a run does not
  /// pick. Places 1 to 3 of that list stay first whatever the preference says.
  Future<DetectedCompiler?> _findCompiler(
    String type,
    String projectPath,
  ) async {
    final language = type == 'c' ? CompilerLanguage.c : CompilerLanguage.cpp;
    if (!_environment.supported) {
      return _lookup(projectPath).find(
        language,
        overrideDirectory: _toolchainDirectory,
      );
    }
    await _environment.load();
    return _lookup(projectPath).find(
      language,
      preference: _environment.settings.preference,
      overrideDirectory: _toolchainDirectory,
      overrideHome: Platform.environment['QFLI_TOOLCHAIN_HOME'],
      configuredDirectory: _environment.settings.directory,
      managedRoots: await _managedRoots(),
    );
  }

  /// The candidate list of this computer, for one project.
  ToolchainLookup _lookup(String projectPath) => ToolchainLookup(
    isWindows: Platform.isWindows,
    environment: Platform.environment,
    executableDirectory: p.dirname(Platform.resolvedExecutable),
    projectPath: projectPath,
  );

  /// Toolchain roots that a setup action of the environment page installed.
  ///
  /// Read for every run: a finished setup must work without a restart, and it
  /// must stop working after `remove`. The web build reports none.
  Future<List<String>> _managedRoots() async {
    final environment = _environment;
    if (!environment.supported) return const [];
    return await environment.managedRoots ?? const [];
  }

  /// Environment of a compiler, link or program child.
  ///
  /// A program of a toolchain outside `PATH` needs the runtime libraries of
  /// that toolchain: MinGW links `libstdc++-6.dll`, `libgcc_s_seh-1.dll` and
  /// `libwinpthread-1.dll`, LLVM-MinGW links `libc++.dll` and `libunwind.dll`.
  /// Windows ended such a program with `0xC0000135` and no output. The `bin`
  /// directories of the toolchains go in front of the inherited `PATH`, which
  /// itself stays unchanged. On POSIX they go to `LD_LIBRARY_PATH` (Linux) and
  /// `DYLD_LIBRARY_PATH` (macOS).
  ///
  /// [executables] holds every compiler of the run, because the C part of a
  /// C++ project may come from another toolchain than its link step.
  Map<String, String> _childEnvironment(List<String> executables) {
    final environment = Map<String, String>.from(Platform.environment);
    final directories = <String>{
      for (final executable in executables)
        if (p.isAbsolute(executable)) p.dirname(executable),
    };
    if (directories.isEmpty) return environment;
    final joined = directories.join(Platform.isWindows ? ';' : ':');
    if (Platform.isWindows) {
      // CreateProcess reads `Path`, and a child that gets only `PATH` keeps the
      // inherited `Path`. Use the spelling that the parent already has.
      final name =
          environment.containsKey('PATH') && !environment.containsKey('Path')
          ? 'PATH'
          : 'Path';
      final current = environment[name] ?? '';
      environment[name] = current.isEmpty ? joined : '$joined;$current';
      return environment;
    }
    final name = Platform.isMacOS ? 'DYLD_LIBRARY_PATH' : 'LD_LIBRARY_PATH';
    final current = environment[name] ?? '';
    environment[name] = current.isEmpty ? joined : '$joined:$current';
    return environment;
  }

  ProgramRunResult _runDesktop({
    required DetectedCompiler compiler,
    required String type,
    required List<String> sources,
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
      var code = kProgramNotRunExitCode;
      try {
        final build = Directory(p.join(projectPath, '.qfli', 'build', 'forge'))
          ..createSync(recursive: true);
        final output = p.join(
          build.path,
          Platform.isWindows ? 'program.exe' : 'program',
        );
        if (sources.isEmpty) {
          stderr.add('工程中没有可编译的源文件。');
          return;
        }
        final includeArgs = <String>['-I', projectPath];
        final includeDir = Directory(p.join(projectPath, 'include'));
        if (includeDir.existsSync()) {
          includeArgs.addAll(['-I', includeDir.path]);
        }
        DetectedCompiler? cCompiler;
        if (type == 'cpp' &&
            sources.any(
              (source) => p.extension(source).toLowerCase() == '.c',
            )) {
          cCompiler = await _findCompiler('c', projectPath);
          if (cCompiler == null) {
            stderr.add('工程包含 C 源文件，但未找到可用的 C 编译器。');
            return;
          }
        }
        // The program that a toolchain outside PATH built needs the runtime
        // libraries of that toolchain; see [_childEnvironment].
        final environment = _childEnvironment([
          compiler.executable,
          if (cCompiler case final DetectedCompiler driver) driver.executable,
        ]);
        final objects = <String>[];
        for (var index = 0; index < sources.length; index++) {
          if (cancelled) return;
          final source = sources[index];
          final isC = p.extension(source).toLowerCase() == '.c';
          final driver = isC ? cCompiler ?? compiler : compiler;
          final object = p.join(build.path, 'unit_$index.o');
          objects.add(object);
          final compile = await _supervisor.start(driver.executable, [
            '-x',
            isC ? 'c' : 'c++',
            '-std=${driver.standard}',
            ...includeArgs,
            '-c',
            source,
            '-o',
            object,
          ], workingDirectory: projectPath, environment: environment);
          current = compile;
          if (cancelled) {
            await compile.cancel();
            return;
          }
          await Future.wait([
            _pipe(compile.stdout, stderr),
            _pipe(compile.stderr, stderr),
          ]);
          final compileCode = await compile.exitCode;
          if (cancelled || compileCode != 0) {
            code = compileCode;
            return;
          }
        }
        final link = await _supervisor.start(compiler.executable, [
          ...objects,
          if (Platform.isLinux) '-lm',
          '-o',
          output,
        ], workingDirectory: projectPath, environment: environment);
        current = link;
        if (cancelled) {
          await link.cancel();
          return;
        }
        await Future.wait([
          _pipe(link.stdout, stderr),
          _pipe(link.stderr, stderr),
        ]);
        final linkCode = await link.exitCode;
        if (cancelled || linkCode != 0) {
          code = linkCode;
          return;
        }

        final program = await _supervisor.start(
          output,
          const [],
          workingDirectory: projectPath,
          environment: environment,
        );
        current = program;
        if (cancelled) {
          await program.cancel();
          return;
        }
        final input = File(p.join(projectPath, 'input.txt'));
        if (input.existsSync()) program.stdin.write(await input.readAsString());
        await program.stdin.close();
        await Future.wait([
          _pipe(program.stdout, stdout),
          _pipe(program.stderr, stderr),
        ]);
        code = await program.exitCode;
      } on ProcessException catch (error) {
        if (!cancelled) stderr.add(error.message);
      } catch (error) {
        if (!cancelled) stderr.add('$error');
      } finally {
        await current?.cancel();
        _finish(exitCode, cancelled ? 130 : code);
        unawaited(stdout.close());
        unawaited(stderr.close());
        if (!done.isCompleted) done.complete();
      }
    }

    unawaited(start());
    return ProgramRunResult(
      title: runTitle(projectPath: projectPath, entryFile: entryFile),
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: exitCode.future,
      cancel: () async {
        if (exitCode.isCompleted) return;
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
      title: runTitle(projectPath: projectPath, entryFile: entryFile),
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: result.future,
    );
  }

  List<String> _collectSources(String projectPath) {
    const extensions = {'.cpp', '.cc', '.cxx', '.c'};
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

  ProgramRunResult _unavailable(
    String message, {
    required String projectPath,
    required String entryFile,
  }) {
    final stderr = StreamController<String>();
    scheduleMicrotask(
      () => stderr
        ..add(message)
        ..close(),
    );
    return ProgramRunResult(
      title: runTitle(projectPath: projectPath, entryFile: entryFile),
      stdout: const Stream<String>.empty(),
      stderr: stderr.stream,
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  void _finish(Completer<int> completer, int code) {
    if (!completer.isCompleted) completer.complete(code);
  }
}
