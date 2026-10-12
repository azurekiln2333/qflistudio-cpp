# Research: iOS native C/C++ runtime

- Query: Audit the missing iOS runtime, distinguish compilation from generated-machine-code execution, and identify proven native interpreters capable of supporting C++.
- Scope: mixed (repository inspection, cached LLVM 15.0.7 sources, upstream documentation).
- Date: 2026-10-01

## Findings

### Current integration is missing

| File | Purpose and observed state |
| --- | --- |
| `ios/Runner/AppDelegate.swift:13` | Only registers generated plugins in the implicit Flutter engine. No compiler or interpreter channels. |
| `ios/Runner/SceneDelegate.swift:4` | Empty Flutter scene delegate. |
| `ios/Runner/Runner-Bridging-Header.h:1` | Imports only `GeneratedPluginRegistrant.h`. |
| `ios/Runner.xcodeproj/project.pbxproj:9` | Build-file list contains Flutter/template Swift and resources; no native interpreter/compiler sources or libraries. |
| `ios/RunnerTests/RunnerTests.swift:7` | Empty example test, no runtime coverage. |
| `pubspec.yaml:13` | Shared studio dependency and pure-Dart C runtime; no native-runtime plugin dependency. |
| `lib/forge_runner.dart:24` | Tries Clang, then C, then the C++ compatibility runner. |
| `lib/clang_runner.dart:65` | iOS reaches the generic `qfli_forge/native` channel. |
| `lib/clang_runner.dart:303` | Generic `run` contract sends `type`, `projectPath`, `entryFile`; returns buffered output rather than the Android streaming contract. |
| `lib/c_runner.dart:186` | Separate optional `qfli_c/native` picoc channel. |
| `native/CMakeLists.txt:54` | Existing picoc target includes OHOS platform source and NAPI shell, links OHOS libraries. Not an iOS build. |
| `native/src/qfli_c_bridge.c:61` | Synchronous picoc invocation and copied result buffers. |
| `native/src/platform_ohos.c:28` | Process-global output and stdin state. |
| `native/build/llvm-project/` | Cached LLVM/Clang 15.0.7 source, useful for a future compiler library; existing target packages are Android/OHOS builds. |

Observed behavior: the missing Clang channel returns `null` for C and a 127/not-run result for C++ (`lib/clang_runner.dart:332`). C then probes the missing picoc channel (`lib/c_runner.dart:195`) and executes the Dart interpreter (`lib/c_runner.dart:83`). C++ does not have that fallback. The generic result title at `lib/clang_runner.dart:346` also says HarmonyOS regardless of the actual platform.

Read-only searches of sibling iOS trees (`qflistudio`, `qfli_python`, `qfli_lua`, `qfli_rust`, `qfli_go`) did not reveal an existing Forge/picoc/Wasm integration to reuse.

### Android execution is not a drop-in ordinary-iOS backend

Android compiles separate units, links `program.so`, invokes a separate executor, and loads generated native code:

- `android/app/src/main/kotlin/com/example/qflistudio/c/NativeCompilerBridge.kt:165`: generated `program.so`, `-shared` link.
- `android/app/src/main/kotlin/com/example/qflistudio/c/NativeCompilerBridge.kt:214`: `ProcessBuilder` for compiler/executor subprocesses.
- `native/toolchain/android-executor.c:37`: `execv` compiler launching.
- `native/toolchain/android-executor.c:44`: `dlopen` generated shared object, then `dlsym("main")` at line 50.
- `native/toolchain/android-executor.c:9`: Linux `prctl` process-monitoring dependency, additionally not a Darwin API.

Apple's platform-security documentation says all executable code on iOS must be signed using an Apple-issued certificate, and mandatory signing prevents unsigned code resources and self-modifying code. It also describes validation of dynamic-library signatures and team identifiers. Newly emitted user machine code cannot be made executable by merely writing it into the app container or changing its mode. Generating a Mach-O file instead of ELF does not solve that.

This constraint does **not** mean that iOS cannot compile source. A signed, bundled native Clang library can parse C/C++ and emit object files, LLVM IR, or Wasm as data. A signed interpreter can execute that data without creating native executable pages. Native frameworks already compiled and signed with the app can also execute their prebuilt functions.

Debug-enabled/JIT-enabled environments and jailbreaks are a separate support target. They must not establish ordinary shipping-iOS availability. Simulator behavior also does not establish physical-device code-signing behavior.

App Store Review Guideline 2.5.2 separately restricts downloaded code that changes app functionality, while explicitly allowing limited educational apps for teaching/developing/testing code if app-provided source is fully viewable and editable. This is a review policy, not an exemption from OS code signing, and does not guarantee acceptance.

### picoc closes only a C-subset gap

The bridge's declared source contract is `.c` translation units (`native/src/qfli_c_bridge.h:33`). `lib/c_runner.dart:128` passes only C units. picoc is a small C interpreter; adding a Swift channel and linking it cannot supply C++ classes, templates, standard-library containers, or C++ exception semantics.

The current bridge also needs real repair before reuse:

- Dependency `native/third_party/picoc` is absent; `native/CMakeLists.txt:19` intentionally fails without it. No dependency version or hash is presently pinned.
- Platform wiring, headers, and build target are OHOS-specific (`native/CMakeLists.txt:56`, `native/CMakeLists.txt:79`). iOS needs a signed static library/framework plus Objective-C/Swift or FFI integration.
- Global I/O buffers require serialization or instance isolation (`native/src/platform_ohos.c:28`, `native/src/platform_ohos.c:33`). Changing the process current directory affects all app threads (`native/src/qfli_c_bridge.c:92`).
- The API has no cancellation, timeout, or instruction-budget parameters (`native/src/qfli_c_bridge.h:42`). Moving synchronous execution off the UI thread does not stop infinite loops.
- Runtime failure after entering main is classified as normal program exit and can leave diagnostics in output (`native/src/qfli_c_bridge.c:111`, `native/src/qfli_c_bridge.c:126`). The argv allocation at line 131 can be skipped by a longjmp before line 142 frees it.
- Native-memory safety, full stdio capture, includes, and repeated runs need verification against the selected upstream source. The existing comments/README are not evidence of successful native execution.

### Proven native execution options for C++

| Option | C++ capability | iOS suitability and work required |
| --- | --- | --- |
| Cached Clang `clang-repl`/ORC | Clang frontend handles C++; incremental execution uses native JIT. | Not suitable as ordinary-iOS no-JIT execution. `clang/lib/Interpreter/IncrementalExecutor.cpp:38` creates a `JITTargetMachineBuilder`, line 40 creates `LLJIT`. A name containing "interpreter" does not make its executor a bytecode interpreter. |
| LLVM IR Interpreter | Clang can emit C++ IR, then LLVM can interpret instructions without JIT. | A real alternative for constrained experiments, but not complete C++ application support. LLVM 15's generic interpreter has missing opcodes, external-call ABI limitations, unresolved-function fatal exits, and unimplemented function-pointer lookup. It is unsafe to declare general C++/stdlib availability from this alone. |
| Native Wasm3 interpreter + Clang/LLD Wasm compiler + WASI sysroot | C/C++ compiled to portable Wasm; libc++ can supply normal C++ library code in the module. | Strongest verified portable architecture. Wasm3 is a C library and explicitly lists iOS support. Compiler must be embedded as a signed in-process library/command; Android subprocess launching is not reusable. Runtime interprets module data. Requires WASI I/O/filesystem integration, cancellation/fuel, resource limits, mixed-unit compiling/linking, and a pinned compatible compiler/sysroot/runtime feature set. |
| WAMR classic/fast interpreter + same compiler/sysroot | C/C++ after Wasm compilation; small C embedding API and WASI implementation. | Also viable. Disable AOT and JIT for generated user modules. Upstream lists Darwin/macOS but does not list iOS as an out-of-box supported platform; an iOS build/platform port and actual device verification remain necessary. More runtime features than a minimal interpreter can be useful, but compatibility must be verified against the chosen release. |

LLVM IR interpreter evidence in the cached 15.0.7 tree:

- `llvm/docs/CommandGuide/lli.rst:14`: bitcode execution through JIT or interpreter; line 19 says only host architecture; line 37 documents `-force-interpreter=true`.
- `llvm/lib/ExecutionEngine/Interpreter/Interpreter.h:109`: native pointer lookup is unimplemented; line 170 aborts on unimplemented instruction visitors.
- `llvm/lib/ExecutionEngine/Interpreter/ExternalFunctions.cpp:139` and line 188: struct/array ABI mapping is TODO.
- The same file at line 202 rejects external variadic calls through generic libffi; line 299 fatally rejects unknown externals. Builtin wrapper exceptions exist, so this does not mean all printf calls fail.
- `llvm/include/llvm/IR/InstVisitor.h:196` and line 239 delegate landingpad/resume handling to generic visitors; the interpreter has no matching override. Full exception unwinding is therefore not supplied by this backend.
- Existing Android CMake caches explicitly have `LLVM_ENABLE_FFI=OFF` (line 835) and target only `AArch64` or `X86` (line 1135), rather than `WebAssembly`. Existing ELF compiler packages cannot become an iOS/Wasm package by relabeling them.

Concrete prior art: the a-Shell iOS project documents compiling C and C++ with bundled Clang into WebAssembly, executing the result, and linking multiple object files/static libraries. Its README links a specific WASI-SDK fork and reports sandbox limitations (no sockets/fork in its execution environment). This establishes a working architecture for on-device C/C++ compilation, not source compatibility with every native desktop project.

WASI-SDK upstream documents Clang/LLVM, wasi-libc, compiler-rt, and libc++ sysroot requirements. Current docs state that C++ exceptions are disabled by default and need additional configuration; thread spawning is available only through an experimental threads target; dynamic linking is less mature; the Preview 1 target lacks networking. A full C++ language frontend and selected stdlib support are plausible, but native OS APIs, arbitrary native dynamic libraries, process spawning, threads, and exceptions require explicit support decisions.

### Recommendation and highest-value scope decision

For the requested C/C++ parity, prefer a separate iOS backend with an in-process Clang/LLD compiler emitting Wasm and an established native Wasm interpreter. Start with a pinned Preview 1 sysroot and static multi-unit programs, implementing real stdout/stderr/stdin, project-local headers/files, limits, and cancellation. Reuse the proven a-Shell architecture as technical prior art; determine dependency versions, licenses, compiler packaging, and feature flags before claiming support.

The material scope decision is whether iOS must include C++ in this task. If yes, adding picoc is insufficient and the Wasm compiler/runtime dependency chain belongs in the implementation plan. If the user explicitly accepts C-only support first, a repaired, pinned picoc backend is a smaller deliverable; iOS C++ must remain visibly unavailable and must not be marked completed. Lack of a Mac test host by itself is not permission to reduce the requested scope.

### Validation boundary on this host

Windows has no available `xcodebuild` or Swift command. Do not run or claim Xcode builds, Apple SDK compilation, simulator launch, signing, XCTest, iOS app-channel execution, physical-device unsigned-code checks, or App Store acceptance. A buildable iOS source integration still needs macOS/Xcode and signed-device verification later.

Possible locally meaningful work: portable interpreter/compiler fixture tests on Windows/WSL, Wasm C and C++ compilation with a matching sysroot, multi-file and mixed-language linking, stdin/output/error/cancel/resource-limit tests, and Dart channel-contract tests. These validate common logic but do not replace iOS execution. This research turn ran no new runtime tests or prototypes.

### External references and versions

Successfully read on 2026-10-01:

- Apple Platform Security, "App code signing process": <https://support.apple.com/guide/security/app-code-signing-process-sec7c917bf14/web>.
- Apple App Store Review Guidelines, 2.5.2: <https://developer.apple.com/app-store/review/guidelines/>.
- Wasm3 upstream README (`main`): <https://raw.githubusercontent.com/wasm3/wasm3/main/README.md>. Documents interpreter, iOS, WASI, embedding, MIT license, and minimal maintenance. Current main feature claims are not a pinned release guarantee.
- WAMR upstream README (`main`): <https://raw.githubusercontent.com/bytecodealliance/wasm-micro-runtime/main/README.md>. Documents C API, classic/fast interpreter, WASI, architecture/platform support, Apache-2.0 with LLVM exception. It announces a repository move to <https://github.com/wasm-micro-runtime/wasm-micro-runtime>.
- WASI-SDK upstream README (`main`): <https://raw.githubusercontent.com/WebAssembly/wasi-sdk/main/README.md>. Compiler/sysroot dependencies, static/shared options, exceptions, threads, and target restrictions. Main docs describe newer targets than cached LLVM 15; select a compatible immutable release rather than combining them blindly.
- a-Shell upstream README (`master`): <https://raw.githubusercontent.com/holzschu/a-shell/master/README.md>. Existing iOS application compiling C/C++ to Wasm; links <https://github.com/holzschu/wasi-sdk>.
- Cached LLVM version source: `native/build/llvm-project/llvm/CMakeLists.txt:19`, `:22`, `:25` identifies 15.0.7. Source URLs corresponding to the inspected implementation: <https://github.com/llvm/llvm-project/tree/llvmorg-15.0.7/llvm/lib/ExecutionEngine/Interpreter> and <https://github.com/llvm/llvm-project/blob/llvmorg-15.0.7/clang/lib/Interpreter/IncrementalExecutor.cpp>.

### Related specs

- `.trellis/spec/backend/native-toolchain.md`: real compiler/runtime verification, pinned LLVM source, and build success versus app availability.
- `.trellis/spec/backend/android-runtime.md`: Android execution isolation/streaming/cancel contract; Linux subprocess and ELF implementation details do not carry across to iOS.
- `.trellis/spec/backend/index.md`: backend spec index; generic error/quality documents remain placeholders.
- `.trellis/workflow.md`: task research must persist; implementation and validation remain separate phases.

## Caveats / Not Found

- No iOS interpreter/compiler integration or vendored picoc dependency exists in this checkout.
- No Apple build/runtime verification occurred, and no native portability claim follows from inspecting source.
- Subsequent network requests failed with TLS EOF/handshake errors. The immutable Wasm3 v0.5.0 README, standalone WASI-SDK `CppExceptions.md`, Cling README/site, Foundation Process metadata, and a-Shell submodule listing were not successfully read. They are not evidence for conclusions here.
- Cling was not selected: upstream execution details were not verified in this turn. The locally verified Clang incremental executor itself demonstrably uses JIT.
- New upstream `main`/`master` README features may not exist in older releases. Dependency versions/hashes, compatible Wasm proposals, iOS minimum version, framework size, and license distribution requirements still need implementation planning.
- Research ownership: only this file was written; all product files and platform configurations were read-only.
