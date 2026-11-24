# Work package ENV-UI: the environment page and its entry

Read `wp-common.md` first.

- Worktree: `D:/MyNewProjects/_wt/qfli_c-wp-env-ui` (branch `wp/env-ui`)
- Report: `reports/wp-env-ui.md`

## Why

The user wrote: "windows linux macos 在软件设置内能不能加个环境配置的？？
能不能加上一键配置clang、gcc环境的". On desktop the application compiles C and
C++ with a compiler of the computer. When none is present, a run fails and the
application offers no way forward. The user wants a place in the application
that shows and configures the compiler environment, and one button that makes
clang or gcc usable.

You build the page and its entry. Package ENV-CORE builds the logic at the
same time behind the frozen interface `lib/toolchain/toolchain_environment.dart`.
In your worktree the shared instance `forgeToolchainEnvironment`
(`lib/toolchain/local_toolchain_environment.dart`) is a stub with
`supported == false`. After integration it is the real object. So you verify
everything against a fake that you write in the tests.

## Read before you write

- `lib/toolchain/toolchain_environment.dart`: every doc comment is part of the
  contract. Do not edit the file. When a defect in it blocks you, write the
  defect into the report, work around it in your own files, and continue.
- `D:/MyNewProjects/qfli_c/.trellis/spec/frontend/forge-tools.md`: the contract
  of the tools page. Every rule in it stays valid.
- `lib/forge_tools_page.dart`: the style of the page and its terminal button.
- Core, read only, under `D:/MyNewProjects/_wt/qfli_studio_core/lib/`:
  `widgets/settings_section.dart` and the settings page, for spacing, tiles
  and wording.

## Owned files

- `lib/forge_environment_page.dart` (new)
- `lib/forge_tools_page.dart` (the entry only)
- `test/forge_environment_page_test.dart` (new)
- `test/forge_tools_test.dart` (existing: extend it for the entry, do not
  weaken it)

Do not edit `lib/main.dart`, `lib/toolchain/**` or `pubspec.yaml`.

## The page

```dart
const ForgeEnvironmentPage({super.key, required this.environment, this.pickDirectory});
final ToolchainEnvironment environment;
final Future<String?> Function()? pickDirectory;
```

- `pickDirectory` defaults to the system directory chooser (`getDirectoryPath`
  of `package:file_selector`, a direct dependency). Tests pass a fake.
- Title of the page: `环境配置`.
- Build the sections with `SettingsSection` of the core, so the page looks like
  the settings of the application.
- The object is a `Listenable`. Rebuild when it notifies. Call `load()` before
  the first use.

Sections, in this order:

1. `当前编译器`. One row for C and one for C++: family, version, path of the
   executable, and the place where the lookup found it. A language without a
   compiler says so and points to the sections below. An action `重新检测`.
   `detect()` can take many seconds: show progress, keep the page usable, and
   never call it from `build`. The first entry of a language is the compiler
   in use. The other entries may follow in a collapsed list.
2. `首选编译器`. `自动`, `Clang`, `GCC` → `setPreference`, then detect again.
3. `工具链目录`. Show `settings.directory`. The user selects a directory with
   the chooser, or types a path, or clears it. One line says what the
   directory must hold: `bin/` with `gcc`, `g++`, `clang` or `clang++`. After
   a change: `setDirectory`, detect again, and tell the user whether that
   directory gave a compiler (an entry with
   `source == CompilerSource.configuredDirectory`).
4. `一键配置`. The list of `setupOptions()`: title, summary, download size
   when it is known, a mark for `installed`, a mark for `needsAdministrator`.
   - A tap opens a confirmation dialog that shows `detail` in full. The user
     must see the exact command or address before anything runs.
   - After the confirmation: `runSetup(id)`. Show the phase, a progress bar
     (determinate when `received` and `total` are set), the last messages as a
     small log, and a button `取消` that calls `cancelSetup()`.
   - Final event `done`: detect again and show the result. `failed`: show the
     message. `cancelled`: return to the list.
   - While an action runs, the other options are disabled.
   - The interface says that a cancelled subscription does not stop the
     action. Decide what happens when the user leaves the page during an
     action, and record the decision.
   - `removable && installed`: an action `移除` with a confirmation →
     `remove(id)`.
   - An empty list shows one line: install a compiler by hand, then select
     the directory above.

Labels (use exactly these):

| Value | Label |
| --- | --- |
| `CompilerSource.environmentVariable` | `环境变量` |
| `CompilerSource.configuredDirectory` | `工具链目录` |
| `CompilerSource.managedInstall` | `一键配置` |
| `CompilerSource.knownLocation` | `已知位置` |
| `CompilerSource.systemPath` | `系统 PATH` |
| phases `preparing` … `cancelled` | `准备` `下载` `校验` `解压` `执行` `检测` `完成` `失败` `已取消` |

- Terms: `编译器`, `工具链`, `工具链目录`, `一键配置`, `重新检测`. One term
  for one thing on the whole page.
- The page must not overflow at a width of 360 logical pixels, at text scale
  1.5, or with a long Windows path. Give the user a way to copy a full path.

## The entry

- `ForgeToolsBody` and `ForgeToolsPage` get an optional
  `ToolchainEnvironment? environment`. The default is
  `forgeToolchainEnvironment`. The constructors stay `const` and
  source-compatible: the host calls them, and you cannot edit the host.
- When `environment.supported` is true, the tools body shows a direct button
  `环境配置` in the manner of the existing terminal button. It opens
  `ForgeEnvironmentPage` as a route.
- The five tool sections stay directly visible and keep their element
  positions (see `forge-tools.md`). The entry is a configuration page, not a
  sixth tool: no card, no tab.
- When `supported` is false (Android, iOS, OHOS, web), nothing is shown, and
  no code of the page runs.
- The entry lives on the tools page because the Settings page belongs to the
  shared core, and this task may not change the core.

## Web safety

`lib/forge_tools_page.dart` compiles for the web. Your files import nothing
that needs `dart:io` and call no `Platform` API.

## Tests (widget tests with a fake `ToolchainEnvironment`)

- Detection: a pending `detect()` shows progress, the result rows show family,
  version, path and place, and a language without a compiler shows the empty
  state.
- Preference: each choice calls `setPreference` once and starts a new
  detection.
- Directory: the fake chooser result reaches `setDirectory`, a typed path
  does too, clear passes null, and the page reports a directory without a
  compiler.
- Setup: the dialog shows `detail`, a declined dialog starts nothing, progress
  events update the bar and the log, `取消` calls `cancelSetup`, each final
  phase shows its state, and a running action disables the other options.
- Remove: only for `removable && installed`, after a confirmation.
- Notification: the page rebuilds when the fake notifies.
- Entry: visible and working when `supported` is true, absent when it is
  false, and the five tool sections are unchanged in both cases.
- Layout: no overflow at 360 logical pixels with text scale 1.5 and a
  200-character path.

## Checks before the report

- `flutter analyze` reports no issues for the whole project.
- `flutter test` passes. Give the test count before and after.
- `git status --short` lists owned files only.

No test here runs the page inside the real application window. Say so in the
report.
