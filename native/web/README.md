# Browser Compiler and WASI Runtime

The Forge runner sends a project snapshot to a dedicated module worker. The
worker loads bundled LLVM 22/Clang/LLD, compiles C17 and C++20 translation units
separately, links a WASI module, and executes it with the browser's WebAssembly
engine and `@bjorn3/browser_wasi_shim` 0.4.2. There is no compilation service.
Compiler and library resources come from the same pinned dependencies as the
native portable backend. C++ exceptions remain enabled throughout.

## Build

Prepare the pinned portable dependencies and build the host TableGen tools
first. Then, from the repository root on Windows:

```powershell
./native/web/prepare-emsdk.ps1
wsl -d qfli-java-build -- bash -lc 'bash native/toolchain/build-web-portable.sh'
```

`web-dependencies.json` pins the emsdk source archive and Emscripten release.
`package-lock.json` pins and verifies the browser WASI dependency. Generated
compiler JS/Wasm/resources and the bundled worker are ignored build output.
The browser package contains only the supported wasm32-wasip1 sysroot and
Clang22 resources, including the complete exception headers and libraries.
The Flutter web build must run after the browser compiler packaging step, so
the generated files under `web/toolchain/` are included in its output.

The default build uses one job and an 8 MB compiler stack; LLVM compilation
requires substantial memory and time. Environment overrides:
`QFLI_EMSDK`, `QFLI_PORTABLE_DEPS`, `QFLI_LLVM_HOST_TOOLS`, `QFLI_WEB_BUILD`,
and `QFLI_WEB_JOBS`. Source and output paths may contain spaces.

## Runner Contract

- Every run receives a new worker and compiler filesystem. Compile/link errors
  emit diagnostics and an exit status; no old program is reused.
- Runtime stdin reads the project-root `input.txt`, or EOF when absent.
- The project is preopened as `/project` and `.`. Relative headers and runtime
  files are available. Program filesystem changes are returned to the existing
  shared storage; only changed files are applied, with conflict checks against
  the initial snapshot. Old files and directories are removed before creating
  their replacements. Directory removal is nonrecursive, preserving any file
  saved into that directory during execution. A save conflict or transaction
  failure is observable.
- Stdout and stderr emit separate UTF-8 lines, including blank lines and final
  unterminated text. Exit follows drained output and project persistence.
- Stop terminates the worker during resource loading, compilation or execution
  and completes with 130. A runtime trap is isolated in the worker.
- Shared project storage uses `package:file` and IndexedDB in the browser;
  native platforms retain their `dart:io` implementations and public IO types.
  Filesystem path operations use the same POSIX `/qfli` context in the browser,
  avoiding the path package's default webpage URL context.
  The sibling patch is staged under the active task and needs workspace write
  permission before integration. An alternative editor is not provided.

WASI has no host process launching or arbitrary sockets. The worker implements
the WASI preview1 filesystem and stdio contract; it does not claim an OS shell.

## Verification

After `verify-portable-wasm.sh` generates the pinned SDK fixtures:

```powershell
npm --prefix native/web test
$env:QFLI_PLAYWRIGHT_MODULE = '<installed playwright module path>'
node native/web/tests/verify-wasi-browser.mjs
node native/web/tests/verify-compiler-browser.mjs
```

`QFLI_WASI_FIXTURES` can select a retained fixture run explicitly. The browser
gate uses installed Chrome by default; `QFLI_BROWSER_CHANNEL` can select another
Playwright browser channel. This gate proves browser **execution** using
host-compiled modules. It does not substitute for compiling the same projects
through the shipped browser compiler and existing Forge editor.

The compiler gate uses source snapshots and the shipped compiler worker. It
checks compilation, exceptions, diagnostics, file output and termination without
reusing host-generated program modules.

Current verified checks: 12 Node tests and eight Chrome worker checks, covering
mixed C/C++, uppercase suffixes, math, stdin/stderr, exit 7, rethrow/destructors,
libc++ exceptions, file writeback, trap isolation, fragmented UTF-8/blank lines,
path traversal rejection and infinite-program termination. Browser compiler
build and complete Forge UI workflow remain separate completion gates. Eight
actual browser storage tests passed in the isolated shared-core mirror, including
cross-tab revision conflicts, transaction failure retry and corrupted snapshot
recovery, custom project locations and exclusion of temporary files. This focused
run used installed Microsoft Edge's Chromium engine because the Flutter Chrome
harness stalled before navigation; the preceding seven storage checks passed
in Chrome. Two native storage/path compatibility tests also passed.
Six focused editor browser widget tests also passed in installed Edge, covering
save propagation/override, ordinary and accessible multiline input, composition,
selection, semantics activation after focus and read-only protection.

For review before sibling-directory write permission is available, stage the
current shared-core patch and an isolated Forge copy inside this workspace:

```powershell
node native/web/stage-shared-core-patch.mjs
node native/web/stage-forge-review.mjs
```

The Forge copy is `native/build/forge-web-review`. Run offline dependency
resolution, analysis and Flutter Web builds there. Its pubspec override points
to `native/build/shared-core-web-review/updated`, preserving the actual sibling.
The Web compiler artifacts must still be packaged before the full runtime gate.
Stage the Forge copy again after source or generated artifact changes.

Editor browser tests can run before the compiler package is available. From
the repository root, prepare their local renderer resources and run them in the
review app:

```powershell
$taskSdk = 'D:/ProgramFiles/flutter_ohos'
Copy-Item native/build/shared-core-web-review/updated/test/code_editor_browser_input_test.dart native/build/forge-web-review/test/
Copy-Item "$taskSdk/bin/cache/flutter_web_sdk/canvaskit" native/build/forge-web-review/test/ -Recurse -Force
Push-Location native/build/forge-web-review
try {
  & "$taskSdk/bin/cache/dart-sdk/bin/dart.exe" `
    "--packages=$taskSdk/packages/flutter_tools/.dart_tool/package_config.json" `
    "$taskSdk/bin/cache/flutter_tools.snapshot" `
    test --no-pub --platform=chrome test/code_editor_browser_input_test.dart
} finally {
  Pop-Location
}
```

The normal Flutter launcher supplies the tool package configuration itself.
Direct snapshot invocations need the explicit `--packages` argument; otherwise
the Web test platform fails in `currentPackageConfig`. Missing local CanvasKit
files return 404 and prevent test callbacks from starting. `CHROME_EXECUTABLE`
can select an installed Chromium browser such as Edge for these tests.

After compiler packaging, `node native/web/prepare-runner-browser-tests.mjs`
stages actual Dart browser runner tests plus compiler/CanvasKit test resources.
Set `QFLI_CANVASKIT` to another installed SDK's CanvasKit directory when needed.
Run `flutter test --no-pub --platform=chrome test/web_runner_browser_test.dart`
from the Forge review copy to verify streamed I/O, custom-location file and empty
directory creation/deletion after reload, conflicts with saved live-editor edits,
file/directory type replacements, protection of new editor children, and the
actual Dart cancellation result. This gate complements worker-only checks.

After rebuilding the review app, verify exact saved source bytes, reload/reopen
and copied editor contents through the actual UI:

```powershell
node native/web/tests/verify-forge-browser.mjs
$env:QFLI_VERIFY_RUN = 'true'
node native/web/tests/verify-forge-browser.mjs
```

The second invocation requires packaged compiler resources in the review Web
build and also checks UI compilation, output and stop. Screenshots are written
under `native/build/forge-web-review/screenshots`. These remain separate gates
until their invocations pass.

Forge conditionally exports the browser runner. Importing the native fallback
into the browser graph would compile its native 64-bit interpreter constants
through dart2js even though Web execution never uses that fallback.
