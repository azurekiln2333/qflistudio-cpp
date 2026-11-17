import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'compiler_candidate.dart';
import 'toolchain_environment.dart';

/// Starts one process for [ToolchainLookup].
///
/// Keeping process creation behind a callback lets tests count and fake probes
/// without changing the production lookup.
typedef ToolchainProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    });

/// Family of a compiler as its own `--version` text names it.
///
/// Clang wins over a `gcc` word, because Apple Clang answers `gcc` in its
/// second line and every Clang build answers `clang` in its first one.
CompilerFamily familyOfVersion(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('clang')) return CompilerFamily.clang;
  return CompilerFamily.gcc;
}

/// Finds the compilers that the runner uses, in one order.
///
/// The environment page and `ClangProgramRunner` share this class, so the page
/// never shows a compiler that a run would not pick. The eight places are:
///
/// 1. `QFLI_CLANG`, `QFLI_CLANGXX`, `QFLI_CC`, `QFLI_CXX`
/// 2. the `toolchainDirectory` argument of the runner
/// 3. `QFLI_TOOLCHAIN_HOME`
/// 4. the configured toolchain directory of the settings
/// 5. managed toolchains that a setup action installed
/// 6. `<executable directory>/toolchain`
/// 7. the Windows Dev-Cpp directories
/// 8. `PATH`
///
/// Places 1 to 3 are overrides for developers and tests. They come first
/// whatever the preference says. The preference orders the two compiler
/// families across places 4 to 8 only.
class ToolchainLookup {
  ToolchainLookup({
    required this.isWindows,
    required Map<String, String> environment,
    required String? executableDirectory,
    required this.projectPath,
    String? devCpp,
    ToolchainProcessStarter? processStarter,
  }) : environment = Map<String, String>.unmodifiable(environment),
       executableDirectory = _nonEmpty(executableDirectory),
       devCpp = _nonEmpty(devCpp),
       _processStarter = processStarter ?? _startProcess;

  /// Default probe timeout. One probe compiles a small program.
  static const Duration probeTimeout = Duration(seconds: 20);

  /// Standards that a probe tries, newest first.
  static const List<String> cStandards = ['c17', 'c11'];
  static const List<String> cppStandards = ['c++20', 'c++17', 'c++14', 'c++11'];

  static const String _cSource =
      '#include <stdio.h>\nint main(void) { puts("ok"); return 0; }\n';
  static const String _cppSource =
      '#include <iostream>\nint main() { std::cout << "ok"; return 0; }\n';

  /// Windows finds a bare name with `PATHEXT`, and Dart appends `.exe` when
  /// `PATHEXT` holds no entry. Both spellings of the variable exist in the
  /// wild.
  static const String _defaultWindowsExtensions = '.COM;.EXE;.BAT;.CMD';

  final bool isWindows;
  final Map<String, String> environment;

  /// Directory of the running application, for place 6. Null skips it.
  final String? executableDirectory;

  /// Base of the relative Dev-Cpp candidates of place 7.
  final String projectPath;

  /// The Windows `ProgramFiles` directory of place 7. Null derives it from the
  /// drive of the project, as the runner did before this class existed.
  final String? devCpp;

  final ToolchainProcessStarter _processStarter;

  /// Candidate list for [language], in lookup order, without duplicates.
  ///
  /// [overrideDirectory] is place 2, [overrideHome] is place 3,
  /// [configuredDirectory] is place 4 and [managedRoots] are place 5. A null
  /// place is skipped. [preference] is applied here, so a caller probes the
  /// list from the front and the first hit wins.
  List<CompilerCandidate> candidates({
    required CompilerLanguage language,
    CompilerPreference preference = CompilerPreference.automatic,
    String? overrideDirectory,
    String? overrideHome,
    String? configuredDirectory,
    List<String> managedRoots = const [],
  }) {
    final names = compilerFileNames(language, isWindows: isWindows);
    final clang = <CompilerCandidate>[];
    final gcc = <CompilerCandidate>[];

    void addFamily(String executable, int place, CompilerSource source) {
      final name = p.basename(executable).toLowerCase();
      // The name decides the family before a process starts: the driver names
      // of a language are `clang`/`gcc` and `clang++`/`g++`. A `gcc.exe` of
      // LLVM-MinGW stays in the GCC group here; the probe corrects the family
      // of every hit from its `--version` text.
      final clangName = names.first.toLowerCase();
      (name == clangName ? clang : gcc).add(
        CompilerCandidate(
          executable: executable,
          place: place,
          source: source,
        ),
      );
    }

    void addRoot(String root, int place, CompilerSource source) {
      for (final name in names) {
        addFamily(p.join(root, 'bin', name), place, source);
      }
    }

    // Place 1: the environment variables, clang first then gcc.
    final variables = language == CompilerLanguage.c
        ? const ['QFLI_CLANG', 'QFLI_CC']
        : const ['QFLI_CLANGXX', 'QFLI_CXX'];
    for (final key in variables) {
      final value = environment[key]?.trim();
      if (value == null || value.isEmpty) continue;
      addFamily(value, 1, CompilerSource.environmentVariable);
    }

    // Places 2 and 3: the runner argument, then QFLI_TOOLCHAIN_HOME. A
    // developer root holds a whole toolchain, so it is `<root>/bin/<name>`.
    if (_nonEmpty(overrideDirectory) case final String root) {
      addRoot(root, 2, CompilerSource.knownLocation);
    }
    if (_nonEmpty(overrideHome) case final String root) {
      addRoot(root, 3, CompilerSource.knownLocation);
    }

    // Place 4: the toolchain directory of the settings.
    if (_nonEmpty(configuredDirectory) case final String root) {
      addRoot(root, 4, CompilerSource.configuredDirectory);
    }

    // Place 5: a managed toolchain holds `bin/` directly.
    for (final root in managedRoots) {
      if (root.trim().isEmpty) continue;
      addRoot(root.trim(), 5, CompilerSource.managedInstall);
    }

    // Place 6: the toolchain directory beside the executable.
    final executable = executableDirectory;
    if (executable != null) {
      addRoot(p.join(executable, 'toolchain'), 6, CompilerSource.knownLocation);
    }

    // Place 7: the Dev-Cpp directories of a Windows computer. The entries are
    // the candidates that the runner had: one from the root of the project
    // drive, one from the root of the executable drive and one from
    // `ProgramFiles`. A test names the first one directly.
    if (isWindows) {
      final roots = <String>[
        devCpp ??
            p.join(p.rootPrefix(p.absolute(projectPath)), 'ProgramFiles',
                'Dev-Cpp', 'MinGW64'),
        if (executableDirectory case final String beside)
          p.join(p.rootPrefix(beside), 'ProgramFiles', 'Dev-Cpp', 'MinGW64'),
        p.join(environment['ProgramFiles'] ?? '', 'Dev-Cpp', 'MinGW64'),
      ];
      for (final root in roots) {
        if (root.trim().isEmpty) continue;
        addRoot(root, 7, CompilerSource.knownLocation);
      }
    }

    // Place 8: the bare names, resolved through PATH by the operating system.
    for (final name in names) {
      addFamily(name, 8, CompilerSource.systemPath);
    }

    final ordered = switch (preference) {
      CompilerPreference.clang => [...clang, ...gcc],
      CompilerPreference.gcc => [...gcc, ...clang],
      CompilerPreference.automatic => _byPlace([...clang, ...gcc]),
    };
    return _overridesFirst(ordered);
  }

  /// Puts places 1 to 3 in front of the rest, keeping their own order.
  ///
  /// A family preference reorders places 4 to 8 only. An override of place 1,
  /// 2 or 3 is what a developer or a test asked for, so no preference moves it
  /// behind a compiler that the family order picked.
  static List<CompilerCandidate> _overridesFirst(
    List<CompilerCandidate> list,
  ) {
    final overrides = <CompilerCandidate>[];
    final rest = <CompilerCandidate>[];
    for (final candidate in list) {
      (candidate.place <= 3 ? overrides : rest).add(candidate);
    }
    overrides.sort((a, b) => a.place.compareTo(b.place));
    final seen = <String>{};
    return [
      for (final candidate in [...overrides, ...rest])
        if (seen.add(_key(candidate.executable))) candidate,
    ];
  }

  /// First usable compiler for [language], or null.
  ///
  /// Each executable is probed at most once per call, and only when it is a
  /// file or a bare name that `PATH` resolves.
  Future<DetectedCompiler?> find(
    CompilerLanguage language, {
    CompilerPreference preference = CompilerPreference.automatic,
    String? overrideDirectory,
    String? overrideHome,
    String? configuredDirectory,
    List<String> managedRoots = const [],
  }) async {
    final list = candidates(
      language: language,
      preference: preference,
      overrideDirectory: overrideDirectory,
      overrideHome: overrideHome,
      configuredDirectory: configuredDirectory,
      managedRoots: managedRoots,
    );
    for (final candidate in list) {
      final compiler = await probe(candidate, language);
      if (compiler != null) return compiler;
    }
    return null;
  }

  /// Usable compilers for the environment page.
  ///
  /// The result starts with the compiler that the next run of a C program
  /// uses. A C++ entry follows when [CompilerLanguage.cpp] resolves one. With
  /// [CompilerPreference.automatic] the families keep the order of today's
  /// lookup: Clang, then GCC. With a family preference the preferred family
  /// comes first.
  Future<List<DetectedCompiler>> detect({
    CompilerPreference preference = CompilerPreference.automatic,
    String? overrideDirectory,
    String? overrideHome,
    String? configuredDirectory,
    List<String> managedRoots = const [],
  }) async {
    final found = <DetectedCompiler>[
      for (final language in const [
        CompilerLanguage.cpp,
        CompilerLanguage.c,
      ])
        if (await find(
              language,
              preference: preference,
              overrideDirectory: overrideDirectory,
              overrideHome: overrideHome,
              configuredDirectory: configuredDirectory,
              managedRoots: managedRoots,
            )
            case final DetectedCompiler compiler)
          compiler,
    ];
    if (preference == CompilerPreference.automatic) {
      found.sort((a, b) {
        final byFamily = _familyRank(a.family).compareTo(
          _familyRank(b.family),
        );
        return byFamily != 0 ? byFamily : a.language.compareTo(b.language);
      });
    }
    return List<DetectedCompiler>.unmodifiable(found);
  }

  /// Compiles one program with [candidate] and reports what it is.
  ///
  /// Returns null when the executable is missing, starts no process, reports
  /// no `--version`, fails every standard, or exceeds [probeTimeout].
  Future<DetectedCompiler?> probe(
    CompilerCandidate candidate,
    CompilerLanguage language,
  ) async {
    final executable = candidate.executable;
    // Resolve a PATH name once and use that concrete file for every probe.
    // This keeps version and compile probes consistent with the existence
    // check, while the detected record retains the candidate spelling.
    final resolvedExecutable = candidate.isBareName
        ? await resolveOnPath(executable)
        : executable;
    if (resolvedExecutable == null) return null;
    if (!candidate.isBareName && await FileSystemEntity.type(executable) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    final version = await _version(resolvedExecutable);
    if (version == null) return null;
    final dialect = await _compile(resolvedExecutable, language);
    if (dialect == null) return null;
    return DetectedCompiler(
      language: language.id,
      family: familyOfVersion(version),
      executable: executable,
      version: _firstLine(version),
      standard: dialect,
      source: candidate.source,
    );
  }

  /// Absolute path that `PATH` resolves for [name], or null.
  Future<String?> resolveOnPath(String name) async {
    final pathValue = environment['PATH'] ?? environment['Path'];
    if (pathValue == null) return null;
    final directories = [
      for (final raw in pathValue.split(isWindows ? ';' : ':'))
        if (raw.trim().replaceAll('"', '').isNotEmpty)
          raw.trim().replaceAll('"', ''),
    ];
    for (final directory in directories) {
      for (final extension in _extensions()) {
        final candidate = p.join(directory, '$name$extension');
        if (await FileSystemEntity.type(candidate) ==
            FileSystemEntityType.file) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Extensions that a bare name tries on this computer. Empty on POSIX.
  List<String> _extensions() {
    if (!isWindows) return const [''];
    final raw = environment['PATHEXT'] ?? _defaultWindowsExtensions;
    return [
      '',
      for (final value in raw.split(';'))
        if (value.trim().isNotEmpty)
          value.trim().startsWith('.')
              ? value.trim().toLowerCase()
              : '.${value.trim().toLowerCase()}',
    ];
  }

  /// Environment of a probe child: the parent environment plus a C locale.
  ///
  /// The `--version` text decides the family and a translated text differs per
  /// language, so the child gets `LC_ALL=C` and answers the same everywhere.
  Map<String, String> get probeEnvironment => _probeEnvironment ??= {
    ...environment,
    'LC_ALL': 'C',
    'LANG': 'C',
  };
  Map<String, String>? _probeEnvironment;

  Future<String?> _version(String executable) async {
    Process process;
    try {
      process = await _processStarter(
        executable,
        const ['--version'],
        environment: probeEnvironment,
      );
    } on ProcessException {
      return null;
    }
    final output = StringBuffer();
    final drained = [
      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).forEach(
        output.write,
      ),
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).forEach(
        output.write,
      ),
    ];
    try {
      await process.exitCode.timeout(probeTimeout);
    } on TimeoutException {
      process.kill();
      await process.exitCode
          .timeout(probeTimeout, onTimeout: () => -1)
          .catchError((Object _) => -1);
      return null;
    }
    await Future.wait(drained);
    return output.toString();
  }

  Future<String?> _compile(String executable, CompilerLanguage language) async {
    final Directory temporary;
    try {
      temporary = await Directory.systemTemp.createTemp('qfli_compiler_probe_');
    } on FileSystemException {
      return null;
    }
    try {
      final isC = language == CompilerLanguage.c;
      final source = File(
        p.join(temporary.path, isC ? 'probe.c' : 'probe.cpp'),
      );
      await source.writeAsString(isC ? _cSource : _cppSource);
      final output = p.join(temporary.path, isWindows ? 'probe.exe' : 'probe');
      for (final standard in isC ? cStandards : cppStandards) {
        Process process;
        try {
          process = await _processStarter(executable, [
            '-std=$standard',
            source.path,
            '-o',
            output,
          ], environment: probeEnvironment);
        } on ProcessException {
          return null;
        }
        final drained = <Future<void>>[
          process.stdout.drain<void>(),
          process.stderr.drain<void>(),
        ];
        int code;
        try {
          code = await process.exitCode.timeout(probeTimeout);
        } on TimeoutException {
          process.kill();
          return null;
        }
        await Future.wait(drained);
        if (code == 0 && await File(output).exists()) return standard;
      }
    } on FileSystemException {
      return null;
    } finally {
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        // A temporary directory that cannot be removed is not a probe result.
      }
    }
    return null;
  }

  static String _firstLine(String text) => text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');

  static List<CompilerCandidate> _byPlace(List<CompilerCandidate> list) {
    final indexed = [for (var index = 0; index < list.length; index++) index];
    indexed.sort((a, b) {
      final byPlace = list[a].place.compareTo(list[b].place);
      return byPlace != 0 ? byPlace : a.compareTo(b);
    });
    return [for (final index in indexed) list[index]];
  }

  static int _familyRank(CompilerFamily family) => switch (family) {
    CompilerFamily.clang => 0,
    CompilerFamily.gcc => 1,
  };

  static String _key(String executable) =>
      p.canonicalize(executable).replaceAll(r'\', '/').toLowerCase();

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}

Future<Process> _startProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.start(
  executable,
  arguments,
  environment: environment,
  runInShell: false,
);
