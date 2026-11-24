# Work package CI: Node.js 24 actions and single-file desktop editions

Read `wp-common.md` first.

- Worktree: `D:/MyNewProjects/_wt/qfli_c-wp-ci` (branch `wp/ci-packaging`)
- Report: `reports/wp-ci.md`

## Owned files

- `.github/workflows/app-installers.yml`
- `.github/workflows/native-artifacts.yml`
- `tool/ci/**` (helpers, tests, `README.md`, `windows_installer.iss`, new files)

## Why

The user downloaded the packages of the last green run and wrote three things:

1. The run page shows "Node.js 20 is deprecated" for `actions/checkout` and
   `actions/upload-artifact` in all seven jobs. "nodejs能不能更新一下".
2. "为什么都是安装版没有安装版和单文件版". Each desktop download holds an
   installer and a no-install archive. No file starts the application by
   itself.
3. "为什么linux windows都只有x64 没有x86_64". The user does not know that x64
   and x86_64 name the same architecture.

The existing build contract is
`D:/MyNewProjects/qfli_c/.trellis/spec/backend/app-installers.md` (it exists
only in that checkout). Read it. Every rule in it stays valid: pins by commit,
`persist-credentials: false`, no `${{ }}` inside a `run:` script, helpers use
the standard library only, `python3` on Linux and macOS, `python` on Windows,
the record files in every download directory.

## Part 1: Node.js 24 pins

Replace every occurrence in both workflow files:

| Now | New |
| --- | --- |
| `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2` | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` |
| `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2` | `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2` |
| `actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093 # v4` | `actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2` |

The main session read these three commits through the public API on
2026-11-18. Each `action.yml` at that commit says `using: node24`. The main
session did not read what changed between the major versions. That is your
part:

- Read `action.yml` and `README.md` of each action at the new commit through
  `raw.githubusercontent.com`.
- List the inputs that the two workflows pass to each action. Expected:
  `repository`, `ref`, `path`, `persist-credentials` (checkout); `name`,
  `path`, `if-no-files-found`, `compression-level`, `retention-days`
  (upload); `pattern`, `path`, `merge-multiple` (download).
- For each input, state in the report: it still exists, it means the same, and
  the default is the same where a workflow relies on a default. Fix the
  workflow where something changed.
- One contract crosses the two workflows: "Native artifacts" uploads an
  archive plus a SHA-256 sidecar, and `tool/ci/fetch_native_artifact.py`
  downloads that artifact as a zip through the REST API. Check that the new
  upload action still stores it as a zip with the same inner files.

## Part 2: Windows single-file edition

Output: `qfli-forge-windows-x64-portable.exe` in `dist/app/` of the `windows`
job, beside the setup program and the zip. One file. A double click starts the
application. No installation, no administrator rights, no registry entry, no
Start menu entry.

A Flutter Windows build is a directory (executable, DLLs, `data/`). No static
single executable exists. So the single file is a launcher that carries the
directory:

- First start: it extracts the build to
  `%LOCALAPPDATA%\QFLIForge\portable\<build id>\`, starts the application from
  there and exits.
- Later starts: the directory is complete, so the launcher starts the
  application at once.
- "Complete" means a marker file that the launcher writes after the last file.
  The launcher repeats an interrupted extraction.
- `<build id>` comes from the application commit and the run. Two builds never
  share a directory. The launcher deletes no other directory: an older build
  can still run.
- The launcher passes its command-line arguments to the application.
- The launcher shows no installer wizard. A progress window during the first
  extraction is acceptable.
- One switch extracts without a start (for example `/EXTRACTONLY`, with an
  optional target directory). The workflow uses it: extract, compare the file
  list with the build output in the style of the existing installer check,
  and fail on a difference.
- Icon: `windows/runner/resources/app_icon.ico`. Another package replaces that
  file. Do not edit it.

Suggested tool: NSIS (`makensis`). The main session believes that the
`windows-2022` image holds NSIS but did not verify it. Locate `makensis` the
way the workflow locates Inno Setup, with the same kind of fallback. NSIS is
not installed on this computer. A portable NSIS archive from the official
source in your scratch directory is fine for a local compile. When you cannot
compile locally, say so in the report: the cloud run is then the first compile
and the main session iterates. Keep the script small in that case. Another
tool is acceptable when it gives the same result and you state why.

## Part 3: Linux single-file edition

Output: `qfli-forge-linux-x64.AppImage` in `dist/app/` of the `linux` job,
beside the `.deb` and the `.tar.gz`. After `chmod +x`, a double click starts
the application.

- Build an AppDir from the same bundle that the `.deb` uses: `AppRun`, the
  `.desktop` file, the icon at the AppDir root and `.DirIcon`.
- `AppRun` must not export `LD_LIBRARY_PATH` and must not change `PATH`. The
  application starts host compilers (`gcc`, `clang`) and `pkexec`. They need
  the host environment. The Flutter launcher finds its libraries through its
  RPATH.
- `AppRun` passes its arguments to the launcher.
- Tool: `appimagetool` with the static type-2 runtime. Pin every downloaded
  file with a versioned address and a SHA-256, and compare before use. Do not
  pin a `continuous` tag: its files change. You compute each SHA-256 from one
  download. State in `tool/ci/README.md` that these values are
  trust-on-first-use.
- The runner has no FUSE 2. Run `appimagetool` with
  `--appimage-extract-and-run`. Pass the runtime with `--runtime-file`, so the
  tool downloads nothing by itself.
- Workflow check: the file is executable, it starts with the ELF magic,
  `--appimage-extract` succeeds in a temporary directory, and the extracted
  application files equal the bundle file list. Fail on a difference.
- This computer runs Windows. Check `wsl -l -q` for a Linux distribution, but
  install nothing. When you cannot run the Linux steps, say so. Make every
  step fail early with a clear message.

## Part 4: Linux icon sizes (contract with package ICONS)

Now `package_app.py` installs `assets/app_icon.png` as one file. Package ICONS
replaces that file with a 1024×1024 image and adds
`linux/packaging/icons/app_icon_<N>.png` for N = 16, 24, 32, 48, 64, 128, 256,
512 (square PNG, N×N pixels).

- Install each file as `usr/share/icons/hicolor/<N>x<N>/apps/<APP_ID>.png` in
  the `.deb` tree, and in the other Linux packages where they take icons.
- AppDir root icon and `.DirIcon`: the 256 file.
- Your worktree does not hold these files. Your tests create their own PNG
  files. A missing icon directory in the workflow means a broken checkout, so
  the helper fails with a clear message.

## Part 5: Records, names, documentation

- `SHA256SUMS`, `SIGNING.txt` and `provenance.json` list the two new packages.
  Both are unsigned.
- The job display names for Windows and Linux say `x64 (x86_64)`. Do not
  rename an artifact or a package file: other files refer to those names.
- `tool/ci/README.md` (Chinese, controlled Chinese rules of `AGENTS.md`):
  - one short section: x64, x86_64 and AMD64 name the same architecture,
    Android uses the ABI name `x86_64`, Flutter desktop uses `x64`, and no
    32-bit and no arm64 desktop package exists;
  - the table of editions per desktop platform (installer, no-install archive,
    single file), with what each one does at the first start and where the
    Windows launcher extracts;
  - the Node.js 24 pins, and removal of the Node.js 20 warning from the known
    limits if the README lists it.
  - Lint: `PYTHONIOENCODING=utf-8 python scripts/ste-lint-zh.py tool/ci/README.md`
    reports 0 findings.

## Checks before the report

- `python -m unittest discover -s tool/ci -p "test_*.py"` passes (85 tests
  before your change). New pure functions have tests: AppDir layout, build id,
  file-list comparison, icon install paths, record entries of the new packages.
- Both workflow files parse with PyYAML. The jobs `android`, `windows`,
  `linux`, `macos`, `ios`, `ohos` still exist.
- `permissions` did not change. No new secret. `GH_TOKEN` stays only in the
  three steps that call `fetch_native_artifact.py`.
- `git diff --check` is clean. `tool/ci/stock-flutter-core.patch` is the known
  exception. Do not edit that file.

You cannot start a cloud run. Say plainly which parts only the cloud can prove.
