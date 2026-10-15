# Android Release APK Build + Static Analysis Fix, 2026-10-15

Coordinator: `w6:p1` Codex. Owner of this slice: Android build + analysis-fix worker.
Task: `.trellis/tasks/10-01-cross-platform-native-runtime`.
Authorization: user explicitly authorized immediate execution without further
planning approval.

## Scope and boundaries

- Verified `cwd` and git root are both `D:/MyNewProjects/qfli_c` before any write.
- Wrote **only** inside this repo:
  - `analysis_options.yaml`
  - `lib/web_clang_runner_browser.dart`
  - `native/web/tests/web_runner_browser_test.dart`
  - `pubspec.yaml` / `pubspec.lock`
  - `lib/platform/` (new: 6 files — `platform_io.dart`, `platform_io_native.dart`, `platform_io_browser.dart`, `platform_path.dart`, `platform_path_native.dart`, `platform_path_browser.dart`)
  - this research document
- Did **not** modify any sibling repository. `../qfli_studio_core` is a separate
  git repo and was left clean (`git status` empty at start).
- Did **not** touch any `ohos/` file, curriculum/content data, or another worker's
  files (`lib/clang_runner.dart`, `lib/forge_runner_native.dart`, `.trellis/*`
  edits belong to other workers and were preserved as-is).
- Android was **build only**. No `adb install`, push, emulator or device
  debugging was performed.

## 1. Static analysis: 4127 → 0

Toolchain (no Linux Dart/Flutter SDK exists on this host):

```powershell
$dart = 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe'
$snap = 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot'
& $dart $snap analyze --no-pub
```

### Baseline

- `native/build/ohos-android-full-analysis-20261015.log`: **4127 issues**.
- Fresh re-run this session: **4127 issues** (`native/build/ohos-android-full-analysis-baseline-20261015.log`, 76.0s).

Issue distribution extracted from the log by path:

| Path | Count | Nature |
| --- | --- | --- |
| `native/build/**` | 3754 | generated review copies (git-ignored) |
| `lib/web_clang_runner_browser.dart` | 20 | real source, missing shared-core API |
| `native/web/tests/web_runner_browser_test.dart` | 37 | real source, missing shared-core API |

The remaining ~316 of the 4127 are analyzer-reported issues not printed to the
log tail; all printed issues fall in the three paths above.

### Root cause

`lib/web_clang_runner_browser.dart` and `native/web/tests/web_runner_browser_test.dart`
imported `package:qfli_studio_core/services/platform_io.dart` and
`.../platform_path.dart`. Those files do **not** exist in the sibling shared core;
they are a *staged, not-yet-integrated* change
(`.trellis/tasks/.../patches/shared-core-platform/`). The current shared-core API
for files/paths is plain `dart:io` + `package:path`, which is unusable in the
browser (`dart:io` has no browser filesystem).

Because the sibling has a separate ownership/permission boundary and must not be
modified, the platform facade was **hosted locally in this repo** and the two files
pointed at it. The native branch re-exports `dart:io`/`package:path` unchanged, so
desktop/mobile behavior is byte-for-byte identical; the browser branch mirrors the
staged shared-core design (memory filesystem + IndexedDB snapshot, POSIX-root path
context).

### Changes

`analysis_options.yaml` — exclude generated build output only (git-ignored, see
`.gitignore` `**/native/build/`); no tracked source is masked:

```yaml
analyzer:
  exclude:
    - vendor/**
    - native/build/**
    - build/**
    - .dart_tool/**
```

`lib/platform/` — new local platform facade (contract-compatible with the staged
shared-core API so it can be deleted and the imports switched back once the shared
core integrates it):

| File | Role |
| --- | --- |
| `platform_io.dart` | conditional export: native / browser |
| `platform_io_native.dart` | re-exports `dart:io`; `studioFile`, `studioDirectory`, `studioCurrentDirectory`, `studioSystemTemp`, `studioEntityType(Sync)`, `initializeStudioStorage`, `flushStudioStorage` |
| `platform_io_browser.dart` | `MemoryFileSystem` rooted at `/qfli` + IndexedDB snapshot; `@visibleForTesting reloadStudioStorageForTesting` |
| `platform_path.dart` | conditional export: native / browser |
| `platform_path_native.dart` | re-exports `package:path` unchanged |
| `platform_path_browser.dart` | `package:path` bound to `Context(Style.posix, current: '/qfli')` |

`lib/web_clang_runner_browser.dart`:

```diff
-import 'package:qfli_studio_core/services/platform_io.dart';
-import 'package:qfli_studio_core/services/platform_path.dart' as p;
+import 'platform/platform_io.dart';
+import 'platform/platform_path.dart' as p;
```

`native/web/tests/web_runner_browser_test.dart`:

```diff
+// ignore_for_file: invalid_use_of_visible_for_testing_member
-import 'package:qfli_studio_core/services/platform_io.dart';
-import 'package:qfli_studio_core/services/platform_io_browser.dart'
+import 'package:qfli_c/platform/platform_io.dart';
+import 'package:qfli_c/platform/platform_io_browser.dart'
     show reloadStudioStorageForTesting;
+import 'package:qfli_c/platform/platform_path.dart' as p;  # removed: file does not use `p`
```

`pubspec.yaml` — added the two browser dependencies used by the facade
(`file: ^7.0.1`, `web: ^1.1.1`); both were already present in `pubspec.lock`
(`web` became a direct dependency, `file` newly resolved). `pub get` output:
`Changed 2 dependencies!`.

The `invalid_use_of_visible_for_testing_member` file-level ignore is **not** masking
a real error: this file is a genuine browser test (`@TestOn('browser')`) that lives
under `native/web/tests/` (outside the default `test/` scan) and legitimately uses
the storage facade's test helper.

### Result

- Scoped: `analyze lib/platform lib/web_clang_runner_browser.dart native/web/tests/web_runner_browser_test.dart` → **No issues found!**
- Full: `analyze --no-pub` → **No issues found! (ran in 28.0s)**
  (`native/build/ohos-android-full-analysis-fixed-20261015.log`)

### Tests

- `flutter test --no-pub --concurrency=1` → **176/176 passed**
  (`native/build/ohos-android-full-tests-fixed-20261015.log`), matching the
  pre-existing 176/176 in `native/build/ohos-android-full-tests-20261015.log`.

### Web compile evidence (bounded — NOT integration)

Strictly scoped claim: **the independent runner facade source compiles** for the
web target. It does **not** establish that the Web app is usable or that Web
integration is complete.

```powershell
& $dart $snap build web --release --no-pub   # → √ Built build\web (43.9s)
```

`main.dart` → `forge_runner.dart` → (web) `forge_runner_browser.dart` →
`web_clang_runner.dart` → `web_clang_runner_browser.dart` → `lib/platform/*_browser.dart`,
so the web build does compile the standalone runner facade and its browser
branch.

**Explicit non-claims / open gaps:**

- `lib/platform/` in the production tree is a *second, independent* memory
  filesystem + IndexedDB store (`qfli-studio-forge-files`), **not** an adapter to
  the shared core. The staged shared-core store uses a different database name
  (`qfli-studio-${StudioProfile.current?.id}`) and a separate `MemoryFileSystem`
  instance.
- The production sibling shared core's `EditorController` still imports `dart:io`
  (`../qfli_studio_core/lib/editor/editor_controller.dart:1`, `File(...)` at
  `:54/:193/:222`). It is not a *compile-time* web problem — the Web build already
  succeeds — but a *runtime* one: the browser has no real filesystem, so
  `dart:io` file operations throw at run time. Observed in the earlier un-staged
  Edge probe as `Unsupported operation: Platform._operatingSystem` from
  `FileSystemEntity.stat` (see below). Consequently the live-editor cases in
  `native/web/tests/web_runner_browser_test.dart` that combine
  `editor.openPath`/`editor.saveFile` with `studioFile(...)` do not share one
  filesystem against the production core; they are `@TestOn('browser')` and
  unexecuted (no driver script references them outside the staged patch).
- `native/web/stage-forge-review.mjs:8` requires the real shared core to contain
  `lib/services/platform_io_browser.dart`; the production sibling does not, so a
  review app cannot be built against the production core.
- `.trellis/spec/backend/web-runtime.md` itself states browser delivery requires
  the sibling shared core's platform adapters and that "staged adapters do not
  establish integration into that repo."

### Independent staged review fix (staging PASS — production core still NOT integrated)

An independent review repaired the *staged* copy and verified shared browser
filesystem persistence and editor access. This evidence covers those two
operations in staging:

- `native/web/stage-forge-review.mjs` copies the app into the ignored staged app
  `native/build/forge-web-review/` and **overwrites two local browser facade
  files with re-exports of the reviewed staged core**, so the runner, editor and
  project store all share ONE memory singleton instead of two disjoint ones:
  - `native/build/forge-web-review/lib/platform/platform_io_browser.dart` →
    `export 'package:qfli_studio_core/services/platform_io_browser.dart';`
  - `native/build/forge-web-review/lib/platform/platform_path_browser.dart` →
    `export 'package:qfli_studio_core/services/platform_path_browser.dart';`
- The reviewed staged core (`native/build/shared-core-web-review/updated/`)
  already switches `EditorController` to `platform_io.dart` (`studioFile(...)`)
  and ships the full `platform_*` adapters, so the real `EditorController` opens
  the same browser filesystem as the runner.
- Actual Microsoft Edge browser test harness result: **2/2 passed**
  (`native/build/browser-facade-staged-review.log`):
  `local facade persists project bytes` and
  `real shared EditorController opens the local runner filesystem`.
- Contrast — the earlier *un-staged* probe
  (`native/build/browser-facade-review-result.txt`) recorded **1 PASS / 1 FAIL**:
  the local facade persisted bytes, but the real shared `EditorController`
  failed with `Unsupported operation: Platform._operatingSystem` because, without
  staging, `EditorController` still used `dart:io` and did not share the local
  facade's filesystem. That FAIL is the production-core gap, not an
  OHOS/Android regression.

The **2/2 staged checks** verify this shared-filesystem repair; the
**production sibling core is not integrated** (its real `EditorController` still
uses `dart:io` and no `platform_*` adapters exist there).

Web acceptance therefore remains **open** at the production level. Web delivery
requires, in the shared core's own boundary: applying the `platform_io`/
`platform_path` integration to the *production* core, switching `EditorController`
and other `dart:io` call sites there, a review app built against the *production*
core, and passing browser compile/execute/UI gates. None of that is in this
worker's scope. **Web must not be reported as usable.**

## 2. Android release APK (final: two 64-bit ABIs only)

Goal of this pass: ship a release APK whose packaged LLVM toolchain matches the
declared ABIs. `--target-platform` accepts repeated values;
`flutter build apk --help` lists `[android-arm, android-arm64, android-x64]`.
Both values below are 64-bit, so every declared ABI has a complete toolchain;
`armeabi-v7a` (no toolchain exists) is dropped without changing Android config
or signing.

```powershell
& $dart $snap build apk --release --no-pub `
  --target-platform android-arm64 --target-platform android-x64
```

- Result: `√ Built build\app\outputs\flutter-apk\app-release.apk (127.9MB)`
  in 148.7s.
- Log: `native/build/ohos-android-full-apk-release-2abi-20261015.log`.
- Signing config **unchanged** (`android/app/build.gradle.kts` release uses
  `signingConfigs.getByName("debug")`; not edited). No Android config was changed
  for this pass — only the CLI ABI selection.
- No install/push/device step was performed.

### Final vs. previous artifact

The previous APK (fat, included `armeabi-v7a` with no packaged toolchain) is kept
for comparison under `build/app/outputs/flutter-apk/` (git-ignored):

| Artifact | ABIs (aapt2 `native-code`) | Size (bytes) | SHA256 |
| --- | --- | --- | --- |
| **Final** `app-release.apk` | `arm64-v8a`, `x86_64` | 134138844 (127.9 MB) | `8570a65f29ec63c329e8ddf21babc263908d815a089e2b5906e883a2d17bfdb6` |
| Previous `app-release-armv7-included-20261015.apk` | `arm64-v8a`, `armeabi-v7a`, `x86_64` | 143635486 (137.0 MB) | `cecff0734c6822fbde208f1a0ef4157ad3fb51f9fa928cacd4d5968f467aa85c` |

The ~4.5 MB reduction is the dropped `armeabi-v7a` Flutter payload
(`lib/armeabi-v7a/libapp.so`, `libflutter.so`); the QFLI native executables are
byte-identical between the two builds (same SHA256 below).

### Final APK identity

| Field | Value |
| --- | --- |
| package | `com.azurekiln.qfli.forge` |
| versionCode / versionName | `1` / `1.0.0` |
| minSdk / targetSdk / compileSdk | `24` / `36` / `36` |
| application-label | `QFLIForge` |
| native-code | `arm64-v8a`, `x86_64` (no `armeabi-v7a`) |
| signature | v2 true, 1 signer, `CN=Android Debug`, cert SHA-256 `3cf19ed8102760001b3d92f3e4f42a6e322a89ba987d93247b5f9d6afebc0b51` (same as previous build) |

### Actual LLVM assets inside the final APK

`lib/<abi>/` — exactly 6 entries per ABI, no `armeabi-v7a` (count = 0):

| Entry | Size (bytes) | SHA256 |
| --- | --- | --- |
| `lib/arm64-v8a/libqfli_clang.so` | 77782256 | `e389e9017a262fa513a4a58d608d61a4cd4d0f7a80541a1c53d468706a29aa2c` |
| `lib/arm64-v8a/libqfli-ld.lld-.so` | 44096816 | `43a32f21fa57067c320480c331b77d4fa0de339e14929a18ff9a9876b5ebc7dd` |
| `lib/arm64-v8a/libqfli_executor.so` | 7640 | `161180ae72ed934e15315459c577b4d782a00597f1c861f5294e929ab36484c1` |
| `lib/arm64-v8a/libc++_shared.so` | 1292896 | (AGP may strip) |
| `lib/x86_64/libqfli_clang.so` | 85174368 | `b06418648a323e310ed41bc6b186cbbd16e1b50a022f9afd68d3ab3a471d60a1` |
| `lib/x86_64/libqfli-ld.lld-.so` | 47718656 | `e9779d1f66bc4d89888c5626528e910de5e4893ce1189cb6ace1617086d4f1a7` |
| `lib/x86_64/libqfli_executor.so` | 7560 | `58c84438e8647b1ebb7f5925d02f056d43354ee55895273742cfc58d82e7d0df` |
| `lib/x86_64/libc++_shared.so` | 1252080 | (AGP may strip) |

The three QFLI executables per ABI have identical SHA256 in the previous and
final APK — the toolchain assets were not rebuilt, only the ABI selection changed.

`assets/qfli_toolchain/` (APK-entry hashes match the `.sha256` sidecar files):

| Entry | Size (bytes) | SHA256 (matches sidecar) |
| --- | --- | --- |
| `assets/qfli_toolchain/arm64-v8a.zip` | 10701985 | `0ea6f56851c8f79dd8c4b140c9a1da2c95ea352d34259efd054ed985cba3baa5` |
| `assets/qfli_toolchain/x86_64.zip` | 10229315 | `3d4e59492ec9e2077101f127bfc32f0b1c040d00108291374f4844cf3561c276` |

Resource manifests (`toolchain.json`, read from inside each ZIP):

| ABI | architecture | targetTriple | resourceDirectory | deviceExecutionVerified |
| --- | --- | --- | --- | --- |
| arm64-v8a | `arm64-v8a` | `aarch64-linux-android` | `lib/clang/15.0.7` | `false` |
| x86_64 | `x86_64` | `x86_64-linux-android` | `lib/clang/15.0.7` | `false` |

### Verifier (final APK)

```powershell
& native/toolchain/verify-android-apk.ps1 -Apk build/app/outputs/flutter-apk/app-release.apk
```

Result: **passed** for `arm64-v8a` and `x86_64`, exit code 0. Checks per ABI:
resource ZIP SHA256 vs sidecar, forward-slash ZIP paths, manifest match,
`deviceExecutionVerified == false`, required compiler headers
(`sysroot/usr/include/stdio.h`, `sysroot/usr/include/c++/v1/vector`,
`lib/clang/15.0.7/include/stddef.h`), ELF machine (183 arm64 / 62 x86_64),
64-bit little-endian `ET_DYN`, 16 KB LOAD alignment, allowed dependency set,
interpreter `/system/bin/linker64`, and packaged executable SHA256 vs manifest.

```
Verified APK ELF: arm64-v8a/libqfli_clang.so
Verified APK ELF: arm64-v8a/libqfli-ld.lld-.so
Verified APK ELF: arm64-v8a/libqfli_executor.so
Verified APK ELF: arm64-v8a/libc++_shared.so
Verified resource archive and compiler headers: arm64-v8a
Verified APK ELF: x86_64/libqfli_clang.so
Verified APK ELF: x86_64/libqfli-ld.lld-.so
Verified APK ELF: x86_64/libqfli_executor.so
Verified APK ELF: x86_64/libc++_shared.so
Verified resource archive and compiler headers: x86_64
Android APK artifacts verified: build\app\outputs\flutter-apk\app-release.apk
Device execution remains unverified.
```

### ABI check (guards against selecting only one platform)

```
aapt2 dump badging app-release.apk  →  native-code: 'arm64-v8a' 'x86_64'
```

Both requested 64-bit ABIs are present and `armeabi-v7a` is absent (ZIP grep for
`lib/armeabi-v7a/*` = 0 entries), confirming the repeated `--target-platform`
values both took effect.

## 3. Findings / follow-ups (not fixed here)

1. **`armeabi-v7a` toolchain gap — RESOLVED for this deliverable.** The earlier
   fat APK declared `arm64-v8a / armeabi-v7a / x86_64` while the QFLI toolchain
   only covered the two 64-bit ABIs (`native/build/android-package/{jniLibs,assets}`
   and both `toolchain.json`). The final APK is built with
   `--target-platform android-arm64 --target-platform android-x64`, so every
   declared ABI now has a complete toolchain. No Android config or signature was
   changed. (If a 32-bit ARM build is ever wanted, it requires building an
   `android-arm` toolchain first — out of scope.)
2. **Web is NOT integrated (production).** `lib/platform/` in the production tree
   is a second, independent memory filesystem + IndexedDB store, not an adapter
   to the shared core. The production sibling core's `EditorController` still
   uses `dart:io`, which is a **production browser runtime filesystem
   limitation** (the Web build already succeeds; `dart:io` file operations throw
   at run time in the browser, e.g. `Unsupported operation:
   Platform._operatingSystem`). The independent staged review (`stage-forge-review.mjs`
   forwarding the staged app's browser facades to the reviewed shared core) has
   **already fixed the shared filesystem at staging, passing 2/2 in Edge**, but
   that fix is confined to the ignored staged app. Therefore the live-editor
   browser cases are not connected and unexecuted against the production core,
   and Web must not be reported as usable. See the bounded "Web compile
   evidence" and "Independent staged review fix" sections above for the full gap
   list and the shared-core prerequisites.
3. **Local facade vs. shared core.** `lib/platform/` duplicates the contract
   staged in `patches/shared-core-platform/`. It exists only to keep tracked
   source analyzable within this repo's boundary. Once the sibling integrates
   `services/platform_io.dart` / `platform_path.dart` (and switches
   `EditorController`), delete `lib/platform/` and restore the
   `package:qfli_studio_core/...` imports in the two files.
4. **Signing.** The release APK is signed with the debug certificate (unchanged
   existing config, same cert SHA-256 as the previous build). Play/upload signing
   remains a separate, user-owned decision.

## 4. Reproduction summary

```powershell
cd D:/MyNewProjects/qfli_c
$dart = 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe'
$snap = 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot'
& $dart $snap analyze --no-pub                       # No issues found!
& $dart $snap test --no-pub --concurrency=1          # All tests passed! (176)
& $dart $snap build apk --release --no-pub `
    --target-platform android-arm64 --target-platform android-x64
                                                     # √ Built app-release.apk (127.9MB)
& native/toolchain/verify-android-apk.ps1 -Apk build/app/outputs/flutter-apk/app-release.apk
# aapt2 dump badging app-release.apk | findstr native-code  → 'arm64-v8a' 'x86_64'
```

This pass (the 2-ABI APK rebuild) changed **no source file**; it was build-only. It
only re-ran the build with a different ABI selection and updated this report. The
source changes listed in §1 (analysis fix) belong to the earlier pass. No commit
was made (root coordinates serialized commits after full validation). The
historical fat APK is retained as
`build/app/outputs/flutter-apk/app-release-armv7-included-20261015.apk` for
comparison.
