import 'dart:io';

import 'native_compiler_host.dart';

/// Adversarial self-test for the hardened native verifier: proves the gates
/// actually FAIL a bad sample rather than passing on stdout alone.
///
/// Run: `dart run tool/forge_content/negative_probe.dart`
Future<void> main() async {
  final c = WslNativeCompiler();
  final repoRoot = Directory.current.path;
  final reason = await c.probe();
  if (reason != null) {
    stderr.writeln('compiler_unavailable: $reason');
    exitCode = 3;
    return;
  }

  var ok = true;

  Future<void> check(String name, bool condition) async {
    stdout.writeln('${condition ? 'PASS' : 'FAIL'}  $name');
    if (!condition) ok = false;
  }

  // 1. non-zero exit must not pass (exit status asserted)
  final nz = await c.compileAndRun(
    language: 'c',
    source: 'int main(void){return 7;}',
    standard: 'c17',
  );
  await check('nonzero exit is reported (exitCode==7)', nz.exitCode == 7);

  // 2. stderr output must be visible (not silently dropped)
  final se = await c.compileAndRun(
    language: 'c',
    source: '#include <stdio.h>\nint main(void){fprintf(stderr,"boom\\n");'
        'printf("ok\\n");return 0;}',
    standard: 'c17',
  );
  await check('program stderr is captured', se.stderr.contains('boom'));
  await check('stdout still captured alongside stderr', se.stdout.trim() == 'ok');

  // 3. a hang must be a timeout, not a silent pass
  final hang = await c.compileAndRun(
    language: 'c',
    source: 'int main(void){for(;;){}return 0;}',
    standard: 'c17',
    timeout: const Duration(seconds: 3),
  );
  await check('infinite loop is a timeout', hang.timedOut);

  // 4. a compile error must be flagged, not passed
  final bad = await c.compileAndRun(
    language: 'c',
    source: 'int main(void){ this is not C }',
    standard: 'c17',
  );
  await check('compile error is flagged', bad.compileFailed);

  // 5. the app ceiling is enforced
  await check(
    'c++23 is above the c++20 cap',
    !WslNativeCompiler.standardWithinCap('cpp', 'c++23'),
  );
  await check(
    'c++20 is within the cap',
    WslNativeCompiler.standardWithinCap('cpp', 'c++20'),
  );
  await check(
    'c17 is within the cap',
    WslNativeCompiler.standardWithinCap('c', 'c17'),
  );

  // 6. isolation: a sample writing a RELATIVE file must write only inside its
  //    own temporary working directory, never the repo cwd.
  final marker = 'qfli_iso_probe_${DateTime.now().microsecondsSinceEpoch}.txt';
  final cwdMarker = File('$repoRoot/$marker');
  if (cwdMarker.existsSync()) cwdMarker.deleteSync();
  final iso = await c.compileAndRun(
    language: 'c',
    source: '#include <stdio.h>\n'
        'int main(void){ FILE* f=fopen("$marker","w"); if(!f) return 3;'
        ' fputs("x",f); fclose(f); puts("wrote"); return 0; }',
    standard: 'c17',
  );
  await check('relative-file sample ran', iso.exitCode == 0 && iso.stdout.trim() == 'wrote');
  await check(
    'relative-file sample did NOT write into the repo cwd',
    !File('$repoRoot/$marker').existsSync() &&
        !File('${Directory.current.path}/$marker').existsSync(),
  );

  stdout.writeln(ok ? 'ALL NEGATIVE PROBES PASS' : 'NEGATIVE PROBES FAILED');
  if (!ok) exitCode = 1;
}
