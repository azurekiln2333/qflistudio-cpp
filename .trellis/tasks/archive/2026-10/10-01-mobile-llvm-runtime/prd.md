# Android LLVM Runtime

## Goal

Integrate a real LLVM C/C++ compiler and runtime into the Android Forge app.

## Requirements

- Support C17 and C++20, standard libraries, project headers, multiple source
  files, and mixed C/C++ projects.
- Preserve input.txt, stdout, stderr, compile/link errors, program exit status,
  and cancellation in the existing run UI.
- Use Android binaries and its sysroot; retain the current target SDK.
- Continue Android only. The user stopped HarmonyOS work and device debugging.
- Use local builds and focused tests. Clearly distinguish local verification
  from device execution, which is not authorized in this session.
- Commit coherent changes with conventional messages; do not push.
- Follow the reference qflistudio native startup flow on Android: show real
  bootstrap progress and retain the native layer until the home frame renders.

## Acceptance Criteria

- [x] Reproducible pinned LLVM Android build/package scripts produce validated
  compiler and linker binaries, headers, libraries, and a standalone executor.
- [x] Android app has a native run bridge with asynchronous output and cancel.
- [x] C and C++ source files are compiled with the correct language mode;
  linking supports project headers and the C++ standard library.
- [x] Dart bridge tests and Flutter static analysis pass.
- [x] Android APK builds locally with the toolchain packaged.
- [x] Report explicitly records that device execution has not been verified.
- [x] Android startup uses a native progress layer and matching light/dark
  launch backgrounds; Flutter presents its initialized home frame before removal.

## Deferred Validation

Actual app execution, Android SELinux compatibility, and behavior on 16 KB
devices require later device validation. No emulator installation, adb, hdc,
or device debug sessions are part of this task.
