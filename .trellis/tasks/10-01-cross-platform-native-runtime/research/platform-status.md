# Current Platform Status

## Current checkpoint (2026-11-25)

本地 `main` 含进程内编译器、OHOS 终端和启动页改动。
本地 `main` 也含桌面合并 `b5896d9` 和测试修复 `9e34dcc`。
这些提交尚未发布，GitHub 也未验证这些源码。
历史应用运行 `44822103705` 和 native 运行 `44001588302` 均成功。
这两次运行没有验证当前合并源码。
构建全部交给 GitHub Actions，本地不再构建。
iOS、Web 和 macOS 应用验收仍未完成。
下表只记录 2026-10-16 的验收结果。

## Historical acceptance scope (2026-10-16)

当时的验收范围包含 OHOS 手机测试和 Android 仅构建。
两项当时的验收均通过。
iOS 和 Web 验收仍未完成。
因此运行时任务当时保持进行中。

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
The task remains `in_progress` for the open cross-platform gates. The recorded
phone audit and production UI checks establish OHOS acceptance for their exact
2026-10-16 packages. Signing or Linux-host checks alone do not establish phone
execution, and the old phone results do not verify the current merged package. See `../ohos-status.md` and
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
