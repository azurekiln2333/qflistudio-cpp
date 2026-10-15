# Android refreshed release acceptance, 2026-10-16

The release APK was rebuilt after the owned curriculum repository change.
Acceptance is build/artifact inspection only: no Android install, push, ADB,
emulator or device debugging was performed. No Android source/signing change.

- Artifact: `native/build/android-release-20261016.apk`, also copied to
  `build/app/outputs/flutter-apk/app-release.apk`.
- 134332505 bytes; SHA256:
  `ec79aa536f49494acea16723ac20e5f52377415bce626352d276f3ca09301715`.
- Exactly ARM64 and x86_64; both complete compiler/linker/executor/STL resource
  sets pass `native/toolchain/verify-android-apk.ps1`, including archive/native
  hashes, ELF types/ABI/dependencies/loaders and 16 KiB LOAD alignment.
- Both bundled application curriculum JSON files match current source bytes.
- apksigner verifies v2; the existing Android Debug certificate is unchanged
  (`3cf19ed8102760001b3d92f3e4f42a6e322a89ba987d93247b5f9d6afebc0b51`).
- Shared core uses committed7768b91 from an isolated snapshot in this repository,
  as described in the OHOS portable acceptance record. Sibling unchanged.

The initial Flutter CLI attempt failed inside the installed SDK flutter.bat.
This SDK's shared.bat contains a `$git` token in a batch FOR command; the
wrapper exits -1. A direct Gradle attempt also selected the host default JDK25,
which Gradle8.14 rejects. Neither failed attempt is counted as acceptance.

Successful build: JBR21, Gradle8.14 assembleRelease, local ignored init script
`native/build/flutter-snapshot.init.gradle` redirects only Flutter task
executables to `native/build/flutter-snapshot.bat`, which calls the installed
Dart/flutter_tools snapshot directly. Arguments select android-arm64 and
android-x64, lib/main.dart, release and tree shaking. JVM is limited to 1536MiB
heap/512MiB metaspace to avoid concurrent Windows commit exhaustion. SDK and
sibling files are not edited. Result: BUILD SUCCESSFUL in 1m29s (146 tasks).

Logs: `native/build/android-portable-content-direct-release-20261016.log`,
`android-release-verify-20261016.log`, `android-release-signature-20261016.log`.
These warnings remain toolchain notices: SDK XML schema mismatch and existing
Gradle deprecations. They did not fail the successful build or artifact gates.
