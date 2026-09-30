# Android LLVM Toolchain

Build upstream LLVM 15.0.7 for Android with NDK 27.0.12077973. The source
commit is `8dfdcc7b7bf66834a761bd8de445840ef68e4d1a`; scripts verify it and
reject tracked content changes. Builds and generated packages live under
ignored `native/build/`. The scripts do not connect to or run a device.

## Prerequisites

- Windows, PowerShell, Git, Android SDK, NDK 27.0.12077973 and CMake 3.22.1.
- LLVM source in `native/build/llvm-project` at the pinned commit.
- Working LLVM 15.0.7 Windows `llvm-tblgen.exe` and `clang-tblgen.exe` in
  `native/build/llvm-host-msys2-working/bin`.
- Their MinGW DLLs in `native/build/msys64/mingw64/bin`. The build script
  stages DLLs in `native/build/llvm-host-tools` and restores the needed PATH
  for every incremental build.

Override paths with `-AndroidSdk`, `-BuildRoot`, `-SourceDirectory`,
`-HostBuildDirectory`, `-MsysRoot`, and `-TargetBuildDirectory` as needed.
One build job is the default because large LLVM units need substantial
memory. Keep enough free space for Windows' page file and process logs.

## Build And Package

From the repository root:

```powershell
./native/toolchain/build-android-llvm.ps1 -TargetArchitecture x86_64 -Jobs 1
./native/toolchain/package-android-llvm.ps1 `
  -TargetArchitecture x86_64 `
  -TargetBuildDirectory ./native/build/llvm-android-x86_64
```

Use `-TargetArchitecture arm64-v8a` for ARM64 with
`./native/build/llvm-android-arm64-v8a` as the package build directory.
Each ABI has a separate build directory. Existing CMake caches must match
the requested ABI, API level and NDK toolchain; caches without Android ABI/API
fields are rejected. API 21 is the default; pass the same
`-ApiLevel` to both scripts to change it. `-ConfigureOnly` runs capability
checks without building. Both C and C++ PIC probes must pass.

Packaging requires a fresh output for the selected ABI. It may share
`native/build/android-package` with an already packaged different ABI.
It strips the compiler, linker and executor and checks their architecture,
dynamic dependencies and 16 KB LOAD alignment. It generates:

```text
android-package/
  jniLibs/<abi>/libqfli_clang.so
  jniLibs/<abi>/libqfli-ld.lld-.so
  jniLibs/<abi>/libqfli_executor.so
  jniLibs/<abi>/libc++_shared.so
  assets/qfli_toolchain/<abi>.zip
  assets/qfli_toolchain/<abi>.zip.sha256
  resources/<abi>/toolchain.json
  resources/<abi>/sysroot/
  resources/<abi>/lib/clang/15.0.7/
  validation/<abi>/
```

The three `libqfli*.so` files are PIE executables with APK native-library
names. They must be extracted to the installed native library directory
and started from that read-only directory. Compiler and linker use static
libc++; generated C++ programs use the packaged `libc++_shared.so`.
The linker basename contains an exact `ld.lld` component between hyphens
because upstream LLD 15 derives its driver flavor from those components.

The resource archive contains Android C headers, the selected ABI/API's
startup objects and libraries, compiler-rt builtins, libunwind, libatomic, LLVM 15
builtin/C++ headers, and licenses. LLVM 15 C++ headers are configured for
Android's stable `__ndk1` ABI. Upstream Clang's `-lc++` is resolved by a
`libc++.so` linker script pointing to `libc++_shared.so`. Other ABI or API
library directories are omitted. Do not put SDK link-time stubs into
`LD_LIBRARY_PATH`; use the installed native-library directory instead.

## Local Validation

Every package cross compiles C17 and C++20 project-header fixtures,
compiles C helpers as C, and links C plus mixed C/C++ executables and shared
objects in both directions with undefined-symbol checks and 16 KB alignment.
It also cross links C `sin`/`exp` calls with nonconstant input using `-lm`.
Every shared fixture must export `main` in its dynamic symbol table for the
executor's `dlsym` call. It does not run
those outputs. Invalid C source and an omitted C helper must report the
expected compiler/linker errors. Diagnostics are retained under `validation/`.
The default validation compiler is the NDK's host Clang 18.
Pass `-ValidationCompiler <host-clang15.exe>` to verify LLVM 15 header and
driver compatibility. The manifest records the actual compiler version.

Resource headers are built before the full compiler. For early resource
validation during a long LLVM build, use a separate output directory:

```powershell
./native/toolchain/package-android-llvm.ps1 `
  -TargetBuildDirectory ./native/build/llvm-android-x86_64 `
  -OutputDirectory ./native/build/android-resource-check `
  -ResourcesOnly -ValidationCompiler C:/tools/llvm15/bin/clang.exe
```

`-ResourcesOnly` omits native binaries and cannot enable the app runtime.

## Executor Protocol

```text
libqfli_executor.so --exec <pidfile> <executable> [args...]
libqfli_executor.so --run <pidfile> <shared-object> <argv0>
```

Both modes set `PR_SET_PDEATHSIG`, check for a parent-death race, create a
process group and write their PID before invoking code. PID files must be
unique and absent when starting. The bridge cancels the negative PID to
kill the entire group. `--exec` replaces itself with the compiler/linker;
`--run` loads the generated shared object with `RTLD_NOW`, calls exported
`main(1, argv)`, flushes stdio and exits with the program's status. User
`exit`, abort and crashes occur in this separate process. Executor setup
and loading errors return 125 and print to stderr.

The app compiles each file as PIC with its own C/C++ language mode, then
links a shared object using the packaged linker. Keep `-Wl,-z,defs` so
unresolved user symbols fail during linking, and use
`-Wl,-z,max-page-size=16384` after driver defaults for generated programs.

## Android App Integration

The Android app consumes `native/build/android-package/jniLibs` and `assets`.
Override the package location with the Gradle property `qfliToolchainPackage`.
Run a local APK build after packaging both selected ABIs:

```powershell
flutter build apk --debug --target-platform android-arm64,android-x64
./native/toolchain/verify-android-apk.ps1 `
  -Apk ./build/app/outputs/flutter-apk/app-debug.apk
```

For an x86_64-only package, build with `--target-platform android-x64` and pass
`-TargetArchitectures x86_64` to the verifier. APK verification checks the actual
native ELF files after AGP stripping, resource archive hashes, compiler hashes,
Android interpreter, and 16 KB alignment. It does not install or run the APK.

`qfli_forge/native` methods `start` and `cancel` communicate with the Android
runner; `qfli_forge/native/events` carries per-run stdout, stderr and exit events.
Generated user code is loaded in a separate executable process. Project
`input.txt` feeds stdin. Compiler failures retain their diagnostics and status.
Projects containing any C++ source use C++ linking, including C main projects.

## Validation Boundary

A local package/APK build establishes source compilation, link correctness
and artifact layout. Android app-process execution, SELinux restrictions,
actual page-size behavior, input/output, cancellation and crash isolation
still require app/device validation. No local result should be described
as that runtime gate having passed.
