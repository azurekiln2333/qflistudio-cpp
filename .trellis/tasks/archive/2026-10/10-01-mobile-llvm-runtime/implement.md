# Implementation Plan

- [x] Recover existing work and scope to Android with no device debugging.
- [x] Build/package x86_64 Android LLVM and executor with a pinned local NDK.
- [x] Finish ARM64 Android LLVM build/package.
- [x] Add Android runtime bridge, extraction, compilation, output and cancel.
- [x] Add streaming Dart client and focused bridge contract tests.
- [x] Validate x86_64 toolchain artifacts and build Android APK locally.
- [x] Build and verify the final APK containing ARM64 and x86_64.
- [x] Run Flutter tests/analyze and application change review.
- [x] Complete final native build/package review and APK inspection.
- [x] Record local evidence and deferred device checks, then commit changes.
- [x] Reference qflistudio native progress and wire Android's first-frame gate.
- [x] Validate startup timing/failure cases, Android resources and final APK.

Code commits: a3c1d4b (toolchain build/package/APK verification) and 2a16d36
(Android runtime bridge, streaming client, tests, and executable contracts).
Final follow-up commits: 398b093 (portable Android ZIP paths) and 4f86187
(native progress layer and first-frame startup gate).

## Validation

Final local evidence: all 56 root Flutter tests passed, including 12 Android
runner cases and four startup cases. Flutter analyze reported no issues.
Startup tests hold frames during pending data loads, present the home layout
before release, release after load failure, and tolerate an absent or failing
progress channel. Android Kotlin/resources and final assembleDebug passed with
one Gradle worker and a 2 GB JVM heap.

Both actual Android LLVM compiler/linker builds finished. Windows PowerShell 5
full packaging passed for each ABI: eight cross-linked fixtures (C17, C++20,
mixed C/C++, project headers and nonconstant C sin/exp), four dynamically
exported main symbols and two expected compile/link failures. Link flags use
-latomic -lm and both 16 KB max-page-size/common-page-size settings. Generated
programs become read-only before loading.

Final APK: build/app/outputs/flutter-apk/app-debug.apk, 189,218,686 bytes.
SHA256: 883c7ee2c18690535dce71fa8c80e67cdfcf5941bc4ce3373c8b57d8ae1f76c3.
Windows PowerShell 5 APK verification passed for all eight native ELF files,
matching resource/native hashes, standard headers, Android loader and 16 KB
alignment after Gradle stripping. aapt2 confirms minSdk24, targetSdk36,
extractNativeLibs=true, and native-code arm64-v8a/x86_64. Compiled startup layout
contains the centered 96 dp icon and 4 dp native determinate progress bar.
Final Android lint passed with zero errors and one existing drawable-v21
directory warning. The new InflateParams warning was fixed by inflating the
startup overlay with its actual content parent, followed by APK rebuild and
verification.

Final package resides in native/build/android-package. Archive SHA256:
- x86_64: 3d4e59492ec9e2077101f127bfc32f0b1c040d00108291374f4844cf3561c276
- arm64-v8a: 0ea6f56851c8f79dd8c4b140c9a1da2c95ea352d34259efd054ed985cba3baa5

Final APK verification caught .NET Framework CreateFromDirectory using
backslashes in ZIP entry names. Packaging now creates explicit slash-normalized
entries and imports both compression assemblies. The verifier rejects the
old malformed APK and passes the re-packaged one. Older generated packages
were preserved as backups; no existing files were deleted.

Device execution, startup visuals, SELinux, real page-size behavior and native
program execution remain unverified. No adb, hdc, emulator, flutter run or app
installation was performed in this Android-only continuation.

Android lint's PropertyEscape gate requires escaping the drive colons in
ignored local.properties after Flutter assemble, which rewrites that file.
Lint was verified with compileFlutterBuildDebug excluded after a successful
Kotlin/Flutter compilation, avoiding any source suppression or lint baseline.

Parse PowerShell scripts; inspect target CMake PIC probes, ELF headers and
dynamic dependencies. Cross compile/link fixture C and C++ projects against
the packaged sysroot. Run Flutter test/analyze through the local flutter_tools
snapshot and build the APK. Inspect APK entries for compiler/linker/executor
and asset archive. Do not run adb, hdc, flutter run, or install the APK.

## Rollback

Keep Android additions scoped to the bridge and generated package integration.
Retain desktop implementation and C fallback when no Android toolchain exists.
Do not touch user changes under ohos/.
