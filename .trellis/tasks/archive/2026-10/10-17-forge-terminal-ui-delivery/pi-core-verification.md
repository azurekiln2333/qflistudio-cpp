# pi-core verification (independent re-check) — shared-core integration & UI propagation

Task: `.trellis/tasks/10-17-forge-terminal-ui-delivery` (in_progress)
Reviewer: pi (shared-core linkage + UI verification re-check)
Core HEAD verified: `183865f feat(projects): add qsz transfer and polish main tab headers`
Mode: read-only production source; no pub get, no HAP build, no device ops, no git
commit. Wrote only this file.

## 1. Environment

- cwd `D:\MyNewProjects\qfli_c`; git root `D:/MyNewProjects/qfli_c`.
- Sibling core `D:\MyNewProjects\qfli_studio_core` at HEAD `183865f` (matches the
  pinned commit; not an old snapshot).

## 2. Dependency linkage — PASS

`qfli_c/pubspec.yaml` declares sibling paths:
`qfli_studio_core: path: ../qfli_studio_core` (line 13-14) and
`re_editor: path: ../qfli_studio_core/vendor/re_editor` (line 29-30).

`.dart_tool/package_config.json` resolves:

| package | rootUri |
| --- | --- |
| `qfli_studio_core` | `../../qfli_studio_core` |
| `re_editor` | `../../qfli_studio_core/vendor/re_editor` |

No `7768b91`, `shared-core-*`, or `native/build/shared` override remains anywhere
in project config (non-build/snapshot paths). The stale generated pin identified
in `design.md` is gone; dependency refresh resolved the propagation defect.

## 3. About / main tab titles / My header — PASS (source + widget tests at 183865f)

- About (`lib/pages/about_page.dart`): `_feedbackGroup = '694120628'` (line 21);
  `_descriptionFor` maps `forgeKey`/`'c'`/`'cpp'` → `C / C++` (line 33);
  feedback card `反馈与交流` + `复制群号` TextButton (187/205); branded app icon
  (line 90); online community text only when not `offlineOnly` (line 24).
- Main tab title tint: `titleLarge` + `colorScheme.primary` in
  `home_page.dart:408`, `quick_tools_page.dart:44` (工具),
  `local_content_pages.dart:74/179` (教程 / 示例代码), `profile_page.dart:92`
  (我的), and the community post list page.
- App shell: `qfli_c/lib/main.dart` `forgeProfile` uses
  `terminalCommandDelegate: forgeTerminalCommandDelegate`, `isOffline: true`,
  `productKey: forgeKey`, `showHomeTabs: false`.
- `dart ... flutter_tools.snapshot analyze --no-pub lib/main.dart` against the
  live sibling core → **No issues found**. The app compiles against `183865f`.

## 4. tool/build_ohos_release.ps1 — PASS (guard prevents stale snapshot packaging)

- Resolves `-FlutterSdk` (or parses `ohos/local.properties` `flutter.sdk`), and
  fails if `dart.exe` / `flutter_tools.snapshot` are missing.
- Runs `… dart … flutter_tools.snapshot pub get` first, so a previous manual
  snapshot pin is refreshed.
- **Hard dependency-root guard** before building: reads
  `.dart_tool/package_config.json` and asserts
  `qfli_studio_core` → `<root>/../qfli_studio_core` and
  `re_editor` → `<root>/../qfli_studio_core/vendor/re_editor`; throws if either
  resolves elsewhere. This makes packaging an old isolated snapshot impossible.
- Builds signed production HAP via
  `build hap --release --no-pub --target lib/main.dart --target-platform ohos-arm64`
  and asserts `build/ohos/hap/entry-default-signed.hap` exists.
- Conclusion: the script cannot silently bundle a stale `shared-core-*` snapshot;
  guard is sound.

## 5. Focused regression runs (direct flutter_tools.snapshot, --no-pub)

Command form:
`D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe
 D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot test --no-pub <files>`

| Suite | Files | Result |
| --- | --- | --- |
| Header theme + About/navigation | `main_tab_header_theme_test.dart`, `settings_about_test.dart`, `settings_navigation_test.dart` | **28/28 pass** |
| Broader related UI | `local_content_lazy_catalog_test.dart`, `tools_grid_test.dart`, `home_navigation_test.dart`, `studio_profile_test.dart`, `home_search_archive_test.dart` | **51/51 pass** |
| Shell cancellation / commands | `shell_command_test.dart`, `sandbox_terminal_test.dart` | **66/66 pass** |
| Forge app-side terminal/tools | `forge_terminal_test.dart`, `forge_terminal_lifecycle_test.dart`, `forge_tools_test.dart` | **21/21 pass** |

Shell cancellation specifically includes the early-cancel fix cases:
"interrupt with no delay after dispatch still cancels",
"interrupt immediately after dispatch still cancels the command",
"interrupt after stdout-ready stops the command quickly". All green.
Forge-side: `cancellation forwards cancel(runId) and keeps prior output`,
`interrupt during toolchain preparation reaches the accepted native run`.

Total focused: **166/166 pass, 0 failures.**

## 6. Non-interference

- No production source edited. Core working tree still holds only the
  pre-existing entries (`M terminax_terminal_page.dart`,
  `M sandbox_shell_backend.dart`, `M code_snippet.dart`;
  `?? code_snippet_idle_frames_test.dart`,
  `?? content_idle_frames_test.dart`,
  `?? main_tab_header_theme_test.dart`) — none written by this check.
- No `pub get`, no HAP build, no device operation, no git add/commit.

## 7. Findings / issues for the coordinator

No functional defect found. Two boundary notes (not blockers):

1. `community/post_list_page.dart` in `pi-core-result.md` is actually
   `lib/pages/community/post_list_page.dart` (path drift in the report only; the
   source does use the primary-tinted tab title).
2. Standalone `qfli_c/lib/forge_tools_page.dart` renders its own `C/C++ 工具`
   AppBar without the shared primary tint; it sits inside `FunctionsTab`'s tinted
   `工具` AppBar, so the shared tab header is correct. Out of shared-core scope.

## 8. Verdict

Dependency linkage is correct (live sibling core, no stale snapshot), the
About / main-tab-title / My-header UI is present and green at `183865f`, the
release build script hard-guards against stale snapshots, and all focused
shared-core + shell-cancellation + Forge-terminal regressions pass
(166/166). No source fix required; device smoke remains owned by root.
