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
- ZIP entry names must use `/` on every host. Windows PowerShell 5 uses .NET
  Framework, whose `ZipFile.CreateFromDirectory` emits backslash paths. Create
  entries explicitly with normalized names; Android treats backslashes as
  filename characters, so header extraction otherwise fails.
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
- Android Process.destroy() closes its pipes. After a natural child exit, kill
  remaining process-group children without destroying the completed Process;
  await both readers before closing streams. Use exitValue() for API 24
  compatibility; destroy only while it still throws IllegalThreadStateException.
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
- Package with Windows PowerShell 5 and verify the resulting APK; every resource
  entry must reject backslashes and include `sysroot/usr/include/stdio.h`.
- Later device gate: stdin, multi-file C/C++, C entry with C++ helper, compile
  and link errors, nonzero exit, crash isolation and cancellation of children.
- `tool/android_native_audit.dart` exercises the actual packaged engine, without
  C fallback. Build/install it under a distinct application ID and require the
  QFLI_C_ANDROID_AUDIT ok:true marker. Its eight x64 cases passed on API 37 with
  16 KiB pages after fixing the pipe race. Before the fix, C++ printed the correct
  result but an InterruptedIOException during pipe draining produced exit 127.
  The ordinary owning debug APK separately passed project creation and editor
  Run: AndroidCppNative/src/main.cpp reports Android Clang cpp, prints
  Hello, QFLIStudio+! and exits 0 on API 37 with 16 KiB pages. Its native files
  and compiler resources passed APK audits. A fresh task-owned emulator-5562
  was used after the original emulator-5560 rejected both ordinary APK variants
  for insufficient storage; no ordinary application data was removed. ARM
  device execution remains unverified.

## 7. Wrong vs Correct

Wrong: mark the runtime verified after cross-linking fixtures on Windows.
Correct: record local cross-link/APK results separately from actual app execution.

Wrong: kill only the compiler leader while its child linker retains stdout.
Correct: cancel its process group, drain/close both pipes, then emit one exit.

## 8. Android Startup

- `qfli_forge/startup` accepts `startupProgress({progress: double})`. Require a
  finite number, clamp to 0..1 and update the native progress bar. Invalid data
  returns `invalid_progress`; unknown methods remain unimplemented.
- AndroidStartup holds the first frame before runApp. AppBootstrap reports
  actual completion of project/auth/settings loads. After bootstrap, await
  endOfFrame for home layout, then allowFirstFrame in finally, including errors.
- Keep the native icon/progress overlay until onFlutterUiDisplayed, then fade
  it out. A progress value of 1 alone must never remove it. The progress channel
  is optional and its errors must not block startup.
- RenderMode.texture allows the native loading UI to draw during deferred
  Flutter rendering. Surface mode installs an Android pre-draw blocker that
  also hides the native progress bar.
- Light/dark launch, normal and overlay backgrounds match shared AppTheme:
  #F8F9FF / #111418. Android 12+ also configures its system splash background.
  Retain system/cutout insets and fit the progress bar within 32 dp side margins
  and a 420 dp maximum width. No fixed bootstrap wait is required.
- Tests must hold rendering during pending loads, release only after home
  layout, release on load failure, and tolerate absent/failing progress channels.
  Verify Kotlin/resources through local build/lint. Device visual checks remain
  deferred under the user's instruction to avoid debugging.
