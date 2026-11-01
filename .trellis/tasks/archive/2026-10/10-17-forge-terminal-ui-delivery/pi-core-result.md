# pi-core result — shared-core UI verification (About / main tab title colors / My header)

Task: `.trellis/tasks/10-17-forge-terminal-ui-delivery`
Verified core commit: `183865f` (feat(projects): add qsz transfer and polish main tab headers)

## Scope and method

- Read `pi-contract-note.md`; targeted only shared-core UI source + a focused test.
- Verified the live sibling `D:\MyNewProjects\qfli_studio_core` at HEAD `183865f`
  (not an old snapshot) and confirmed `qfli_c/.dart_tool/package_config.json`
  now resolves `qfli_studio_core` → `../../qfli_studio_core` and
  `re_editor` → `../../qfli_studio_core/vendor/re_editor`. No `7768b91`,
  `native/build` or `shared-core` override remains. The stale generated pin is gone.
- No device/build operations, no git commits, no generated package-config edits.
- Did not touch preexisting dirty files `lib/pages/terminax_terminal_page.dart`,
  `lib/widgets/code_snippet.dart` (and `lib/terminal/shell/sandbox_shell_backend.dart`,
  owned by the native/terminal worker) or the existing untracked idle-frame tests.

## Findings — source is already correct

1. **About branding + feedback/copy** (`lib/pages/about_page.dart`)
   - `_AboutAppIcon` renders each host's `assets/app_icon.png` with `ClipRRect`
     rounded corners (also reused on the licenses page).
   - `_descriptionFor` maps `StudioProductCatalog.forgeKey` / `'c'` / `'cpp'`
     to `C / C++` and produces `C / C++ 开发工具。管理本地项目，编辑 C / C++ 源码…`.
   - Feedback card (`反馈与交流`) has a selectable `694120628` `SelectableText`,
     a `复制群号` `TextButton` and tappable card; `_copyFeedbackGroup` copies via
     clipboard with success/failure snackbars and a mounted guard.
   - Single About entry: `settings_page.dart` no longer duplicates it; the only
     entry is Profile → `showQfliAbout` → `AboutPage` secondary route.

2. **Main tab title colors** (commit `183865f` "polish main tab headers")
   - `home_page.dart`: Home AppBar title uses
     `textTheme.titleLarge?.copyWith(color: colorScheme.primary)`.
   - `quick_tools_page.dart` (`FunctionsTab`, 工具), `local_content_pages.dart`
     (`LocalTutorialsTab` 教程 / `ExampleCodeTab` 示例代码),
     `community/post_list_page.dart` (讨论/教程) all use the same
     `titleLarge` + `colorScheme.primary` pattern.

3. **My/Profile header** (`lib/pages/profile_page.dart`)
   - `AppBar` title `StudioLocalizations.of(context).profile` uses
     `titleLarge` + `colorScheme.primary`.
   - Offline-only gating is intact: the profile tab is always reachable and hides
     networked sections for `offlineOnly` products.

4. **QFLIForge offline shell renders the intended pages**
   - `qfli_c/lib/main.dart` sets `forgeProfile` (`productKey: forge`, offline).
   - Shared shell (`lib/pages/home_page.dart`) composes Home (`HomeTab`),
   工具 (`FunctionsTab`), 教程 (`LocalTutorialsTab`)/示例 (`ExampleCodeTab`) and
   我的 (`ProfileTab`) from live core; About is reached via the shared route.
   - `dart analyze lib/main.dart` in `qfli_c` against the live sibling core:
     **No issues found** — confirms the app compiles against commit `183865f`.

## Changes

- Added `qfli_studio_core/test/main_tab_header_theme_test.dart` (new, focused,
  untracked) with 5 checks:
  - 工具 / 教程 / 示例代码 / 我的 AppBar titles use `colorScheme.primary` and
    `titleLarge` font size under the real `AppTheme.light`.
  - QFLIForge `AboutPage` shows `QFLIForge`, `版本 1.0.0`, `C / C++ 开发工具`
    copy and the `反馈与交流` / selectable `694120628` feedback group, and does
    not leak the online community text.
- No production source edits were required; no speculative redesign.

## Test evidence (direct `flutter_tools.snapshot`)

- Existing focused shared-core About/navigation suite:
  `settings_about_test.dart` + `settings_navigation_test.dart` → **23/23 passed**.
- Broader related UI suite:
  `local_content_lazy_catalog_test.dart`, `tools_grid_test.dart`,
  `home_navigation_test.dart`, `studio_profile_test.dart`,
  `home_search_archive_test.dart` → combined with the above **78/78 passed**.
- New `main_tab_header_theme_test.dart` → **5/5 passed**.
- `dart analyze` on the new test and touched core UI pages → **No issues found**.
- `qfli_c` `dart analyze lib/main.dart` → **No issues found**.

## Conclusion

The shared-core UI at `183865f` already implements the intended About branding,
copyable QQ feedback, main tab header colors and the colored My/Profile header.
The device-visible defect was the stale generated dependency override
(`.dart_tool/package_config.json` pinning `shared-core-7768b91a3ea3`), not the
source. **Dependency refresh alone resolves the UI propagation**; no core UI
source fix is needed.

## Limitations / observations

- Forge's product-owned tools body (`qfli_c/lib/forge_tools_page.dart`) renders
  its own `C/C++ 工具` AppBar without the shared primary tint. It sits inside
  `FunctionsTab`'s tinted `工具` AppBar, so the shared tab header itself is
  correct; tinting the product body is out of shared-core scope and was left
  untouched (no speculative change).
- Verification is source + widget-test level (no device run, per worker scope).
  Device smoke is owned by root.
