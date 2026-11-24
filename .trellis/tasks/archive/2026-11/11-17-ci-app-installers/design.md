# Design: CI installer builds

## Working copy

- Branch `ci/app-installers` from `github/main` (`ba5c33a`).
- Worktree: `D:/MyNewProjects/_wt/qfli_c-ci-app-installers`. All product edits happen there. The main checkout only receives Trellis files.
- Push the branch to `github`. Iterate until the workflow is green. Fast-forward GitHub `main`. Merge `github/main` into local `main`. Remove the branch and worktree.

## Runner layout

```text
$GITHUB_WORKSPACE/
  qfli_c/              application (actions/checkout, path: qfli_c), working directory of every step
  qfli_studio_core/    azurekiln2333/qflistudio-core @ 573d1b6eecf1c2b392ad753264a5a09f62f8335e
  flutter/             flutter/flutter @ 00b0c91f06209d9e4a41f71b7a512d6eb3b9c694 (stock jobs)
  flutter_ohos/        gitcode CPF-Flutter/flutter_flutter tag 3.41.9+ohos-1.0.2 (OHOS job)
```

Stock Flutter jobs patch the core with `tool/ci/prepare_core.py`. The OHOS job uses the unpatched core.

## Files

| Path | Owner | Purpose |
| --- | --- | --- |
| `.github/workflows/app-installers.yml` | main session | One workflow, jobs `android` (matrix abi), `windows`, `linux`, `macos`, `ios`, `ohos` |
| `tool/ci/prepare_core.py`, `stock-flutter-core.patch`, `test_prepare_core.py` | helper agent | Copied from `qfli_dart/tool/ci`, unchanged except names in messages |
| `tool/ci/fetch_native_artifact.py` | helper agent | Download and verify a `Native artifacts` output |
| `tool/ci/ohos_build.py`, `ohos-command-line-tools.lock.json` | helper agent | Sanitize signing, bootstrap HarmonyOS tools, package HAP and APP |
| `tool/ci/package_app.py`, `windows_installer.iss` | helper agent | Build and verify installers, write records |
| `tool/ci/test_ci_helpers.py` | helper agent | `unittest` for the pure functions of `package_app.py` and for its `android` command |
| `tool/ci/test_fetch_native_artifact.py`, `test_ohos_build.py` | helper agent, main session | `unittest` for artifact selection, digest checks, extraction, the missing-input exit, JSON5 parsing, HAP entry checks and the `package` command of `ohos_build.py` |
| `tool/ci/README.md` | main session | Chinese user document |

Helper scripts use the Python standard library only. The workflow does not pin Python. Linux and macOS jobs call `python3`. The Windows job calls `python`. `fetch_native_artifact.py` requires `tarfile.data_filter`.

## Script contracts

Environment read by packaging scripts: `GITHUB_SHA`, `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `GITHUB_SERVER_URL`, `RUNNER_TEMP`, `CORE_REVISION`, `FLUTTER_REVISION`. The OHOS job reads `FLUTTER_OHOS_REVISION` and `FLUTTER_OHOS_TAG` instead of `FLUTTER_REVISION`.

### `fetch_native_artifact.py`

```text
python3 tool/ci/fetch_native_artifact.py --name <artifact name> --extract-to <dir>
    --record <json path> [--run-id <id>] [--repository <owner/repo>] [--branch main]
```

- Calls `gh api` (token in `GH_TOKEN`). `--repository` defaults to `GITHUB_REPOSITORY`.
- Lists `repos/<repo>/actions/artifacts?name=<name>&per_page=100`.
- Selection (`select_artifact(artifacts, name, run_id, branch)`, pure, unit tested): exact name, `expired` false, then `workflow_run.id == run_id` when given, else `workflow_run.head_branch == branch`. Newest `created_at` wins.
- No match: exit 1 with `No unexpired artifact '<name>' ... Run the "Native artifacts" workflow first.`
- Downloads `.../artifacts/<id>/zip` with `gh api` to `RUNNER_TEMP`. The outer ZIP holds one inner `.tar.gz` and its SHA256 sidecar (naming from `native/toolchain/package-ci-artifact.py`). Verify the digest. Extract with `tarfile` `filter='data'` into `--extract-to` (created when missing).
- Writes the record: `name`, `artifactId`, `runId`, `headSha`, `headBranch`, `createdAt`, `expiresAt`, `archive`, `archiveSha256`.

Extraction targets (from `native/toolchain/README.ci.md`):

| Artifact | `--extract-to` |
| --- | --- |
| `qfli-native-android-<abi>` | `native/build/android-package` |
| `qfli-native-ohos-arm64-v8a` | `.` (repository root) |
| `qfli-native-ios` | `native/build/ios-portable/package` |

### `ohos_build.py sanitize | bootstrap | package`

- Based on `qfli_dart/tool/ci/ohos_build.py`.
- `sanitize`: `ohos/build-profile.json5` here has `//` comments. Parse with a small JSON5-tolerant reader (`parse_json5(text)`: strip `//` and `/* */` comments outside strings, drop trailing commas, accept single-quoted strings only if cheap). Remove `signingConfigs` content and each product's `signingConfig`. Write plain JSON.
- `bootstrap`: unchanged logic. User agent `qfli-c-github-actions`.
- `package`: inputs `build/ohos/hap/entry-default-unsigned.hap` and `build/ohos/app/ohos-default-unsigned.app`. Check in the HAP and in each HAP nested in the APP: `libs/arm64-v8a/libflutter.so`, `libs/arm64-v8a/libapp.so`, `libs/arm64-v8a/libqfli_ohos_runner.so`, `resources/rawfile/qfli_toolchain/ohos-wasi.zip`. Output directory `dist/app/`: `qfli-forge-ohos-arm64-unsigned.hap`, `qfli-forge-ohos-arm64-unsigned.app`, `hap-contents.json` (library list with sizes), `SIGNING.txt`, `provenance.json` (includes `$RUNNER_TEMP/native-input.json`, `ohos-toolchain.json`, `ohos-flutter-version.json`), `LICENSE`, `SHA256SUMS` (one line per file of the directory). `read_flutter_version` skips a first-run notice before the JSON document. No dependency on `tool/ohos/inspect_dart_hap.py` (absent here).

### `package_app.py <platform> --output dist/app [--native-record <json>]`

Based on `qfli_dart/tool/ci/package_installer.py` (work in progress there; adapt, do not import). Every command writes its package files, `SIGNING.txt`, `provenance.json`, `SHA256SUMS` (one line per package file) and a copy of the repository `LICENSE` into `--output`.

Constants: `APP_NAME = 'QFLIForge'`, `APP_ID = 'com.azurekiln.qfli.forge'`, `BINARY_NAME = 'qfli_c'`, `DEB_PACKAGE = 'qfli-forge'`, `HOMEPAGE = 'https://github.com/azurekiln2333/qflistudio-cpp'`.

| Command | Default input | Package files | Verification |
| --- | --- | --- | --- |
| `android --abi <abi>` | `build/app/outputs/flutter-apk/app-release.apk` | `qfli-forge-android-<abi>-test-signed.apk` | `lib/` holds exactly `<abi>`. Six libraries of AC2. `assets/qfli_toolchain/<abi>.zip` |
| `windows` | `build/windows/x64/runner/Release` | `qfli-forge-windows-x64-setup.exe`, `qfli-forge-windows-x64.zip` | Source has `qfli_c.exe`, `flutter_windows.dll`, `data/app.so`, `data/flutter_assets/AssetManifest.bin`. Silent install, file list equality (plus `LICENSE.txt`, `unins000.exe`, `unins000.dat`), silent uninstall |
| `linux` | `build/linux/x64/release/bundle` | `qfli-forge-linux-x64.deb`, `qfli-forge-linux-x64.tar.gz` | Package fields, `apt-get install`, launcher link `/usr/bin/qfli-forge -> /opt/qfli-forge/qfli_c`, desktop entry, icon, `ldd` has no `not found`, `apt-get remove` |
| `macos` | `build/macos/Build/Products/Release/QFLIForge.app` | `QFLIForge-macos-universal.dmg` | `hdiutil verify`, mount, `/Applications` link, `lipo -archs` has `arm64` and `x86_64`, `codesign --verify --deep --strict` |
| `ios` | `build/ios/archive/Runner.xcarchive` | `QFLIForge-ios-arm64-unsigned.xcarchive.zip` (`ditto -c -k --sequesterRsrc --keepParent`), `QFLIForge-ios-arm64-unsigned.ipa` | `lipo Runner -verify_arch arm64`. IPA has only `Payload/`. `Runner`, `Info.plist`, `Frameworks/App.framework/App`, `Frameworks/Flutter.framework/Flutter`, `forge-wasi-sdk/toolchain.json`. No `embedded.mobileprovision` |

Provenance fields: `applicationCommit`, `repository`, `runId`, `runUrl`, `coreCommit`, `flutterCommit`, `platform`, `architecture`, `applicationVersion` (from `pubspec.yaml`), `signing`, `nativeInput` (record or null), `packages` (file, sha256, size), `validation` (list), `deviceRuntimeVerified: false`.

Signing notes: Android `ephemeral debug key` (an update over an earlier CI build fails, reinstall needed). iOS and OHOS `unsigned`. macOS `ad hoc`. Windows and Linux `unsigned`. Desktop notes also state that a host `clang` or `gcc` is required.

`windows_installer.iss`: from the sibling file. `AppName "QFLIForge"`, `AppExe "qfli_c.exe"`, a new fixed `AppId` GUID, publisher URL of this repository, no SDK comment.

## Workflow

- Triggers: `workflow_dispatch` with `target` (all, android, ios, ohos, linux, windows, macos) and optional `native_run_id`. `push` to `main` and `ci/app-installers` on application, platform, `tool/ci/**` and workflow paths.
- `permissions: contents: read, actions: read`.
- Action pins follow the existing workflow (`checkout` v4.2.2, `upload-artifact` v4.6.2).
- Artifact names: `app-android-<abi>`, `app-windows-x64`, `app-linux-x64`, `app-macos-universal`, `app-ios-arm64-unsigned`, `app-ohos-arm64-unsigned`. Retention 30 days.
- Android: `sdkmanager 'ndk;27.0.12077973'`, fetch native input, `flutter build apk --release --no-pub --target-platform android-<arch>`.
- Windows: `windows-2022` (Inno Setup 6 preinstalled, `choco install innosetup` fallback, version not pinned).
- Linux: `ubuntu-24.04` with `clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev`.
- macOS: `macos-15`, ad hoc signing through `FLUTTER_XCODE_CODE_SIGN_*`.
- iOS: `macos-15`, fetch native input, `python3 native/toolchain/install-ios-package.py --package native/build/ios-portable/package`, `flutter build ipa --release --no-codesign --no-pub`.
- OHOS: `ubuntu-24.04`, sanitize, bootstrap, Java 21, fetch native input, `flutter build hap` and `flutter build app` with `--release --no-pub --no-codesign --target-platform ohos-arm64`.
- Each job writes a step summary with the download link and the limits.

## Trade-offs

- Native inputs come from workflow artifacts, not from a release. Simple and already verified, but they expire after 30 days. The fetch helper reports that case. A long-lived release is a later task.
- One macOS universal build replaces the sibling's per-architecture matrix. This application embeds no per-architecture SDK.
- No analyze or test gate. The task delivers packages. A gate can follow.

## Rollback

All changes are new files. Reverting the CI commits on GitHub `main` restores the previous state. The existing `Native artifacts` workflow is untouched.

## Deviations from the first plan

- Jobs: `windows` and `linux` are two jobs, not one `desktop` matrix. Their steps share almost nothing.
- Python: the first plan required Python 3.12+. The workflow uses the default interpreter of each runner image and does not pin a version.
- Tests: `test_fetch_native_artifact.py` and `test_ohos_build.py` were added. `test_fetch_native_artifact.py` also runs `main()` for the missing-input case (AC8). `test_ohos_build.py` also runs `package()` in a temporary workspace and checks the output file set, the license copy, the checksums and five failure cases.
- Cloud runs: run `44112310414` (commit `9712439`) lost its macOS and iOS jobs. GitHub cancelled both after 15 minutes without a runner, before any step. The session has no authenticated GitHub client, so it cannot re-run jobs. The commit with the `package()` test changed a trigger path and started run `44120892921`.
- License: the check step found that only the Windows installer and the Debian package carried the license. Each download directory now holds a copy of `LICENSE` (rule in `.trellis/spec/backend/native-toolchain.md`).
- Linux step summary: one line states that the Debian package and the tar.gz bundle carry no signature.
- Branch: the remote branch `ci/app-installers` and the worktree stay after the merge. The workflow and the user document name the branch as the test branch. Removal needs a user decision.
- Check: the `trellis-check` sub-agent failed twice with a gateway timeout. The main session ran the check through the `trellis-check` skill.
