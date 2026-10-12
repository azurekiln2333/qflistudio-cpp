# Current Platform Status

| Platform | Implementation | Verification |
| --- | --- | --- |
| Android | Existing packaged LLVM/executor; startup overlay waits for Flutter; shared Dart streaming wrapper | Prior local artifact/build gates and current channel tests; device execution deliberately skipped |
| Windows | Native desktop compiler/process runner; corrected mixed units and cancellation | 13 real runner checks passed; latest 67-test native Flutter suite passed |
| Linux | Native desktop compiler runner and portable in-process LLVM/Wasm adapters | GCC/Clang seven desktop fixtures each; 19 portable checks plus four compiler lifecycle gates; Linux Flutter app unverified |
| macOS | Shared corrected desktop runner | Build/app execution skipped without Apple host |
| iOS | Native channels, static compiler/interpreter build script, SDK bundle, Dart streaming and cleanup wait | Common Linux adapters, resources-only SDK and Dart contracts passed; Xcode/signing/device/channel execution skipped |
| Web | Local compiler worker, WASI runtime and runner source; reviewed file/directory replacement repair; staged shared-core storage/path/editor patch | 12 Node and eight Chrome runtime checks; eight Edge storage and six Edge editor widget checks; rebuilt Chrome normal/accessibility source edit, Ctrl+S save, reload/reopen passed; compiler cache retained at about 61%; memory-limited resume stopped during configuration; actual compilation/Dart writeback/UI run-stop and sibling integration remain open |

OHOS/device debugging was not performed. Startup progress work is already
committed as 4f86187; this runtime task remains in_progress and uncommitted.

The Flutter fork still logs input-configuration null errors when the project
dialog is created. The verified source round trip completes despite those
errors; this is not a claim of an error-free browser application. Six focused
editor widget tests now pass in Edge. The harness needed the SDK tool package
configuration and local CanvasKit resources; fixtures also needed explicit
platform variants and controlled semantics activation.
