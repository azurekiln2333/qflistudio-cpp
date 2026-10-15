# Cross-Platform Native Runtime Design

## Goal and Boundaries

Forge exposes C/C++ compilation and execution. Desktop platforms already have
native compiler execution; their project collection and lifecycle gaps belong
in the Dart compiler adapter. Android already has a packaged LLVM/native
executor. At initial planning, iOS had no native compiler integration and Web
had neither browser project storage nor a compiler worker. Their later source
integration and remaining verification gaps are in `implement.md` and
`research/platform-status.md`.

This task retains all platform gaps until implemented or explicitly scoped by
the user. Current implementation starts with confirmed desktop defects; success
on Windows does not establish completion on iOS, Web, or Apple desktop builds.

## Historical OHOS process design and Android scope, 2026-10-15

This OHOS process design was superseded by the 10-16 revision below after
actual release-app execution failed. It is retained as historical build and
diagnostic context, not as the current runtime contract.

The original OHOS design placed Clang, LLD, the isolated executor and libc++
in the signed installed native directory; a
resource-only ZIP supplies headers, configuration and link-time inputs.
ArkTS extracts resources through bounded raw-FD reads, validates readiness
against the actual layout, and passes opaque NAPI handles and a writable cache
directory directly to the native bridge. Each run compiles fresh PIC objects,
links a fresh shared program, and executes it in the isolated process with
independent streams and cancellation. Host/build checks cannot establish
app-domain executable and generated-code loading policy; require the real
phone audit plus ordinary editor Run/Stop before claiming OHOS acceptance.

Android keeps its existing native runtime/signing configuration. This
deliverable builds only ARM64 and x86_64, the two packaged toolchain ABIs, and
inspects the final APK. Android installation, push and device debugging are
excluded by the user's instruction.

## OHOS architecture revision, 2026-10-16

The preceding 10-15 process design failed on the actual release phone: installed
tools are 0644, explicit system-loader execve returns EACCES, and native-child
API13 returns multi-process disabled (16010004). The production route now embeds
signed ARM64 LLVM22/Clang/LLD and a forced WasmEdge interpreter, with WASI SDK33
resources as verified data. OHOS opts into WASI shared-memory threads; each
worker has an interpreter VM, sharing memory and WASI descriptors. All VMs must
finish before shared imports, AST or borrowed descriptors are released.

The ARM64 compiler and interpreter archives, SDK strict shared links, pinned
resource package and build provenance are complete. Real host NAPI execution
passes 31/31 cases, including C++ exceptions, SjLj, clocks, threaded programs
and cancellation. The signed actual-app audit also passes all 212 cases on the
release phone: 12 basic cases and 100 examples for each language. The latest
`lib/main.dart` production HAP also passes strict verification and replacement
installation with existing projects retained. Ordinary C++ Run, Stop (130),
fresh Run, Tutorial and Examples UI gates pass. The requested OHOS app and
Android build-only acceptance is complete; the cross-platform task stays open
for iOS/Web. Phone case evidence is recorded in
`research/ohos-portable-device-2026-10-16.json`, and production artifacts/UI
evidence in `research/ohos-production-ui-2026-10-16.json`.

This route supports the WASI ABI rather than native OHOS system-library
linkage. Compiler and interpreter are signed native ARM64 code; compiled user
programs are interpreted WASI data. It does not provide arbitrary native OHOS
headers, system APIs or generated machine-code linkage. See
`research/ohos-portable-acceptance-2026-10-16.md` and the current runtime spec
for evidence and final acceptance status. Independent iOS/Web gates stay open.

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

## iOS Backend and Remaining Apple Verification

Ordinary signed iOS apps can compile source as data, but cannot load arbitrary
new unsigned machine code using the Android generated-shared-object route.
Use bundled, signed compiler code to emit a portable program representation
and a proven compatible interpreter/runtime to execute it.

The implemented source uses in-process Clang/LLD emitting WebAssembly, with a
matching WASI libc/libc++ sysroot and a native Wasm interpreter. Compiler and runtime
must agree on supported Wasm features. Runtime I/O, project files, exit status,
memory limits, cancellation, and repeated-run cleanup require actual native
contracts. A C-only picoc plugin would not meet the C++ requirement.

The runtime choice and compatibility evidence are recorded in
research/ios-runtime.md and research/wasm-compatibility.md. Legacy Wasm exception
support is not compatible with current standard exception bytecode; the pinned
compiler/sysroot/interpreter combination passes the common native fixtures
below. Apple integration/build/device tests remain unverified on this Windows
host, so source integration and Linux execution do not complete iOS acceptance.

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
Mobile startup, user-owned OHOS signing edits and existing compiler-discovery
order are preserved. OHOS bridge repairs follow the contract above.

New platform backends will need isolated build directories and immutable
dependency versions/hashes, as the existing Android package contract requires.
Report per-platform implementation and verification status separately.
