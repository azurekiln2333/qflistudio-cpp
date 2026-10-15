# Current Platform Status

Updated 2026-10-16. Build/host evidence and application/device evidence are
separate. Current requested acceptance is OHOS app testing and Android
build-only verification; both requested gates pass. Older iOS/Web gaps remain
open, so the overall cross-platform task remains in progress.

| Platform | Implementation | Verification |
| --- | --- | --- |
| OHOS | Signed native ARM64 LLVM22/LLD and forced WasmEdge interpreter; user C/C++ targets WASI33, not native OHOS ABI; shared-memory thread host and verified resources | ARM64 archives, strict SDK shared links, pinned package/provenance, signed audit HAP and host NAPI31 pass; portable curriculum200 passes. Actual release phone audit passes212/212: 12 basic cases (including thread cancellation/memory growth), 100 C and 100 C++ examples. Latest production HAP strictly verifies and replacement-installs with existing data retained; ordinary C++ Run, Stop130, fresh Run and Tutorial/Examples list/detail gates pass. Current OHOS scope is accepted. Historical process route failed with execve EACCES and native-child16010004. |
| Android | Packaged native LLVM/executor for ARM64 + x86_64; owned app curriculum assets | Refreshed release build after curriculum changes passes, with APK/signature/ABI/resource/16 KiB inspection. No Android install/push/device tests. |
| Windows | Native desktop compiler/process runner; owned curriculum repository | Full repository analysis has zero issues; 178 VM tests pass, using a read-only committed shared-core snapshot isolated in this repository. |
| Linux | Native desktop compiler runner and portable in-process LLVM/Wasm adapters | GCC/Clang seven desktop fixtures each; 19 portable checks plus four compiler lifecycle gates; real NAPI31 and both native200/portable200 curriculum runs pass. Native curriculum also passes 10 negative probes. Linux Flutter app unverified. |
| macOS | Shared corrected desktop runner | Build/app execution skipped without Apple host |
| iOS | Native channels, static compiler/interpreter build script, SDK bundle, Dart streaming and cleanup wait | Common Linux adapters, resources-only SDK and Dart contracts passed; Xcode/signing/device/channel execution skipped |
| Web | Local compiler worker, WASI runtime and runner source; staged shared-core storage/path/editor patch; local facade keeps source analyzable without sibling writes | Web source build passes. Actual staged Edge facade persistence/editor sharing probe passes 2/2 after staged reexports. Production sibling core still uses unsupported browser filesystem calls. Older 12 Node, eight Chrome, eight Edge storage and six editor checks remain bounded evidence; actual compiler/Dart/UI run-stop and sibling integration remain open. |

Historical 10-15 source/content commits: `797d9b7`, `49a7579`, `cccc0b8`, `7f92787`.
The task remains `in_progress`; neither HAP signing nor Linux-host execution
establishes OHOS app execution. See `../ohos-status.md` and
`ohos-portable-acceptance-2026-10-16.md` for current evidence and continuation.
`ohos-portable-device-2026-10-16.json` records the 212 unique phone cases and
exact signed audit HAP/log hashes. `ohos-production-ui-2026-10-16.json` records
the separately passed production HAP, preserved projects, editor Run/Stop and
content UI acceptance with screenshots.
`acceptance-artifacts-2026-10-15.json` retains the earlier architecture's exact
deliverables; it does not describe current portable-program phone acceptance.

The Flutter fork still logs input-configuration null errors when the project
dialog is created. The verified source round trip completes despite those
errors; this is not a claim of an error-free browser application. Six focused
editor widget tests now pass in Edge. The harness needed the SDK tool package
configuration and local CanvasKit resources; fixtures also needed explicit
platform variants and controlled semantics activation.
