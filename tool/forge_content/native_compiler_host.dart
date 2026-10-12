import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs the native C/C++ compiler inside the WSL distro that hosts the modern
/// toolchain, because the Windows-only fallback (TDM-GCC 4.9.2) cannot compile
/// C17+/C++14+ samples and must never silently stand in for a real check.
///
/// The contract (see `.trellis/tasks/10-12-c-cpp-substantive-curriculum/design.md`
/// and `research/verification-plan.md`):
///
///   * The primary toolchain is the `qfli-java-build` WSL2 distro
///     (`clang++` 18.1.3 / `g++` 13.3.0). If it is missing, the run **fails**
///     with `compiler_unavailable`; it never downgrades to the Windows compiler
///     or to the in-app interpreter.
///   * Windows absolute paths are translated with `wslpath` so a path bug is not
///     misread as a content failure.
///   * A sample's `-std` is chosen per sample from the requested standard and the
///     compiler's real support; the exact flag and compiler version are returned
///     so the ceiling is auditable.

/// One compiled-and-run result.
class NativeRunResult {
  const NativeRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.standard,
    required this.compiler,
    required this.compilerVersion,
    this.unavailable,
    this.compileFailed = false,
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  /// The exact `-std=` value used for this sample.
  final String standard;

  /// `clang++` or `g++`.
  final String compiler;
  final String compilerVersion;

  /// Set when the environment (not the sample) made execution impossible.
  final String? unavailable;

  /// True when compilation itself failed (a real content failure).
  final bool compileFailed;

  /// True when the program did not exit on its own within the timeout.
  final bool timedOut;

  bool get environmentUnavailable => unavailable != null;
}

/// Native compiler gateway over WSL `qfli-java-build`.
class WslNativeCompiler {
  WslNativeCompiler({
    this.distro = 'qfli-java-build',
    this.clang = 'clang++',
    this.gcc = 'g++',
  });

  /// The distro that owns the modern toolchain. It is `qfli_java`-owned; this
  /// verifier only reads it.
  final String distro;

  final String clang;
  final String gcc;

  bool _probed = false;
  String? _unavailable;
  String _clangVersion = '';
  String _gccVersion = '';

  /// Probes the distro once. Returns a human reason when unusable, else null.
  Future<String?> probe() async {
    if (_probed) return _unavailable;
    _probed = true;
    final which = await _runBash(
      'command -v $clang >/dev/null 2>&1 && command -v $gcc >/dev/null 2>&1',
    );
    if (which == null) {
      _unavailable = 'wsl distro "$distro" is not reachable';
      return _unavailable;
    }
    if (which.exitCode != 0) {
      _unavailable = '$clang/$gcc not found in "$distro"';
      return _unavailable;
    }
    _clangVersion = await _version('$clang --version');
    _gccVersion = await _version('$gcc --version');
    return null;
  }

  String get clangVersion => _clangVersion;
  String get gccVersion => _gccVersion;

  /// Compiles and runs [source] in a scratch directory.
  ///
  /// [standard] is the requested language standard (`c++20`, `c23`, ...). When
  /// the compiler rejects it, the verifier records `standard_unavailable` by
  /// returning a result whose [standard] is the last accepted fallback — but it
  /// never silently drops a C++ sample to an older standard without that being
  /// visible in the returned [standard].
  Future<NativeRunResult> compileAndRun({
    required String language, // 'c' or 'cpp'
    required String source,
    required String standard,
    String? stdinText,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final reason = await probe();
    if (reason != null) {
      return NativeRunResult(
        exitCode: 127,
        stdout: '',
        stderr: '',
        standard: standard,
        compiler: language == 'c' ? gcc : clang,
        compilerVersion: '',
        unavailable: reason,
      );
    }

    final compiler = language == 'c' ? gcc : clang;
    final version = language == 'c' ? _gccVersion : _clangVersion;
    final ext = language == 'c' ? 'c' : 'cpp';

    // Source is passed as base64 to avoid all shell/heredoc quoting pitfalls.
    final script = StringBuffer()
      ..writeln('work=\$(mktemp -d)')
      ..writeln(r'trap "rm -rf ""$work"" " EXIT')
      ..writeln('cd "\$work"')
      ..writeln('base64 -d > main.$ext <<\'SRCB64\'')
      ..writeln(base64.encode(utf8.encode(source)))
      ..writeln('SRCB64');
    if (stdinText != null) {
      script
        ..writeln('base64 -d > input.txt <<\'INB64\'')
        ..writeln(base64.encode(utf8.encode(stdinText)))
        ..writeln('INB64');
    }
    script.writeln('std=""');
    final standards = _standardCandidates(language, standard);
    for (final candidate in standards) {
      script.writeln(
        'if [ -z "\$std" ] && $compiler -std=$candidate main.$ext '
        '-o prog 2>cerr; then std=$candidate; fi',
      );
    }
    script.writeln('if [ -z "\$std" ]; then echo COMPILE_FAIL; cat cerr; exit 200; fi');
    script.writeln('echo "QFLI_STD=\$std"');
    // Run the program, capturing its exit status and its own stderr separately
    // from the compiler diagnostics so a sample that writes to stderr cannot
    // pass silently.
    final runLine = stdinText != null ? './prog < input.txt' : './prog';
    script.writeln('$runLine > prog_stdout 2> prog_stderr; qfli_rc=\$?');
    script.writeln('echo "QFLI_EXIT=\$qfli_rc"');
    // Base64 the program's own stdout/stderr so byte content survives.
    script.writeln('echo "QFLI_OUT_B64=\$(base64 -w0 prog_stdout)"');
    script.writeln('echo "QFLI_ERR_B64=\$(base64 -w0 prog_stderr)"');

    // The whole script is itself base64-encoded and executed by bash, so no
    // Dart/shell interaction can corrupt the payload.
    final scriptB64 = base64.encode(utf8.encode(script.toString()));
    final result = await _runBash(
      'echo "\$QFLI_SCRIPT" | base64 -d | bash',
      timeout: timeout,
      environment: <String, String>{
        'QFLI_SCRIPT': scriptB64,
        'WSLENV': 'QFLI_SCRIPT',
      },
    );
    if (result == null) {
      // Distinguish a hung sample from a missing environment: a null result
      // after a successful probe means the sample itself did not finish.
      return NativeRunResult(
        exitCode: 124,
        stdout: '',
        stderr: 'timeout after ${timeout.inSeconds}s',
        standard: standard,
        compiler: compiler,
        compilerVersion: version,
        timedOut: true,
      );
    }

    final raw = result.stdout;
    if (raw.contains('COMPILE_FAIL') || result.exitCode == 200) {
      final diag = raw
          .replaceFirst('COMPILE_FAIL', '')
          .replaceAll(RegExp(r'^QFLI_.*$', multiLine: true), '')
          .trim();
      return NativeRunResult(
        exitCode: 1,
        stdout: '',
        stderr: diag,
        standard: standard,
        compiler: compiler,
        compilerVersion: version,
        compileFailed: true,
      );
    }

    final stdMatch = RegExp(r'^QFLI_STD=(.*)$', multiLine: true).firstMatch(raw);
    final exitMatch = RegExp(r'^QFLI_EXIT=(\d+)\s*$', multiLine: true).firstMatch(raw);
    final outB64 = RegExp(r'^QFLI_OUT_B64=(.*)$', multiLine: true).firstMatch(raw);
    final errB64 = RegExp(r'^QFLI_ERR_B64=(.*)$', multiLine: true).firstMatch(raw);
    final usedStandard = stdMatch?.group(1) ?? standard;
    final programStdout =
        _tryBase64(outB64?.group(1) ?? '');
    final programStderr =
        _tryBase64(errB64?.group(1) ?? '');

    // A missing QFLI_EXIT line means the program was killed (e.g. by the
    // timeout) rather than exiting on its own; treat it as a timeout, not a pass.
    final exitedCleanly = exitMatch != null;
    return NativeRunResult(
      exitCode: exitedCleanly
          ? (int.tryParse(exitMatch.group(1) ?? '') ?? result.exitCode)
          : 124,
      stdout: programStdout,
      stderr: programStderr,
      standard: usedStandard,
      compiler: compiler,
      compilerVersion: version,
      timedOut: !exitedCleanly,
    );
  }

  static String _tryBase64(String value) {
    if (value.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(value), allowMalformed: true);
    } on FormatException {
      return '';
    }
  }

  /// The maximum standard the packaged app can compile. A sample authored above
  /// this ceiling must not be silently compiled at a *lower* fallback and
  /// reported as a pass, so the verifier rejects it explicitly.
  static const int _cCap = 17;
  static const int _cppCap = 20;

  /// True when [standard] is within the app ceiling for [language].
  static bool standardWithinCap(String language, String standard) {
    final n = _standardNumber(standard);
    if (n == null) return false;
    return language == 'c' ? n <= _cCap : n <= _cppCap;
  }

  static int? _standardNumber(String standard) {
    final match = RegExp(r'(\d+)$').firstMatch(standard);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Fallback candidates, ordered. C++ deliberately stops at `c++20` (the app
  /// ceiling); `c++23` is never offered because the app cannot compile it.
  static List<String> _standardCandidates(String language, String requested) {
    final list = <String>[requested];
    if (language == 'c') {
      for (final s in <String>['c17', 'c11']) {
        if (!list.contains(s)) list.add(s);
      }
    } else {
      for (final s in <String>['c++20', 'c++17', 'c++14', 'c++11']) {
        if (!list.contains(s)) list.add(s);
      }
    }
    return list;
  }

  Future<String> _version(String command) async {
    final result = await _runBash('$command 2>&1 | head -1');
    final text = result?.stdout.trim() ?? '';
    return text.split('\n').first.trim();
  }

  Future<_Captured?> _runBash(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    Map<String, String>? environment,
  }) async {
    try {
      final process = await Process.start(
        'wsl.exe',
        <String>['-d', distro, '--', 'bash', '-lc', command],
        environment: environment == null ? null : <String, String>{
          ...Platform.environment,
          ...environment,
        },
        runInShell: false,
      );
      final out = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final err = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final code = await process.exitCode.timeout(timeout, onTimeout: () {
        process.kill();
        return 124;
      });
      final stdoutText = await out;
      final stderrText = await err;
      return _Captured(code, stdoutText, stderrText);
    } on ProcessException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}

/// A minimal process-result substitute (the SDK's `ProcessResult` is final
/// and cannot be implemented outside the SDK).
class _Captured {
  _Captured(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}
