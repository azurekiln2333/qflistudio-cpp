import 'package:path/path.dart' as p;

import 'toolchain_environment.dart';

/// `c` or `cpp`.
///
/// The runner passes the kind of the entry program. The environment page
/// passes `null` and asks for both.
enum CompilerLanguage {
  c('c'),
  cpp('cpp');

  const CompilerLanguage(this.id);

  /// Value of [DetectedCompiler.language].
  final String id;
}

/// One place that the lookup checks for a compiler.
///
/// [place] is the contract of the lookup (`1` to `8` in
/// `.trellis/spec/backend/desktop-runtime.md`), [source] is the value that a
/// compiler found here reports.
class CompilerCandidate {
  const CompilerCandidate({
    required this.executable,
    required this.place,
    required this.source,
  });

  /// Absolute path, or the bare name that `PATH` resolves.
  final String executable;

  /// Place of the contract, 1 to 8.
  final int place;

  final CompilerSource source;

  /// Bare names are resolved through `PATH`; the lookup cannot test them with
  /// `File.exists`.
  bool get isBareName => !p.isAbsolute(executable);

  /// Toolchain root of [executable]: the parent of `bin` for a path such as
  /// `<root>/bin/clang.exe`, and null for a bare name or for a path outside a
  /// directory named `bin`.
  static String? rootOf(String executable) {
    if (!p.isAbsolute(executable)) return null;
    final directory = p.dirname(executable);
    return p.basename(directory).toLowerCase() == 'bin'
        ? p.dirname(directory)
        : null;
  }

  @override
  String toString() => 'CompilerCandidate($executable, place $place)';
}

/// Executables to try for [language], from the place names that the runner
/// already used: `clang` then `gcc` for C, `clang++` then `g++` for C++.
List<String> compilerFileNames(
  CompilerLanguage language, {
  required bool isWindows,
}) {
  final names = language == CompilerLanguage.c
      ? const ['clang', 'gcc']
      : const ['clang++', 'g++'];
  return [for (final name in names) isWindows ? '$name.exe' : name];
}
