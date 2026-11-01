# Design

Three pi workers own separate surfaces: Dart and ArkTS routing; native compiler/NAPI command execution; shared-core UI verification. Root owns dependency refresh, integration, build and device delivery.

Terminal contract: MethodChannel qfli_forge/native method terminalStart receives runId, projectPath (sandbox root), workingDirectory, command (clang, clang++, or ./relative-program), arguments (string list). It returns {available:true} for accepted work, with existing stdout/stderr/exit events and cancel(runId). Dart must share NativeClangRunner's broadcast event stream. Desktop commands should retain existing real-shell fallback.

ArkTS calls qfliRunner.terminal(handle, projectPath, workingDirectory, command, arguments, cacheDirectory). NAPI validates paths, performs actual signed in-process LLVM/LLD compilation, and runs generated WASI modules through the existing interpreter. Keep no-exec/JIT contract, worker cleanup and cancel behavior. Compiler output is persistent under the sandbox, separate from temporary cleanup. Do not change existing run signature.

Refresh generated package resolution to the live sibling core. Previous .dart_tool/package_config.json overrides point at native/build/shared-core-7768b91a3ea3 despite pubspec's sibling path; this is the UI propagation defect. Verify the changed shared API and compile against current core before delivery.
