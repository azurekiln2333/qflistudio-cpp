# Work package ENV-CORE: desktop toolchain environment and one-click setup

Read `wp-common.md` first.

- Worktree: `D:/MyNewProjects/_wt/qfli_c-wp-env-core` (branch `wp/env-core`)
- Report: `reports/wp-env-core.md`

## Why

The user wrote: "windows linux macos 在软件设置内能不能加个环境配置的？？
能不能加上一键配置clang、gcc环境的". On desktop the application compiles C and
C++ with a compiler of the computer. When none is present, a run ends with
`未找到可用的 C/C++ 编译工具链。` and the application offers no way forward.
The user wants a place in the application that shows and configures the
compiler environment, and one button that makes clang or gcc usable.

You build the logic. Package ENV-UI builds the page at the same time against
the same interface. Neither of you sees the other's code before integration.

## Read before you write

- `lib/toolchain/toolchain_environment.dart`: the frozen interface. Do not edit
  it. When a defect in it blocks you, write the defect into the report, choose
  the smallest workaround inside your own files, and continue.
- `lib/clang_runner.dart`: the lookup and the run of today.
- `D:/MyNewProjects/qfli_c/.trellis/spec/backend/desktop-runtime.md`: the
  runner contract. Every rule in it stays valid.
- `lib/forge_runner.dart` and `lib/platform/`: how this application keeps
  `dart:io` out of the web build.
- Core, read only: `AppPaths` and `ProcessSupervisor` under
  `D:/MyNewProjects/_wt/qfli_studio_core/lib/`.

## Owned files

- `lib/toolchain/**` except `toolchain_environment.dart`
- `lib/clang_runner.dart`
- `test/toolchain_*_test.dart` (new)
- `test/clang_runner_test.dart` (existing: extend it, do not weaken it)

`pubspec.yaml` already holds `crypto` for the SHA-256. Do not edit it.

## Result 1: the environment object

`forgeToolchainEnvironment` in `lib/toolchain/local_toolchain_environment.dart`
is a stub now. Make it real.

- The file is imported by `lib/forge_tools_page.dart`, which compiles for the
  web. So the file must compile for the web, and `supported` is false there.
  Use the mechanism of `lib/forge_runner.dart`. Make no `Platform` call before
  a web guard.
- `supported` is true on Windows, Linux and macOS, and false elsewhere. When
  it is false, no member starts a process, opens a file or uses the network.
- Settings: one JSON file in the storage directory of the application
  (`AppPaths.storageDirectory()`). A missing or damaged file gives the
  defaults. Write through a temporary file and a rename.
- Managed toolchains live under the storage directory (for example
  `toolchains/<option id>/`). Never write beside the executable, and never
  change `PATH`, the registry or a shell profile of the user.
- Tests must not touch the network, the real storage directory or the real
  environment. Give the class the seams it needs for that (storage directory,
  platform, environment variables, process start, HTTP), with production
  defaults.
- Network use happens only inside `runSetup`, after the user confirmed in the
  page. No background check, no update check, no telemetry.

## Result 2: one lookup for the page and the runner

`detect()` and the runner share one candidate list. The page must never show a
compiler that a run does not use.

Order (check it against the code; the relative order of today's places wins
when this list disagrees):

1. `QFLI_CLANG`, `QFLI_CLANGXX`, `QFLI_CC`, `QFLI_CXX` → `environmentVariable`
2. the `toolchainDirectory` constructor argument of the runner (tests)
3. `QFLI_TOOLCHAIN_HOME` → `knownLocation`
4. `settings.directory` → `configuredDirectory` (new)
5. managed toolchains → `managedInstall` (new)
6. `<executable directory>/toolchain` → `knownLocation`
7. the Windows Dev-Cpp directories → `knownLocation`
8. `PATH` → `systemPath`

- Places 1 to 3 are overrides for developers and tests. The preference does
  not reorder them.
- Preference `automatic` keeps today's order inside each place (clang, then
  gcc). Preference `clang` or `gcc` moves every compiler of that family ahead
  of the other family across places 4 to 8.
- Take the family from the `--version` text, not from the file name:
  LLVM-MinGW ships a `gcc.exe` that is Clang, and `gcc` on macOS is Apple
  Clang.
- Each probe compiles a program, with a timeout of 20 seconds today. Keep
  `detect()` responsive: probe no executable twice, and think about a computer
  with six candidates.

## Result 3: the runner

- `ClangProgramRunner()` without arguments uses the shared environment.
  `ForgeProgramRunner` builds it that way, and you cannot edit that file.
- A changed setting or a finished setup takes effect at the next run, without
  a restart of the application. Check what the runner caches.
- The existing constructor parameters keep their meaning. The existing tests
  pass unchanged.
- Missing compiler on desktop: the message becomes exactly
  `未找到可用的 C/C++ 编译工具链。请在工具页打开「环境配置」。` (ENV-UI names
  its entry `环境配置`). Android, iOS and OHOS keep their messages.
- A program that a toolchain outside `PATH` built must start. MinGW GCC links
  `libstdc++-6.dll`, `libgcc_s_seh-1.dll` and `libwinpthread-1.dll`
  dynamically. LLVM-MinGW links `libc++.dll` and `libunwind.dll`. Without the
  toolchain `bin` directory on the `PATH` of the child, Windows ends the
  program with exit code `0xC0000135` and no output. Solve it for the run step
  (a `PATH` prefix for the child through the `environment` parameter of
  `ProcessSupervisor.start`, or static linking) and prove it in the
  end-to-end check. Mind the two spellings `Path` and `PATH` on Windows.

## Result 4: one-click setup

`setupOptions()`, `runSetup()`, `cancelSetup()`, `remove()`. `detail` holds
the exact command, or the exact address and the target directory. The page
shows it before the user confirms.

### Windows (no administrator rights)

- Option Clang: LLVM-MinGW (`github.com/mstorsjo/llvm-mingw`), the
  `ucrt-x86_64` zip. It is self-contained: clang, lld, libc++, the mingw-w64
  headers and libraries. It needs no Visual Studio.
- Option GCC: a real GNU GCC for x86_64 Windows with UCRT. Candidates: WinLibs
  (`github.com/brechtsanders/winlibs_mingw`, a variant without LLVM) and
  w64devkit (`github.com/skeeto/w64devkit`). Choose the smallest download
  that compiles C and C++ and that a plain Windows 10 can unpack with on-board
  tools. The main session did not measure the sizes. Expect hundreds of
  megabytes on disk. Put the measured numbers into `detail` and
  `downloadBytes`.
- Pin each archive: exact release address, size in bytes and SHA-256 as
  constants. You compute the SHA-256 from your own download. That is
  trust-on-first-use: say so in a comment and in the report. Compare with a
  checksum of the project when one exists.
- Flow: download to a `.part` file under the storage directory with progress
  (`received`, `total`) → compare size and SHA-256 → unpack into a temporary
  directory beside the target → rename to the final directory → write a
  marker → `detecting` → `done`. A failure or a cancel at any step leaves no
  directory that `setupOptions()` reports as installed.
- Unpacking: `%SystemRoot%\System32\tar.exe` is bsdtar. On this computer it
  reports `bsdtar 3.8.4 - libarchive 3.8.4 zlib/1.2.5.f-ipp`: it reads zip,
  but not xz and not 7z. `tar` in Git Bash is GNU tar, a different program.
  Use the absolute System32 path.
- Check the free disk space before the download.
- The storage path can hold spaces and non-ASCII characters (Windows user
  names). Verify one compile and one run with such a path, or report it as not
  verified.
- HTTP: `dart:io` `HttpClient`. Release files redirect to another host. Use a
  connect timeout and a stall timeout. A network error ends with `failed` and
  a short Chinese message. Many users of this application reach GitHub
  slowly: a long download must show progress and must stay cancellable. Resume
  of a partial download is welcome when it is cheap. It is not required.
- `remove()` deletes a managed toolchain and notifies the listeners.

### Linux (administrator rights through `pkexec`)

- Find the package manager by its executable: `apt-get`, `dnf`, `pacman`,
  `zypper`. Offer the options GCC and Clang with `needsAdministrator: true`.
  Expected commands (check them against the documentation you can reach):
  `apt-get install -y gcc g++` / `clang`, `dnf install -y gcc gcc-c++` /
  `clang`, `pacman -S --needed --noconfirm gcc` / `clang`,
  `zypper --non-interactive install gcc gcc-c++` / `clang`.
- Send the output lines as `running` messages.
- Without `pkexec` or without a known package manager, no action can run.
  Decide what the list shows then, and record the decision.
- `installed` is true when `detect()` finds that family on the system path.

### macOS

- Option "Xcode 命令行工具" runs `xcode-select --install`. The command opens a
  system dialog and returns at once. Say that in the progress messages: the
  user finishes the dialog, then detects again. `xcode-select -p` tells
  whether the tools are present.
- A real GCC on macOS exists only through Homebrew (`gcc-<N>`, `g++-<N>`).
  Offer it only when `brew` exists. It has the last priority: leave it out
  when time is short, and say so.
- The macOS runner is sandboxed: `macos/Runner/Release.entitlements` holds only
  `com.apple.security.app-sandbox`. Nobody here can test whether a sandboxed
  application may run `/usr/bin/clang` or `xcode-select --install`. Do not edit
  the entitlements. Write into the report what you expect and why.

## Tests

- Settings: round trip, missing file, damaged file.
- Lookup: the order of the eight places, the three preference values, no
  double probe, the family from `--version` samples (GNU GCC, Clang, Apple
  Clang, the `gcc.exe` of LLVM-MinGW).
- Setup on Windows against a loopback `HttpServer` with a small zip:
  success, wrong SHA-256, wrong size, connection drop, cancel during the
  download, cancel during unpacking, second `runSetup` while one runs, `remove`.
  After each failure no installed directory and no `.part` file remains.
- Setup options per platform with an injected platform and injected
  executables: Linux with each package manager, Linux without `pkexec`, macOS
  with and without the command-line tools.
- Runner: the default constructor reads the shared settings, a setting change
  applies at the next run, the missing-compiler message on desktop.
- `flutter test` blocks real HTTP once the widget test binding is initialized.
  Write the network tests so that they reach the loopback server.

## End-to-end check on this computer (Windows 10 x64)

Run the real flow once for each Windows option, with a temporary storage
directory whose path holds a space and a Chinese character: real download,
SHA-256, unpack, detect, then compile and run one C program and one C++ program
that uses `<iostream>`, through `ClangProgramRunner`. Put the check into an
opt-in test (for example guarded by `QFLI_TOOLCHAIN_E2E=1`), so a normal
`flutter test` stays offline. Record sizes, durations and the output in the
report. When a download does not finish within 20 minutes, stop it, report the
measured speed, and say what stays unverified.

Nobody here can run the Linux and macOS actions. Cover them with the injected
tests, and write "not verified on a real computer" for them in the report.

## Checks before the report

- `flutter analyze` reports no issues for the whole project.
- `flutter test` passes. Give the test count before and after.
- `git status --short` lists owned files only.
