# Browser C/C++ Runtime Contract

## 1. Scope / Trigger

Applies to lib/forge_runner.dart, lib/forge_runner_browser.dart,
lib/web_clang_runner_browser.dart, web/forge-worker.js, web/forge-wasi.js and
native/web/. Browser delivery also requires the sibling shared core's platform
IO/path adapters. Staged adapters do not establish integration into that repo.

## 2. Signatures

- WebClangProgramRunner.run(projectPath, entryFile) returns ProgramRunResult
  for .c/.cpp/.cc/.cxx, case insensitive; unsupported suffixes return null.
- Worker request: {runId:String, entryFile:project-relative String,
  files:[{path:String, bytes:Uint8Array} or {path:String, directory:true}]}.
- Output: {runId, kind:stdout|stderr, text:String}; file publication:
  {runId, kind:files, files:[...]}; terminal event: {runId, kind:exit,
  exitCode:int}. Events from another runId are ignored.
- cancel() terminates the run's worker and completes exitCode with 130 after
  any accepted file writeback finishes.

```sh
bash native/toolchain/build-web-portable.sh
node --test native/web/tests/wasi.test.mjs
node native/web/tests/verify-compiler-browser.mjs
node native/web/stage-forge-review.mjs
node native/web/prepare-runner-browser-tests.mjs
```

## 3. Contracts

- Conditional exports exclude native process runners and the Dart C fallback
  from the JavaScript import graph. The fallback has 64-bit integer constants
  that dart2js cannot represent. Browser compiler errors never select it.
- Use shared platform_path for filesystem paths: POSIX /qfli browser context,
  native package:path passthrough. A browser URL is not a project path.
- Each run owns a fresh module worker/compiler filesystem. The compiler uses
  pinned LLVM 22/WASI SDK 33, C17/C++20, separate translation units, and standard
  Wasm exceptions. Preload wasip1 include/lib and Clang 22 resources. Generated
  compiler JS/Wasm/data and the bundled worker are build artifacts.
- Browser WASI receives only project files, an input.txt stdin file (EOF when
  absent), separate output streams, and project preopens. Output preserves
  empty lines, UTF-8 split across chunks, and final unterminated text.
- Runtime files are diffs against the initial project. A changed live file
  rejects writeback instead of overwriting an editor save. File/directory
  changes must flush storage before normal exit completes; save failure emits
  stderr and changes the result to 127. Cancellation retains exit 130.
- Preflight the original type and bytes for every changed path. Apply type
  replacements by deleting removed files, deleting removed directories
  deepest-first without recursion, creating directories, then writing changed
  files with a final conflict check. Nonrecursive removal preserves new editor
  children even when the program replaced their parent with a file.
- Shared browser storage serializes the virtual filesystem except /tmp into
  IndexedDB. Snapshot paths must be canonical absolute paths; custom project
  roots such as /workspace must persist. package:file root enumeration can
  return relative names: bind each root child to '/' before recursive listing.
- Compare snapshot revision and write its successor in ONE readwrite
  transaction. A stale tab must preserve its dirty bytes and the peer snapshot.
  Normalize initialization and save errors to FileSystemException so editor
  retry/dirty handling remains valid.
- Browser code editing requires a text-field semantics node and a multiline
  input configuration. Normal Web and native connections retain the existing
  delta model. The current SDK's semantics strategy omits beforeinput events,
  so Web accessibility connections use complete-value callbacks; otherwise an
  inferred empty delta truncates full-source replacement to the old first line.
  Reuse the existing line-buffer/prefix/composing application logic, and update
  an active connection's configuration when semantics changes.
  Default vendor save shortcuts must reach the application's actual save
  action; preserve explicit vendor overrides and native behavior.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Unsupported entry suffix | null; no worker |
| Entry outside project or invalid worker path | Diagnostic, exit 127 |
| Missing compiler/module or protocol failure | Separate stderr, exit 127 |
| Compile/link error | Nonzero exit; no execution/files event |
| Program exits with nonzero status | Preserve status and both streams |
| Wasm runtime trap | Separate diagnostic, exit 134 |
| Accepted stop | Worker terminated, streams closed, exit 130 |
| Live editor file changed during run | Reject conflicting writeback, exit 127 |
| Storage transaction failure/stale tab | FileSystemException; dirty data retained |
| WSL/build environment termination | Preserve build cache; verification open |

## 5. Good / Base / Bad Cases

- Good: actual browser compilation, C++ exception execution, Dart runner
  writeback/reload and UI output/stop all have independent passing evidence.
- Base: runtime executes host-compiled fixtures and storage tests pass; this
  does not prove the browser compiler or integrated application works.
- Bad: report a generated scaffold, source implementation or build percentage
  as completed browser compilation/execution.

## 6. Tests Required

- Node/Chromium runtime fixtures: mixed units/uppercase suffixes, math/input,
  output/stderr/exit 7, exceptions/destructors, files, traps, empty directories,
  fragmented output, rejected paths and infinite-program worker termination.
- Actual compiler gate: compile the fixtures in a browser; syntax/link errors
  must not launch a program; stop a compiled infinite program.
- Shared storage: binary/empty-directory and ProjectStore reopen, exclusive
  creation, peer conflict preservation, failed-save retry, corrupted snapshot,
  filesystem path consistency, custom roots and /tmp exclusion. Check native
  adapter passthrough separately.
- Actual Dart runner: input/output/status, file/directory diffs, durable reload,
  cancellation and protection of a live editor save. Include both file-to-
  directory and nested-directory-to-file replacement, exact bytes after reload,
  and a new live-editor child surviving a rejected parent replacement.
- UI: assert the exact named source file in IndexedDB, reload/reopen and copy
  the editor contents with clipboard line endings normalized. Poll async copy
  completion and independently assert contents before reporting success.
  Check ordinary input, accessibility, save shortcuts, desktop/mobile screenshots
  and actual compile/output/stop. QFLI_VERIFY_RUN=true enables the runtime UI
  checks in native/web/tests/verify-forge-browser.mjs.
- An installed browser's test harness failure is separate from an application
  failure. Record the actual browser and passed suite; retain unexecuted gates.
- Direct Flutter tool snapshot invocations must receive the SDK tool package
  configuration via Dart's --packages argument. Browser tests need local
  test/canvaskit assets; 404s prevent their callbacks from starting.
  Widget tests default to enabled semantics: use semanticsEnabled:false for
  normal input and activation fixtures, then acquire an explicit semantics
  handle. Use TargetPlatformVariant instead of a global setUp platform override
  that remains set during the widget binding's invariant checks.

## 7. Wrong vs Correct

Wrong: File('/qfli/...') and package:path's default URL-based context in browser
storage callers. Correct: studioFile(...) and the shared POSIX path facade.

Wrong: claim editing/save worked from an asynchronous predicate finishing or
from any file containing the marker. Correct: assert the exact project's file
bytes and independently confirm reopened editor contents.

Wrong: installing a consuming no-op vendor SaveIntent. Correct: route the
application's save shortcut or invoke an explicitly supplied override.

Wrong: create replacement nodes before deleting their original types, or use
recursive deletion to clear a directory conflict. Correct: remove old types
in depth order and reject a nonempty live directory without deleting its child.
