# pi-dart result — terminal routing for QFLIForge

Task: `.trellis/tasks/10-17-forge-terminal-ui-delivery` (Dart + ArkTS worker)

## Outcome

Implemented and verified the QFLIForge terminal command route:

- **Profile wiring** — `forgeProfile.terminalCommandDelegate` now points at the
  web-safe `forgeTerminalCommandDelegate`. The shared terminal
  (`terminal_pane.dart` / `terminax_terminal_page.dart`) already reads
  `StudioProfile.current.terminalCommandDelegate`, so this is the only product
  change needed to reach it.
- **Web-safe conditional export** — `lib/forge_terminal.dart` is now a pure
  `export 'forge_terminal_native.dart' if (dart.library.js_interop)
  'forge_terminal_browser.dart';`. This matches the existing
  `forge_runner.dart` pattern and keeps `dart:io` out of the browser build.
  The browser stub returns `false` so the sandbox keeps its own honest
  unsupported message.
- **Delegate behaviour** (`lib/forge_terminal_native.dart`):
  - Non-OHOS returns `false` → desktop real-shell fallback, Android/iOS sandbox
    unchanged.
  - On OHOS, `clang` / `clang++` and explicit `./relative-program` /
    `../relative-program` paths are forwarded via
    `MethodChannel('qfli_forge/native').invokeMethod('terminalStart', ...)`.
  - Payload is exactly `{runId, projectPath: sandboxRoot, workingDirectory: cwd,
    command, arguments}`.
  - Compound syntax (`|`, `>`, `<`, `&&`, `;`, globs, newlines) is rejected by
    `CommandParser.classify` and returns `false`, so the sandbox reports the
    real missing construct instead of mis-reading `clang a.c > log` as one
    argv.
  - Malformed quoting (`CommandParser.tokenize(...).ok == false`) returns
    `false`.
  - Arguments are tokenized with the shared `CommandParser` under
    `EscapePolicy.backslashLiteral`, so `"my dir/file.cpp"` becomes one argv.
  - Bare names (`main`, `ls`) are never claimed.
- **Shared event stream** — `NativeClangRunner.sharedEvents` is now public and
  used by both the editor Run path and the terminal delegate, so the two never
  re-register the platform stream handler (the OHOS bridge keeps a single
  `eventSink`, so a second subscription's `onCancel` would have silenced the
  first). `NativeClangRunner.allocateRunId` is shared so run ids never collide.
  The delegate subscribes **before** `terminalStart` and streams
  stdout/stderr, preserves the native numeric exit code, and drives
  `SandboxShellBackend.runStreams`.
- **Cancellation** — delegates to the native `cancel({runId})` and waits for the
  real exit/cleanup event (with the same optional timeout contract as the
  editor runner).
- **ArkTS** (`ohos/entry/src/main/ets/plugins/QfliCNative.ets`):
  - New `terminalStart` handler validates
    `runId/projectPath/workingDirectory/command/arguments`, always requiring
    absolute, `\0`-free paths and a string argv.
  - Reuses the existing `prepareToolchain`, `activeRun` busy-guard, `create`
    event callback, `cancel`, `finishRun`, `releaseRun` and `available:false`
    fallback lifecycle. `startAfterPrepare` now takes a launch callback so
    `start` and `terminalStart` share one code path; the existing `Run` call is
    unchanged (`qfliRunner.run(...)` with the same 5 arguments).
  - `terminalStart` calls the exact native API
    `qfliRunner.terminal(handle, projectPath, workingDirectory, command,
    arguments, context.cacheDir)`.
- **Types** — `Index.d.ts` declares
  `terminal(handle, projectRoot, workingDirectory, command, arguments,
  cacheDirectory): boolean` alongside the untouched `create/run/cancel/destroy`.

## Changed / added files

| File | Change |
| --- | --- |
| `lib/main.dart` | import + `terminalCommandDelegate: forgeTerminalCommandDelegate` on `forgeProfile` |
| `lib/native_clang_runner.dart` | public `sharedEvents`, shared `allocateRunId` (event reuse) |
| `lib/forge_terminal.dart` | conditional export (web-safe) |
| `lib/forge_terminal_native.dart` | new: `dart:io` delegate implementation |
| `lib/forge_terminal_browser.dart` | new: browser no-op delegate |
| `test/forge_terminal_test.dart` | new: 11 focused tests |
| `ohos/.../plugins/QfliCNative.ets` | new `terminalStart`, shared prepare/launch lifecycle |
| `ohos/.../libqfli_ohos_runner/Index.d.ts` | declare `terminal(...)` |

`lib/native_clang_runner.dart` was already staged with the `sharedEvents` /
`allocateRunId` change from a prior session; completed and re-verified here.

## Test commands and evidence

```
flutter analyze          -> No issues found! (ran in 13.6s)
flutter test             -> All tests passed! (189)
flutter test test/forge_terminal_test.dart -> All tests passed! (11)
flutter test test/native_clang_runner_test.dart test/forge_tools_test.dart
                         -> All tests passed! (15)
```

Focused coverage in `test/forge_terminal_test.dart`:
- desktop fallback returns false;
- real forwarding payload (`clang --version` → command/arguments/projectPath/
  workingDirectory/runId);
- quoted argv (`"my dir/main file.cpp"` stays one argument);
- compound syntax and malformed quoting are rejected without touching the
  bridge;
- bare program/unknown command not claimed;
- stdout/stderr forwarding and nonzero exit code;
- `available:false` reports honestly with `kProgramNotRunExitCode`;
- malformed bridge output fails without hanging;
- cancellation forwards `cancel(runId)` and keeps prior output;
- `./program` routes only when the file exists.

## Contract confirmation for other workers

- Native worker: implement
  `terminal(handle, projectRoot, workingDirectory, command, arguments,
  cacheDirectory): boolean` on `libqfli_ohos_runner.so`. `command` is either
  `clang` / `clang++` or an explicit `./`-relative program; `arguments` is a
  pre-tokenized argv (quotes already stripped by Dart). Compiler argv must not
  spawn a native subprocess, `chdir`, or redirect process-wide stdio (see the
  root contract note). Exit codes and cancellation must match the existing
  `run` semantics; the delegate waits for the real `exit` event.
- Root: `tool/ohos_terminal_audit.dart` works unmodified against this route,
  including `./"quote program"` (quoted program path) and `-c` object output.

## Limitations / notes

- Only `clang` / `clang++` and explicit `./` (`../`) project programs are
  claimed on OHOS. Bare program names and compound shell lines still fall
  through to the sandbox's own honest diagnostics — no fabricated shell.
- ArkTS/NAPI was not compiled here (no hvigor/device per instructions); only
  the Dart layer was executed. The ArkTS change was reviewed for lifecycle
  parity with the existing `start`.
