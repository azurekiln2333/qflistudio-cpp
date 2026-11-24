# Design

## Split

Four work packages run in parallel. Each package has its own worktree. Every
worktree starts from the base commit on `ci/app-installers`. One package owns
each file.

| Package | Pane | Worktree under `D:/MyNewProjects/_wt/` | Branch | Owns |
| --- | --- | --- | --- | --- |
| CI | `w5C:p2` | `qfli_c-wp-ci` | `wp/ci-packaging` | both workflow files, `tool/ci/**` |
| ICONS | `w5C:p3` | `qfli_c-wp-icons` | `wp/icons` | `tool/icons/**`, every icon file, `linux/packaging/icons/*` |
| ENV-CORE | `w5C:p4` | `qfli_c-wp-env-core` | `wp/env-core` | `lib/toolchain/**` except the interface, `lib/clang_runner.dart`, their tests |
| ENV-UI | `w5C:p5` | `qfli_c-wp-env-ui` | `wp/env-ui` | `lib/forge_environment_page.dart`, `lib/forge_tools_page.dart`, their tests |

The main session owns the base commit, `pubspec.yaml`, `pubspec.lock`, the
interface file, the integration, the specs, every commit and every push. The
agents commit nothing and push nothing. The briefs are `wp-common.md` and
`wp-<package>.md` in this directory.

## Contracts between the packages

- ENV-CORE and ENV-UI share `lib/toolchain/toolchain_environment.dart`. The
  file is frozen. The shared instance is `forgeToolchainEnvironment` in
  `lib/toolchain/local_toolchain_environment.dart`. The base commit holds a
  stub with `supported == false`. ENV-CORE replaces the stub.
- The entry and the page have the name `环境配置`. The runner message for a
  missing compiler on desktop is
  `未找到可用的 C/C++ 编译工具链。请在工具页打开「环境配置」。`.
- ICONS delivers `linux/packaging/icons/app_icon_<N>.png` for N = 16, 24, 32,
  48, 64, 128, 256, 512. CI installs these files into the `.deb`, the
  `.tar.gz` and the AppImage. The CI tests create their own PNG files.
- ICONS delivers `windows/runner/resources/app_icon.ico` in a layout that
  `rc.exe`, Inno Setup 6 and NSIS 3 read. CI refers to the file by path.

## Place of the environment page

The Settings page belongs to the shared core. At the pinned revision it builds
a fixed list of sections and offers no hook for the application. A change there
needs a commit and a push in `qflistudio-core`. The user did not authorize
that.

Decision: the application owns a page `环境配置` (`ForgeEnvironmentPage`). The
page uses `SettingsSection` of the core, so it looks like the Settings page. A
direct button on the tools page opens it. The button exists only when
`environment.supported` is true (Windows, Linux, macOS). The five tool sections
keep their positions (`forge-tools.md`).

Follow-up, not part of this task: an entry inside the core Settings page.

## Compiler lookup

The page and the runner use one candidate list.

1. `QFLI_CLANG`, `QFLI_CLANGXX`, `QFLI_CC`, `QFLI_CXX`
2. the `toolchainDirectory` argument of the runner
3. `QFLI_TOOLCHAIN_HOME`
4. the configured toolchain directory (new)
5. managed toolchains from the one-click setup (new)
6. `<executable directory>/toolchain`
7. the Windows Dev-Cpp directories
8. `PATH`

Places 1 to 3 are overrides. The preference (`automatic`, `clang`, `gcc`) orders
the two families across places 4 to 8. The existing order of
`desktop-runtime.md` stays: environment variables first, `PATH` last. A settings
change applies at the next run.

## One-click setup

| Platform | Clang | GCC | Rights |
| --- | --- | --- | --- |
| Windows | LLVM-MinGW zip | a GNU GCC zip for UCRT (WinLibs or w64devkit) | none |
| Linux | package `clang` | packages `gcc` and `g++` | `pkexec` |
| macOS | `xcode-select --install` | Homebrew `gcc`, only when `brew` exists | system dialog |

- The page shows the exact address or command. Nothing runs before the user
  confirms.
- Windows: each archive has a pinned address, size and SHA-256. The
  application downloads into its storage directory, compares the SHA-256, and
  unpacks with `%SystemRoot%\System32\tar.exe`. It changes no `PATH`, no
  registry value and no shell profile. The user can remove a managed toolchain.
- The SHA-256 values come from our own download (trust on first use).
- The run step puts the toolchain `bin` directory on the `PATH` of the child
  process. A MinGW program needs the runtime libraries of the toolchain.
- The network use exists on desktop only. Android, iOS, OHOS and the web
  report `supported == false`, and no member acts.

## Single-file editions

- Windows: `qfli-forge-windows-x64-portable.exe`. A launcher unpacks the
  bundle once into `%LOCALAPPDATA%\QFLIForge\portable\<build id>\` and starts
  the application. It shows no wizard. Proposed tool: NSIS.
- Linux: `qfli-forge-linux-x64.AppImage`. `appimagetool` and the type-2
  runtime are pinned by a versioned address and a SHA-256.
- Both packages are unsigned. `SIGNING.txt` and `SHA256SUMS` list them.
- macOS keeps the `.dmg`. An `.app` in a `.dmg` is already one file to copy.

## Icons

One generator (`tool/icons/generate_app_icons.py`) derives every file from
`ohos/entry/src/main/resources/base/media/icon.png`. The artwork and the
background colour are the same on every platform. The outline follows the
platform: full square for OHOS, iOS, Windows and Linux, adaptive icon for
Android 8 and later, baked rounded rectangle for macOS, safe circle for the
maskable web icons. No workflow calls the generator.

## Workflow actions

| Action | Pin |
| --- | --- |
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1) |
| `actions/upload-artifact` | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` (v7.0.2) |
| `actions/download-artifact` | `9000827ccba6bdab643e8b6fd33ac0654aef8333` (v8.0.2) |

All three declare `using: node24`. CI checks every input in use against the
new major versions.

## Names

x64, x86_64 and AMD64 name one architecture. Android uses the ABI name
`x86_64`. Flutter desktop uses `x64`. The job names show `x64 (x86_64)`. No
artifact and no package file gets a new name, so existing links stay valid.

## Integration

Order on `ci/app-installers`: ICONS, CI, ENV-CORE, ENV-UI. One commit for each
package. Known contact points:

- `tool/ci/package_app.py` reads the icon files of ICONS.
- The real environment object reports `supported == true` on the desktop test
  host. `test/forge_tools_test.dart` then sees the entry.
- `flutter pub get` of the local Flutter rewrites the generated plugin files
  under `linux/flutter`, `windows/flutter` and `macos/Flutter`. These changes
  belong to no package and are discarded.

## Publication and rollback

1. Push `ci/app-installers` to GitHub. The push starts "Application
   installers".
2. A green run and a check of the artifacts allow the push to GitHub `main`.
3. The change of `native-artifacts.yml` starts one "Native artifacts" run on
   `main`. That run must be green too.
4. Local `main` gets the commits through a local merge. Nobody pushes local
   `main`.

Rollback: `main` moves only after a green run on the branch. A defect on
`main` gets a revert commit of the package that caused it. The packages are
separate commits.

## Not verifiable on this computer

- The Linux and macOS setup actions, and the sandbox of the macOS release
  build.
- The AppImage on real distributions. The cloud run checks its structure
  only.
- The portable executable on a clean Windows without developer tools.
