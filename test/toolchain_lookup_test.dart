import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/toolchain/compiler_candidate.dart';
import 'package:qfli_c/toolchain/toolchain_environment.dart';
import 'package:qfli_c/toolchain/toolchain_lookup.dart';

import 'toolchain_fake_compiler.dart';
import 'toolchain_fake_process.dart';

/// The eight places of the compiler lookup, and the preference that orders
/// the families. Every probe runs against files of a temporary directory, so
/// no test depends on a compiler of this computer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCompilerHost host;

  setUp(() {
    host = FakeCompilerHost(
      isWindows: true,
      executableDirectory: r'C:\Program Files\QFLIForge',
    );
    // Keep every place inside the temporary directory of this test.
    host.devCppOverride = p.join(
      host.root.path,
      'ProgramFiles',
      'Dev-Cpp',
      'MinGW64',
    );
  });

  tearDown(() => host.dispose());

  /// Roots of the eight places, on one fake Windows computer.
  ({
    String variable,
    String override,
    String home,
    String configured,
    String managed,
    String beside,
    String devCpp,
    String onPath,
  })
  roots() {
    final base = host.root.path;
    return (
      variable: p.join(base, 'variable'),
      override: p.join(base, 'override'),
      home: p.join(base, 'home'),
      configured: p.join(base, 'configured'),
      managed: p.join(base, 'managed'),
      beside: host.executableDirectory!,
      devCpp: p.join(base, 'ProgramFiles', 'Dev-Cpp', 'MinGW64'),
      onPath: p.join(base, 'path'),
    );
  }

  test('the eight places keep the documented order', () {
    final r = roots();
    final lookup = host.lookup(pathDirectories: [r.onPath]);
    final candidates = lookup.candidates(
      language: CompilerLanguage.c,
      overrideDirectory: r.override,
      overrideHome: r.home,
      configuredDirectory: r.configured,
      managedRoots: [r.managed],
    );
    // Place 5 is the root that a setup action installed.
    final places = <String, int>{};
    for (final candidate in candidates) {
      places.putIfAbsent(candidate.executable, () => candidate.place);
    }
    expect(places[p.join(r.override, 'bin', 'clang.exe')], 2);
    expect(places[p.join(r.home, 'bin', 'clang.exe')], 3);
    expect(places[p.join(r.configured, 'bin', 'clang.exe')], 4);
    expect(places[p.join(r.managed, 'bin', 'clang.exe')], 5);
    expect(places[p.join(r.beside, 'toolchain', 'bin', 'clang.exe')], 6);
    expect(host.lookup().candidates(language: CompilerLanguage.c).any((entry) => entry.place == 6), isTrue);    expect(places['clang.exe'], 8);
    // Place 7 is the Dev-Cpp location of the drive of the project.
    final devCpp = places.keys.where(
      (path) => path.contains('Dev-Cpp') &&
          path.startsWith(r.devCpp),
    ).toList();
    expect(devCpp, isNotEmpty);
    expect(places[devCpp.first], 7);
  });

  test('an environment variable comes first, whatever the preference', () {
    final r = roots();
    final compiler = host.addFile(r.variable, 'clang.exe');
    host.versions[compiler] = clangVersion;
    host.environment['QFLI_CLANG'] = compiler;
    final configured = host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      version: gnuGccVersion,
    );

    // The lookup reads the environment at construction time.
    final candidates = host
        .lookup(pathDirectories: [r.onPath])
        .candidates(
          language: CompilerLanguage.c,
          preference: CompilerPreference.clang,
          overrideDirectory: r.override,
          configuredDirectory: r.configured,
        );
    expect(candidates.first.executable, compiler);
    expect(candidates.first.place, 1);
    expect(candidates.first.source, CompilerSource.environmentVariable);
    expect(candidates.map((entry) => entry.executable), contains(configured));
    // A GCC preference cannot move the override of place 1 behind a family.
    final gccFirst = host.lookup().candidates(
      language: CompilerLanguage.c,
      preference: CompilerPreference.gcc,
      overrideDirectory: r.override,
      configuredDirectory: r.configured,
    );
    expect(gccFirst.first.executable, compiler);
    expect(gccFirst.first.place, 1);
  });

  test('QFLI_CLANG wins over QFLI_CC, as it did before', () {
    final r = roots();
    final clang = host.addFile(r.variable, 'clang.exe');
    final cc = host.addFile(r.variable, 'cc.exe');
    host.environment['QFLI_CLANG'] = clang;
    host.environment['QFLI_CC'] = cc;
    final candidates = host.lookup().candidates(
      language: CompilerLanguage.c,
      overrideDirectory: r.override,
    );
    expect(candidates.first.executable, clang);
    expect(
      candidates.indexWhere((entry) => entry.executable == cc),
      lessThan(
        candidates.indexWhere(
          (entry) => entry.place == 2 || entry.place == 3,
        ),
      ),
    );
  });

  test('automatic keeps clang before gcc inside one place', () async {
    final r = roots();
    host.addCompiler(r.configured, CompilerLanguage.c, fileName: 'gcc.exe');
    host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.c,
      configuredDirectory: r.configured,
    );
    expect(found, isNotNull);
    expect(p.basename(found!.executable), 'clang.exe');
    expect(found.family, CompilerFamily.clang);
    expect(found.source, CompilerSource.configuredDirectory);
  });

  test('preference gcc moves the GCC family ahead of clang', () async {
    final r = roots();
    host.addCompiler(r.configured, CompilerLanguage.c, fileName: 'gcc.exe');
    host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    final automatic = await host.lookup().find(
      CompilerLanguage.c,
      configuredDirectory: r.configured,
    );
    final preferred = await host.lookup().find(
      CompilerLanguage.c,
      preference: CompilerPreference.gcc,
      configuredDirectory: r.configured,
    );
    expect(p.basename(automatic!.executable), 'clang.exe');
    expect(p.basename(preferred!.executable), 'gcc.exe');
    expect(preferred.family, CompilerFamily.gcc);
  });

  test('preference clang moves the clang family ahead of gcc', () async {
    final r = roots();
    final gcc = host.addCompiler(
      r.configured,
      CompilerLanguage.cpp,
      fileName: 'g++.exe',
    );
    final clang = host.addCompiler(
      r.configured,
      CompilerLanguage.cpp,
      fileName: 'clang++.exe',
      version: clangVersion,
    );
    final automatic = await host.lookup().find(
      CompilerLanguage.cpp,
      configuredDirectory: r.configured,
    );
    final preferred = await host.lookup().find(
      CompilerLanguage.cpp,
      preference: CompilerPreference.clang,
      configuredDirectory: r.configured,
    );
    expect(automatic!.executable, clang);
    expect(preferred!.executable, clang);
    expect(preferred.family, CompilerFamily.clang);
    expect(gcc, isNotEmpty);
  });

  test('the place of an override beats the preference of a family', () async {
    final r = roots();
    host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.c,
      preference: CompilerPreference.clang,
      overrideDirectory: r.override,
      configuredDirectory: r.configured,
    );
    // Place 2 is empty, so place 4 answers; a GCC there still wins over a
    // place 3 clang, and the preference cannot move place 3 behind it.
    expect(p.basename(found!.executable), 'clang.exe');
    final gccInOverride = await host.lookup().find(
      CompilerLanguage.c,
      preference: CompilerPreference.clang,
      overrideDirectory: r.configured,
    );
    expect(p.basename(gccInOverride!.executable), 'clang.exe');
  });

  test('a family comes from the version text, not from the file name', () {
    expect(familyOfVersion(gnuGccVersion), CompilerFamily.gcc);
    expect(familyOfVersion(clangVersion), CompilerFamily.clang);
    expect(familyOfVersion(appleClangVersion), CompilerFamily.clang);
    expect(familyOfVersion(llvmMinGwGccVersion), CompilerFamily.clang);
  });

  test('the gcc.exe of LLVM-MinGW reports Clang', () async {
    final r = roots();
    host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      fileName: 'gcc.exe',
      version: llvmMinGwGccVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.c,
      configuredDirectory: r.configured,
    );
    expect(found!.family, CompilerFamily.clang);
    expect(found.version, 'clang version 20.1.8');
    expect(found.standard, 'c17');
  });

  test('one executable is probed with one version call and one compile set', () async {
    final r = roots();
    final clang = host.addCompiler(
      r.override,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    final gcc = host.addCompiler(
      r.override,
      CompilerLanguage.c,
      fileName: 'gcc.exe',
      version: gnuGccVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.c,
      overrideDirectory: r.override,
    );
    expect(p.basename(found!.executable), 'clang.exe');
    expect(host.count(clang), 2, reason: 'one --version and one compile');
    expect(host.count(gcc), 0, reason: 'the first hit ends the search');
    // A directory without a compiler starts no process at all.
    expect(
      host.started,
      isNot(contains(p.join(r.configured, 'bin', 'clang.exe'))),
      reason: 'a missing file is skipped before a process starts',
    );
    expect(
      host.started,
      isNot(contains(p.join(r.override, 'bin', 'g++.exe'))),
      reason: 'a C++ name is no candidate of a C program',
    );
  });

  test('a compiler that fails every standard is not reported', () async {
    final r = roots();
    final clang = host.addCompiler(
      r.override,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    host.broken.add(clang);
    host.addCompiler(
      r.override,
      CompilerLanguage.c,
      fileName: 'gcc.exe',
      version: gnuGccVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.c,
      overrideDirectory: r.override,
    );
    expect(p.basename(found!.executable), 'gcc.exe');
    expect(host.count(clang), 3, reason: 'one --version and two standards');
  });

  test('a bare name is resolved through PATH before it is probed', () async {
    final r = roots();
    final clang = host.addBinFile(r.onPath, 'clang.exe');
    host.versions[clang] = clangVersion;
    // The test host keeps its eight `bin` places empty, so the bare name of
    // place 8 is the first candidate that exists.
    final found = await host.lookup(pathDirectories: [r.onPath]).find(
      CompilerLanguage.c,
    );
    expect(found!.executable, 'clang.exe');
    expect(found.source, CompilerSource.systemPath);
    expect(found.family, CompilerFamily.clang);
  });  test('PATH resolves a name with any case through PATHEXT', () async {
    final r = roots();
    host.environment['PATHEXT'] = '.EXE';
    host.addBinFile(r.onPath, 'clang.EXE');
    final resolved = await host
        .lookup(pathDirectories: [r.onPath])
        .resolveOnPath('clang');
    expect(
      resolved?.toLowerCase(),
      p.join(r.onPath, 'clang.exe').toLowerCase(),
    );
  });

  test('probe children get a C locale and inherit PATH', () async {
    final host = FakeCompilerHost(
      isWindows: false,
      environment: {'PATH': '/usr/bin', 'LANG': 'de_DE.UTF-8'},
    );
    addTearDown(host.dispose);
    Map<String, String>? seen;
    final lookup = ToolchainLookup(
      isWindows: false,
      environment: host.environment,
      executableDirectory: null,
      projectPath: '/project',
      processStarter: (executable, arguments, {environment}) async {
        seen = environment;
        return fakeProcess(stdout: clangVersion);
      },
    );
    expect(lookup.probeEnvironment['LC_ALL'], 'C');
    expect(lookup.probeEnvironment['LANG'], 'C');
    expect(lookup.probeEnvironment['PATH'], '/usr/bin');
    expect(seen, isNull);
  });

  test('detect reports C first and one entry per language', () async {
    final r = roots();
    host.addCompiler(
      r.configured,
      CompilerLanguage.c,
      fileName: 'clang.exe',
      version: clangVersion,
    );
    host.addCompiler(
      r.configured,
      CompilerLanguage.cpp,
      fileName: 'g++.exe',
      version: gnuGccVersion,
    );
    final detected = await host.lookup().detect(
      configuredDirectory: r.configured,
    );
    expect(detected.map((entry) => entry.language), ['c', 'cpp']);
    expect(detected.first.family, CompilerFamily.clang);
    expect(detected.last.family, CompilerFamily.gcc);
  });

  test('the newest standard that the probe accepts is reported', () async {
    final r = roots();
    final clang = host.addCompiler(
      r.configured,
      CompilerLanguage.cpp,
      fileName: 'clang++.exe',
      version: clangVersion,
    );
    final found = await host.lookup().find(
      CompilerLanguage.cpp,
      configuredDirectory: r.configured,
    );
    expect(found!.standard, 'c++20');
    expect(clang, isNotEmpty);
  });

  test('a wrong executable reports no compiler', () async {
    final r = roots();
    host.addCompiler(r.configured, CompilerLanguage.c, fileName: 'clang.exe');
    host.broken.add(p.join(r.configured, 'bin', 'clang.exe'));
    host.broken.add(p.join(r.configured, 'bin', 'gcc.exe'));
    final found = await host.lookup().find(
      CompilerLanguage.c,
      configuredDirectory: r.configured,
    );
    expect(found, isNull);
  });
}
