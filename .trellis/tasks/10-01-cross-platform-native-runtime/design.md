# Cross-Platform Native Runtime Design

## Goal and Boundaries

Forge exposes C/C++ compilation and execution. Desktop platforms already have
native compiler execution; their project collection and lifecycle gaps belong
in the Dart compiler adapter. Android already has a packaged LLVM/native
executor. iOS has no native compiler integration. Web has neither browser project
storage nor a compiler worker.

This task retains all platform gaps until implemented or explicitly scoped by
the user. Current implementation starts with confirmed desktop defects; success
on Windows does not establish completion on iOS, Web, or Apple desktop builds.

## Desktop Compilation

1. Collect `.c`, `.cpp`, `.cc`, and `.cxx` translation units once.
2. Select C++ linking whenever any C++ translation unit exists. The entry suffix
   continues to select Android/generic-native request type.
3. Compile `.c` units with the C driver, all other source units with C++.
   Explicit `-x c` / `-x c++` keeps case-insensitive source discovery consistent
   with compiler behavior for `.C` and `.CPP` filenames.
4. Retain project/include search paths, standards probing, object ordering,
   diagnostics, and supervised process ownership.
5. On Linux, link libm after object files. macOS uses libSystem; Windows retains
   its compiler's runtime libraries.
6. A compilation or link error prevents launch of any existing output binary.
7. Accepted cancellation completes with 130 after the supervised process stops,
   including cancellation during compilation, linking, or execution.

The observable runner contract remains ProgramRunResult: independent stdout and
stderr streams, an exit future, and a cancel callback. Source paths stay argument
array entries; no shell interpolation is introduced.

## Missing iOS Backend

Ordinary signed iOS apps can compile source as data, but cannot load arbitrary
new unsigned machine code using the Android generated-shared-object route.
Use bundled, signed compiler code to emit a portable program representation
and a proven compatible interpreter/runtime to execute it.

The leading candidate is in-process Clang/LLD emitting WebAssembly, with a
matching WASI libc/libc++ sysroot and a native Wasm runtime. Compiler and runtime
must agree on supported Wasm features. Runtime I/O, project files, exit status,
memory limits, cancellation, and repeated-run cleanup require actual native
contracts. A C-only picoc plugin would not meet the C++ requirement.

The runtime decision remains technical research in this task, with evidence
recorded in research/ios-runtime.md and research/wasm-compatibility.md. In
particular, legacy Wasm exception support is not compatible with current
standard exception bytecode. Do not declare a chosen backend functional until
common native fixture execution passes. Apple integration/build tests are
skipped on this host under the user's test-environment instruction.

Common native interpreter fixtures now pass with WASI SDK 33/LLVM 22.1.0 and
WasmEdge commit `845df599e7b71c98b0c77990c3aa3a10022bbaae`. Static compiler
code lives in `native/compiler/`; interpreter code lives in `native/portable/`.
Both expose opaque one-use sessions with cross-thread cancellation. Compiler
diagnostics and WASI stdio use borrowed independent descriptors. Wasm execution
forces interpreter mode, caps memory at 4096 pages and preopens only the project.
Native errors retain diagnostics and do not trigger a Dart fallback.

The platform bridge implements the existing Android start/cancel and event
protocol. `NativeClangRunner` owns subscription, event validation and stream
lifecycle for Android and iOS. The Android wrapper retains its existing optional
C fallback; iOS explicitly reports unavailable bundled resources. No generated
native-code loading or process-global chdir/stdio redirection is introduced.

## Web and Shared Core

Web needs a compiler/execution worker and browser-backed project storage. The
same C/C++ compiler and sysroot may be built to Wasm, but the current shared
core cannot access projects through dart:io in a browser. Complete delivery
therefore crosses the sibling shared-core ownership boundary. Preserve the
desktop/mobile storage behavior when adding a browser implementation.

Do not substitute a remote compilation service without a user decision.
Compilation output, runtime output, exit events, and stop requests must remain
local and routed to the existing terminal behavior.

## Compatibility and Rollback

Desktop edits are confined to lib/clang_runner.dart and focused execution tests.
No change to ProgramRunner or ProcessSupervisor's shared API is required.
Android/OHOS behavior, mobile startup, user-owned OHOS edits, and existing
compiler-discovery order are preserved.

New platform backends will need isolated build directories and immutable
dependency versions/hashes, as the existing Android package contract requires.
Report per-platform implementation and verification status separately.
