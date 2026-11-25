# Desktop C/C++ Runtime Contract

## 1. Scope / Trigger

Applies to lib/clang_runner.dart, its real desktop execution tests, and
native/toolchain/verify-linux-desktop.sh. Desktop runtime means native compiler
and program processes supervised by the shared ProcessSupervisor.

## 2. Signatures

```dart
ClangProgramRunner({ProcessSupervisor? supervisor, String? toolchainDirectory});
Future<ProgramRunResult?> run({required String projectPath, required String entryFile});
```

```sh
CC=cc CXX=c++ bash native/toolchain/verify-linux-desktop.sh
CC=clang-15 CXX=clang++-15 bash native/toolchain/verify-linux-desktop.sh
```

The Linux verifier executes compiler/program fixtures independently. It does
not execute Flutter or validate the macOS/iOS application shell.

## 3. Contracts

- Discover all .c/.cpp/.cc/.cxx translation units irrespective of entry suffix.
- Use the C++ linker if any C++ unit exists, including a C main project.
- Compile each .c unit as C; use explicit -x c or -x c++ so case-insensitive
  file discovery does not depend on compiler extension inference.
- Preserve per-driver standard probes: C17/C11 and C++20/17/14/11.
- Compiler discovery preserves environment overrides QFLI_CLANG/QFLI_CLANGXX,
  QFLI_CC/QFLI_CXX, QFLI_TOOLCHAIN_HOME, constructor root, bundled toolchain/bin,
  Windows Dev-Cpp paths and PATH candidates, in existing precedence.
- Keep project root and optional include/ header paths as argument-array entries.
- Link libm after object files on Linux; do not assume libm is implicit for C.
- Feed input.txt to the program, close stdin, and preserve stdout/stderr and
  normal program exit status separately from compiler/link diagnostics.
- Compilation/link errors do not launch any stale output binary.
- Accepted cancellation returns 130 after process cleanup. Normal exit retains
  the program status. A cancel call after terminal completion is idempotent.
- A live process must be cleaned up even when output decoding or stdin fails.
- Unavailable toolchains/startup failures use kProgramNotRunExitCode (127).

## 4. Validation and Error Matrix

| Condition | Required behavior |
| --- | --- |
| No matching entry family | Return null for the next backend |
| No desktop compiler | Report unavailable; preserve existing routing policy |
| C units in a C++ project, no usable C driver | Report missing C compiler |
| Compile or link failure | Stream diagnostics, preserve failure status, no program launch |
| Native program exits nonzero | Preserve stderr and the actual exit status |
| Cancel during accepted work | Stop supervised process, complete with 130 |
| Output/stdin error after launch | Stop remaining process and close result streams |

## 5. Good / Base / Bad Cases

- Good: C main with C-only syntax links a C++ stdlib helper; both source and
  program paths include spaces; a cancel test proves no active processes remain.
- Base: Linux CLI fixtures pass, but the Linux Flutter application is explicitly
  unverified because its SDK is absent.
- Bad: claim mixed-language support only from a C++ main calling C; omit the
  reverse direction or depend on filename .C being inferred as C by the driver.

## 6. Tests Required

- Real desktop runner: multi-file C/C++, headers, both mixed directions,
  uppercase source extensions, runtime-valued math, input.txt, independent stderr,
  nonzero exits, compile diagnostics, link failure after a previous successful
  binary, sequential stream consumption, and cancel exit 130 with cleanup.
- Linux CLI: reuse test/fixtures/desktop_native; validate outputs/errors/status,
  libm-dependent C input, C and C++ language modes, and native SIGTERM cleanup.
  Linux shell signal status 143 is not Dart adapter exit 130.
- Flutter analyze and existing platform-channel tests must remain green.
- Skip unavailable macOS/iOS/device execution; record the specific limitation.

## 7. Wrong vs Correct

Wrong: derive the project linker from main.c and omit helper.cpp.
Correct: collect all units, compile each with its language, and link through C++
when the project contains C++.

Wrong: return the OS kill status as an accepted cancellation result.
Correct: finish process cleanup and return the runner's cancellation status 130.
