# Android LLVM Runtime Contract

## 1. Scope / Trigger

Applies to Android LLVM build/package scripts, AndroidToolchain,
NativeCompilerBridge, and AndroidClangRunner. This bridge adds Android
compilation to the existing desktop backend without changing targetSdk.

## 2. Signatures

```powershell
./native/toolchain/build-android-llvm.ps1 [-TargetArchitecture x86_64|arm64-v8a] [-Jobs 1] [-ApiLevel 21] [-ConfigureOnly]
./native/toolchain/package-android-llvm.ps1 -TargetBuildDirectory <path> [-TargetArchitecture x86_64|arm64-v8a] [-ApiLevel 21] [-ValidationCompiler <host-clang15>] [-ResourcesOnly]
./native/toolchain/verify-android-apk.ps1 -Apk <path> [-TargetArchitectures arm64-v8a,x86_64]
```

Gradle property `qfliToolchainPackage` points to the generated package directory;
default: `native/build/android-package` relative to the repository root.

MethodChannel `qfli_forge/native` exposes:

- `start({runId: String, type: 'c'|'cpp', projectPath: String, entryFile: String})`
  returns `{available: bool}`. Paths must identify a readable project and entry.
- `cancel({runId: String})` cancels that accepted run.

EventChannel `qfli_forge/native/events` emits:

```json
{"runId":"android-1","kind":"stdout","text":"42"}
{"runId":"android-1","kind":"stderr","text":"main.c:2: error: ..."}
{"runId":"android-1","kind":"exit","exitCode":0}
```

## 3. Contracts

- LLVM 15.0.7 source commit is pinned to
  `8dfdcc7b7bf66834a761bd8de445840ef68e4d1a`; NDK is 27.0.12077973.
- Host TableGen requires its staged MinGW DLL PATH. Never overwrite a changed
  source tree or reuse an ABI/API-mismatched target cache.
- Native package filenames: `libqfli_clang.so`, `libqfli-ld.lld-.so`,
  `libqfli_executor.so`, and `libc++_shared.so`, under `jniLibs/<abi>/`.
- These libqfli files are PIE executables installed with native extraction.
  Compiler executables run from the installed read-only native directory.
- LLD 15 needs the `ld.lld` basename component between hyphens to select ELF.
- Assets `qfli_toolchain/<abi>.zip` contain `toolchain.json`, `sysroot/`, and
  `lib/clang/15.0.7/`. Manifest fields `targetTriple`, `apiLevel`, and
  `resourceDirectory` are consumed by Kotlin.
- Use LLVM 15 libc++ headers configured for Android's `__ndk1` ABI. Include
  Android libraries/startup objects, libunwind, libatomic and compiler-rt
  builtins. Upstream Clang's `-lc++` needs the packaged libc++.so link script.
  Always link `-latomic -lm`; pure C mode does not add libm implicitly.
- User C and C++ files compile separately as PIC with C17/C++20 respectively.
  Any C++ translation unit selects C++ linking, including projects with C main.
- Link generated code as a shared object with `-Wl,-z,defs` and 16 KB segment
  alignment (`max-page-size` and `common-page-size`, including RELRO); mark it
  read-only before loading. A separate executor loads the
  library and calls exported main.
  The Flutter process must never execute user main directly.
- Executor creates a process group, writes PID before invoking user/compiler
  code, and preserves stdio and exit status. Cancellation targets that group.
- LD_LIBRARY_PATH contains only installed native libraries, never sysroot
  link-time stubs. ProcessBuilder uses argument arrays, without a shell.
- Subscribe before start; filter by runId; preserve empty output lines. Exit
  follows drained stdout and stderr. Accepted runs emit one terminal event.
- `available:false` permits the existing C fallback. Accepted compilation,
  linking and runtime errors must never silently switch to the interpreter.
- Build/package success is local evidence. Device execution remains unverified
  until tested through the app, not just through a device shell.

## 4. Validation & Error Matrix

| Condition | Required Behavior |
| --- | --- |
| Missing host tools, SDK files, source version mismatch | Stop with actionable path/version error |
| ABI or API cache mismatch | Reject before building |
| Required native executables/assets absent | Return available:false |
| Another run active | Return runner_busy without replacing it |
| Compiler or linker returns nonzero | Stream diagnostics and preserve status |
| Program exits or crashes | Preserve child status, keep app process alive |
| Cancel during compile/run | Kill process group and report 130 |
| Invalid bridge event or disconnected stream | Close streams and terminate native work |
| Windows pagefile/disk exhaustion | Treat as environment failure, never source success |

## 5. Good / Base / Bad Cases

- Good: local artifact checks plus actual app C/C++ run, errors and cancel are
  independently verified on each supported ABI/page size.
- Base: artifacts cross-link and APK builds; app/device execution is explicitly
  deferred because the user requested no debugging.
- Bad: using OHOS binaries on Android, reducing targetSdk to allow writable
  execve, or claiming runtime availability solely from a successful APK build.

## 6. Tests Required

- PowerShell scripts parse. C/C++ PIC probes pass. ELF machine, dependencies,
  and every LOAD segment satisfy the selected ABI and 16 KB alignment.
- Cross-link C17, C++20 stdlib and mixed C/C++ project-header fixtures with
  the packaged sysroot; record validation compiler version.
- Dart tests cover output before start reply, runId filtering, empty lines,
  accepted errors, missing toolchain/plugin, cancel, malformed events and
  channel failure. Static analysis and Android Kotlin compilation pass.
- APK inspection confirms native files and resource archives are packaged.
  Verify unchanged compiler/linker/executor hashes against the archived
  manifest, resource archive SHA256, and actual ELF ABI/dependencies/16 KB
  alignment after AGP stripping. Executables require /system/bin/linker64.
- Later device gate: stdin, multi-file C/C++, C entry with C++ helper, compile
  and link errors, nonzero exit, crash isolation and cancellation of children.

## 7. Wrong vs Correct

Wrong: mark the runtime verified after cross-linking fixtures on Windows.
Correct: record local cross-link/APK results separately from actual app execution.

Wrong: kill only the compiler leader while its child linker retains stdout.
Correct: cancel its process group, drain/close both pipes, then emit one exit.
