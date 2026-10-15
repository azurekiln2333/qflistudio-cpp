# Current Platform Status

Updated 2026-10-15. Build/host evidence and application/device evidence are
separate. Current requested acceptance is OHOS app testing and Android
build-only verification; older iOS/Web gaps remain open.

| Platform | Implementation | Verification |
| --- | --- | --- |
| OHOS | Installed LLVM/linker/executor and libc++; resource-only ZIP; repaired NAPI ownership, extraction, mixed linking, streams and cancellation | Seven bridge/executor/NAPI host groups, strict SDK syntax checks, actual-resource cross-linking, signed production/diagnostic HAP builds and exact HAP hashes pass. Diagnostic HAP installed; actual app execution remains unverified because launch returned lock-screen error 10106102. |
| Android | Packaged LLVM/executor for ARM64 + x86_64; shared Dart streaming wrapper | Final release APK built; both ABIs, resource hashes, ELF/dependencies/16 KiB alignment and v2 signature pass. Existing debug signing retained. No Android install/push/device tests. |
| Windows | Native desktop compiler/process runner; corrected mixed units and cancellation | Full repository analysis has zero issues; 176 VM tests pass, including actual desktop runner checks. |
| Linux | Native desktop compiler runner and portable in-process LLVM/Wasm adapters | GCC/Clang seven desktop fixtures each; 19 portable checks plus four compiler lifecycle gates; WSL curriculum 200 native compile/run cases and 10 negative probes pass. Linux Flutter app unverified. |
| macOS | Shared corrected desktop runner | Build/app execution skipped without Apple host |
| iOS | Native channels, static compiler/interpreter build script, SDK bundle, Dart streaming and cleanup wait | Common Linux adapters, resources-only SDK and Dart contracts passed; Xcode/signing/device/channel execution skipped |
| Web | Local compiler worker, WASI runtime and runner source; staged shared-core storage/path/editor patch; local facade keeps source analyzable without sibling writes | Web source build passes. Actual staged Edge facade persistence/editor sharing probe passes 2/2 after staged reexports. Production sibling core still uses unsupported browser filesystem calls. Older 12 Node, eight Chrome, eight Edge storage and six editor checks remain bounded evidence; actual compiler/Dart/UI run-stop and sibling integration remain open. |

Current source/content commits: `797d9b7`, `49a7579`, `cccc0b8`, `7f92787`.
The task remains `in_progress`; neither HAP signing nor Linux-host execution
establishes OHOS app execution. See `../ohos-status.md` and
`acceptance-artifacts-2026-10-15.json` for exact deliverables and continuation.

The Flutter fork still logs input-configuration null errors when the project
dialog is created. The verified source round trip completes despite those
errors; this is not a claim of an error-free browser application. Six focused
editor widget tests now pass in Edge. The harness needed the SDK tool package
configuration and local CanvasKit resources; fixtures also needed explicit
platform variants and controlled semantics activation.
