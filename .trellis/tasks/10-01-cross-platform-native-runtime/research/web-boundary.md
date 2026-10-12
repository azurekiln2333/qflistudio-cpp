# Web Runtime and Shared-Core Boundary

## Confirmed Current Behavior

A generated `web/` directory does not establish a working browser IDE. Forge
passes absolute filesystem paths to its runners and uses local files throughout:

- `lib/clang_runner.dart:3` imports dart:io and launches compiler/program
  processes (`lib/clang_runner.dart:221`, `:258`).
- `lib/c_runner.dart:2` imports dart:io and reads the project through File and
  Directory (`lib/c_runner.dart:57`, `:243`).
- `../qfli_studio_core/lib/services/app_paths.dart:41` reads Platform.environment;
  project directories are local Directory objects (`:128`).
- `../qfli_studio_core/lib/store/project_store.dart:112` resolves its registry
  to a local File, and project creation writes template files (`:315`).
- `../qfli_studio_core/lib/services/file_service.dart:21` lists Directory entries.
- `../qfli_studio_core/lib/services/runner_service.dart:71` validates entries
  through File and resolves symbolic links (`:73`).

Browser execution cannot use the operating-system Process API. A browser-native
route needs a C/C++ toolchain compiled to WebAssembly, an execution worker,
virtual project files, stdin/output exchange, and a stop operation. Merely adding
a conditional compiler runner does not repair shared project/editor storage.

The current pure-Dart C package is not a native C implementation. It imports
dart:isolate (`packages/qfli_c_runtime/lib/src/c_program.dart:9`) and attempts
Isolate.run with a fallback; that does not add C++ compilation or browser files.

## Ownership and Scope

The shared core is a sibling repository, referenced by a path dependency in
pubspec.yaml. Its browser storage and file APIs affect every language app.
A complete Web delivery must be reviewed as a shared-core change with its own
compatibility contract. Do not label this simply an unavailable test environment:
the execution and storage implementation is missing.

The current user request specifies a native compiler/interpreter implementation.
Whether that includes browser WebAssembly delivery needs a scope decision; a
remote compiler service would introduce a separate product dependency and is
not established by the request.

## Verification Limits

The environment can open browsers, but an end-to-end browser IDE cannot be
verified as implemented from the scaffold. Before browser testing, complete the
reviewed storage/toolchain integration. Keep desktop native Process testing
separate from any future WebAssembly testing.

## Implementation Progress, 2026-10-02

- The local compiler worker and WASI runtime are implemented. Twelve Node tests
  and eight actual Chrome worker checks passed using host-compiled fixtures.
  This is execution evidence; browser compilation remains a separate gate.
- A shared-core patch is staged against the sibling's current dirty contents.
  Native IO behavior is retained through conditional exports. Browser project
  storage uses a memory filesystem with IndexedDB persistence.
- Read, compare and write of the snapshot revision occur in one IndexedDB
  readwrite transaction. Stale browser tabs reject saves rather than overwrite
  a peer's committed snapshot. Persistence errors become FileSystemException;
  failed saves retain dirty bytes and permit a subsequent editor save.
- Seven actual Chrome storage tests passed in the scratch mirror: binary and
  empty-directory persistence, ProjectStore C++ reopen, exclusive creation,
  exact peer-snapshot protection/reload, failed-transaction/editor retry, and
  corrupted snapshot normalization/recovery, and virtual filesystem path
  consistency through configured entry lookup and RunnerService dispatch.
  The test SDK's Windows CanvasKit handler returned404; copying installed
  CanvasKit into scratch test assets resolved that without SDK changes.
- The expanded eight-test storage suite now passes in installed Microsoft
  Edge/Chromium, including custom `/workspace` project locations and exclusion
  of ephemeral `/tmp` files. Root enumeration explicitly binds package:file's
  relative child names to `/` before recursively serializing every persistent
  virtual root. The fixture creates its custom location before ProjectStore
  creation, matching that API's existing directory requirement.
- Scratch shared-core and Web runner analysis passed with no issues.
- Complete UI inspection exposed package:path's default browser URL context:
  AppPaths produced `http://127.0.0.1:<port>/qfli/...`, which MemoryFileSystem
  interpreted as a relative POSIX path. The staged shared platform_path facade
  now uses Context(Style.posix, current:'/qfli') in browsers and exports the
  unchanged package:path API on native platforms. All filesystem path imports
  use that facade. Browser tests require an absolute `/qfli/` project path with
  no URL scheme; two native storage/path passthrough tests passed.
- Four exact re_editor vendor files and focused browser input tests are staged
  with the platform adapters. Rebuilt normal and accessibility Chrome UI checks
  passed exact multiline insertion, Ctrl+S persistence, reload/reopen and copied
  editor bytes. Six focused editor widget tests also pass in Edge. The fixtures
  use explicit platform variants and controlled semantics activation. Direct
  tool snapshots require the SDK tool package configuration; local CanvasKit
  resources are required in the scratch test directory.
- Actual compiler and Dart-runner browser gates are prepared but have not run.
  The Dart gate covers stdin, separate streams, exit7, custom-location runtime
  file/directory creation and deletion after reload, saved live-editor conflicts
  and actual cancellation130. A review found file/directory type replacements
  applied in the wrong order. The runner now preflights live types/bytes, removes
  deleted files, removes obsolete directories deepest-first/nonrecursively, then
  creates directories and writes changed files. Two additional real-compiler
  fixtures require both type-replacement directions to survive reload and a
  newly saved editor child to survive a rejected directory replacement with127.
  These fixtures remain unexecuted until compiler packaging.
- The browser compiler build was interrupted at33% when WSL stopped. A second
  incremental two-job attempt coincided with a Windows PowerShell startup
  OutOfMemoryException. Windows committed memory was59.6GiB of63.7GiB. The same
  cache then reached61% with one job before its WSL session exited1. Its build
  log ends without a compiler/Make diagnostic; the subsequent kernel log reports
  `Init has exited. Terminating distribution`. The initiating cause is not
  established by available logs. The build is held during parent Web rebuilds;
  cached objects remain, and no clean rebuild or user process termination was
  performed. Safe synced kernel page-cache reclamation changed no global config.
- The sibling patch remains unapplied because the workspace permission
  boundary is pending. Full Forge UI verification uses a separate scratch app.
  No OHOS/device debugging was performed.

## Current Resource Gate, 2026-10-02

The latest one-job resume completed CMake configuration and generation, reused
existing LLVM targets through 59%, then was terminated by the owned resource
monitor when available Windows commit fell below 512 MiB. Both build and monitor
handles are terminal; no compiler process remains. The earlier approximately
61% object cache is retained. Reusing targets through 59% does not mean the
cached completion regressed or that new compiler artifacts were produced.

About 3 GiB of initial free commit did not suffice in this attempt. A separate
Android emulator named PyFlow_Import_Test uses approximately 4.9 GB working set.
It is outside Forge's task ownership and was left running. A concrete user
question asks whether that emulator may be closed or memory will be released
separately. Do not retry the same build without improved resource availability.
The actual sibling remains unchanged until its write permission is resolved.
