# Non-OHOS Runtime Audit

## Scope and Evidence

This audit covers the current Forge repository. The user has approved task
creation. Whether the request includes sibling language apps remains pending;
the presence of those apps beside this repository does not establish intent.

The Forge profile exposes C and C++ only (`lib/main.dart:29`). Runner routing is
Clang first, then native/Dart C, then the C++ delegate (`lib/forge_runner.dart:27`).

| Platform | Existing execution path | Gap | Local verification capability |
| --- | --- | --- | --- |
| Android | Packaged LLVM process and isolated shared-object executor | Already integrated in the archived mobile task; device behavior remains unverified | Android build tools are present; no device runs requested in this task |
| Windows | Native Clang/GCC CLI via Dart ProcessSupervisor | C entry omits C++ units; delivery requires installed/bundled toolchain | GCC/G++ are present and real existing runner tests pass |
| Linux | Same native Clang/GCC CLI | Same mixed-source gap; investigate missing math link dependency | WSL qfli-java-build has GCC/G++ 13.3.0 and CMake; Linux Dart/Flutter absent |
| macOS | Same native Clang/GCC CLI | Same shared source-discovery gap; signing/sandbox behavior unverified | Apple host and Xcode unavailable; skip Apple execution tests |
| iOS | No Forge/native C channels; Dart C fallback only | Native C missing, C++ unavailable; requires a platform-appropriate execution design | Xcode/iOS device unavailable; skip native build/runtime tests |
| Web | Generated scaffold, desktop/mobile file abstractions | No browser project storage or native/WASM execution backend | Browser present; complete app runtime is not implemented |

## Desktop Findings

### Confirmed Mixed-Language Defect

`lib/clang_runner.dart:43` chooses project language from the entry extension.
`lib/clang_runner.dart:186` passes this choice to `_collectSources`.
`lib/clang_runner.dart:353` collects only `.c` for a C entry; the C++ branch also
collects `.c`. Therefore only one direction of mixed C/C++ is implemented.

The fix belongs in project source discovery and linker selection. Collect both
source families, compile each translation unit with its own driver, and select
the C++ linker if any C++ unit exists. Android already does that at
`android/app/src/main/kotlin/com/example/qflistudio/c/NativeCompilerBridge.kt:166`.
Do not duplicate a native platform channel on desktops merely to invoke the
compiler they already execute.

### Math Link Dependency to Verify

`lib/clang_runner.dart:241` links only object files and the output path. On Linux
libm normally requires an explicit `-lm` after the objects. Use a runtime-valued
math expression in a real fixture to avoid constant folding masking the bug.
Android already links `-lm` (`NativeCompilerBridge.kt:170`). macOS math is part
of libSystem; do not assume a Linux-specific flag is a missing macOS library.

### Existing Contracts

- Compiler discovery supports environment overrides, toolchain roots, bundled
  `toolchain/bin`, Windows Dev-Cpp and PATH (`lib/clang_runner.dart:72`).
- Standards are compile-probed: C17/C11 and C++20/17/14/11
  (`lib/clang_runner.dart:136`).
- Translation units are compiled separately and diagnostics are streamed.
- `input.txt` is sent to stdin (`lib/clang_runner.dart:268`).
- Compilation/link failures stop before program launch.
- Process lifetime and cancellation use the sibling ProcessSupervisor;
  a source-discovery correction should retain that existing ownership.
- If no desktop compiler exists, the runner reports unavailable. It does not
  currently fall through to the Dart C interpreter (`lib/clang_runner.dart:55`).

## Baseline Verification, 2026-10-01

Command from repository root:

```powershell
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' `
  'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot' `
  test --no-pub --concurrency=1 test/clang_runner_test.dart
```

Result: all six existing tests passed with real native compiler execution.
They cover multi-file C/project headers, C++ standard library, C++ main with C
helper, compile diagnostics, the legacy C++ delegate, and sequential stream
consumption. They do not cover C main with C++ helper or Linux libm.

Linux inspection: `qfli-java-build` starts successfully and has `/usr/bin/cc`,
`/usr/bin/c++` (GCC 13.3.0), `/usr/bin/cmake`, curl and xz. Its `dart` and `flutter`
PATH entries point to `/mnt/d/ProgramFiles/flutter_ohos`, containing Windows
`.exe` tools, not a Linux SDK. Do not call Windows Dart tests Linux verification.

Ubuntu cannot start: WSL reports its registered VHDX missing. Use the working
distribution without modifying or unregistering the user's Ubuntu setup.

## Planning Boundaries

Expected Forge product ownership is `lib/clang_runner.dart`, its focused tests,
native platform build/runtime integration selected during planning, and runtime
documentation. Sibling shared-core changes are a separate ownership boundary.

Preserve dirty OHOS files and unrelated project configuration. Do not run OHOS
device debugging. Do not claim Apple runtime support from source inspection or
claim device verification from successful Android packaging.
