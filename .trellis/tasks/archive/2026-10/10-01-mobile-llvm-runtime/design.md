# Android Native Runtime Design

## Boundaries

The mobile gap is in lib/clang_runner.dart and Android MainActivity: the Dart
runner calls a MethodChannel with no Android implementation. Native scripts
currently produce OHOS artifacts only. Add Android-specific build/package
scripts, an Android runtime bridge, and a streaming Dart client.

## Execution

Package Android compiler, linker, and a small executor as lib*.so files in the
APK native library directory, with native extraction enabled. These ELF
executables run from the installed, read-only directory. Extract only headers,
link-time libraries, and compiler resources from assets to internal app storage.
Compile user files as PIC objects and link a shared object with exported main.
The packaged executor loads the generated object with dlopen, invokes main,
flushes stdio, and returns the program status. Compiler and user code run outside
the Flutter process. This keeps current targetSdk and isolates exit/crashes.

The executor creates a process group and records its PID before exec/loading.
Cancellation kills the group, including compiler/linker children. No shell
command string is used. File paths and compiler options are argument arrays.

This design needs later app/SELinux verification. A successful local APK build
must not be described as verified Android runtime support.

## Bridge Contract

- MethodChannel qfli_forge/native: start({runId, type, projectPath, entryFile})
  returns {available: bool}; cancel({runId}) cancels an accepted run.
- EventChannel qfli_forge/native/events emits maps with runId and kind:
  stdout/stderr carry text, exit carries exitCode.
- Subscribe before start. Install listeners before starting processes. Every
  accepted run emits exactly one exit, after both output pipes are drained.
- Android reports unavailable if its packaged toolchain is absent. Keep the
  existing C fallback for that case. Accepted native failures report errors
  without silently falling back to a different execution engine.
- Existing non-Android mobile bridge and desktop compilation keep their current
  behavior.

## Packaging

Use NDK 27.0.12077973, LLVM 15.0.7 pinned to the existing commit, existing host
TableGen binaries and staged MSYS2 DLLs. Build directories and staged packages
live under ignored native/build. Validate ELF machine, dependencies and 16 KB
LOAD alignment. Package matching Android sysroot and C++ libraries. Artifact
hashes and source version belong in a manifest. Gradle consumes the generated
package path and does not vendor generated binaries in git.

## Android Startup

Reference qflistudio defers the first Flutter frame while AppBootstrap loads
project, authentication and settings data. Mirror that flow on Android using
qfli_forge/startup startupProgress({progress: double}), a native icon/progress
overlay, and light/dark backgrounds matching the shared core theme.

Use the public texture rendering mode so Android's native overlay can draw
while Flutter frames are deferred. Surface mode blocks the whole Android first
draw. Release the frame in finally after bootstrap and the home layout; remove
the overlay only in onFlutterUiDisplayed. Do not add a fixed startup delay.
