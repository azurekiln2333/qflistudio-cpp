# Application Installer Build Contract

## 1. Scope / Trigger

Applies to `.github/workflows/app-installers.yml` and the helpers in `tool/ci/`.
The workflow builds downloadable application packages for Android, iOS, OHOS,
Windows, Linux and macOS on GitHub-hosted runners. It consumes the outputs of
the "Native artifacts" workflow (see [Native Toolchain](./native-toolchain.md)).

Code-spec depth is required: the change adds commands, wires one workflow to
the artifacts of another, and sets the signing boundary of every download.

## 2. Signatures

```text
python3 tool/ci/prepare_core.py --core ../qfli_studio_core --flutter ../flutter [--check]
python3 tool/ci/fetch_native_artifact.py --name <artifact> --extract-to <dir> --record <json>
    [--run-id <id>] [--repository <owner/repo>] [--branch main]
python3 tool/ci/package_app.py android --abi arm64-v8a|x86_64 --output dist/app
    [--input <apk>] [--native-record <json>]
python3 tool/ci/package_app.py windows|linux|macos|ios --output dist/app
    [--input <build>] [--native-record <json>]
python3 tool/ci/ohos_build.py sanitize|bootstrap|package
```

Manual run inputs: `target` (`all`, `android`, `ios`, `ohos`, `linux`,
`windows`, `macos`; default `all`) and `native_run_id` (optional).

## 3. Contracts

### Runner layout and pins

```text
$GITHUB_WORKSPACE/
  qfli_c/              application, working directory of every step
  qfli_studio_core/    azurekiln2333/qflistudio-core @ CORE_REVISION
  flutter/             flutter/flutter @ FLUTTER_REVISION (five stock jobs)
  flutter_ohos/        Flutter OHOS tag FLUTTER_OHOS_TAG @ FLUTTER_OHOS_REVISION (OHOS job)
```

- The workflow pins the core, both Flutter trees and every action by commit.
  After a clone, compare `git rev-parse HEAD` with the pinned commit.
- The five stock Flutter jobs run `prepare_core.py`. The OHOS job uses the
  unpatched core. `prepare_core.py` refuses an OHOS SDK and a core at another
  revision or with local edits.
- `actions/checkout` uses `persist-credentials: false`.
- The workflow does not pin Python. Linux and macOS steps call `python3`.
  Windows steps call `python`. Helpers use the standard library only.
  `fetch_native_artifact.py` requires `tarfile.data_filter`.

### Triggers

- `push` to `main` and `ci/app-installers`, filtered by paths. The last path
  entry is `'!**/*.md'`: a Markdown-only push starts no run.
- The concurrency group holds the ref and the target. A newer push cancels the
  run in progress on the same ref.
- A `push` run builds every platform. Only a manual run can select one.

### Permissions and input handling

- `permissions: contents: read, actions: read`. No other scope.
- `GH_TOKEN: ${{ github.token }}` exists only in the three steps that call
  `fetch_native_artifact.py`.
- No `${{ }}` expression appears inside a `run:` script. Inputs reach the shell
  through `env` and a quoted expansion:
  `${NATIVE_RUN_ID:+--run-id "$NATIVE_RUN_ID"}`.

### Native inputs

| Artifact | `--extract-to` |
| --- | --- |
| `qfli-native-android-<abi>` | `native/build/android-package` |
| `qfli-native-ios` | `native/build/ios-portable/package` |
| `qfli-native-ohos-arm64-v8a` | `.` |

Selection: exact name, not expired, then the given run id, else the newest
artifact of branch `main`. The helper compares the inner archive with its
SHA-256 sidecar before extraction. It writes the record that
`--native-record` reads (`name`, `artifactId`, `runId`, `headSha`,
`headBranch`, `createdAt`, `expiresAt`, `archive`, `archiveSha256`).

### Output

Every job writes `dist/app/` and uploads that directory.

| Artifact | Package files | Signing |
| --- | --- | --- |
| `app-android-<abi>` | `qfli-forge-android-<abi>-test-signed.apk` | ephemeral debug key |
| `app-windows-x64` | `qfli-forge-windows-x64-setup.exe`, `qfli-forge-windows-x64.zip`, `qfli-forge-windows-x64-portable.exe` | unsigned |
| `app-linux-x64` | `qfli-forge-linux-x64.deb`, `qfli-forge-linux-x64.tar.gz`, `qfli-forge-linux-x64.AppImage` | unsigned |
| `app-macos-universal` | `QFLIForge-macos-universal.dmg` | ad hoc, not notarized |
| `app-ios-arm64-unsigned` | `QFLIForge-ios-arm64-unsigned.ipa`, `QFLIForge-ios-arm64-unsigned.xcarchive.zip` | unsigned |
| `app-ohos-arm64-unsigned` | `qfli-forge-ohos-arm64-unsigned.hap`, `qfli-forge-ohos-arm64-unsigned.app` | unsigned |

- Each directory also holds `SHA256SUMS`, `SIGNING.txt`, `provenance.json` and
  a copy of the repository `LICENSE`. The OHOS directory adds
  `hap-contents.json`.
- `package_app.py` lists only the package files in `SHA256SUMS`.
  `ohos_build.py` lists every file of the directory.
- Upload options: `if-no-files-found: error`, `compression-level: 0`,
  `retention-days: 30`.
- `provenance.json` records `applicationCommit`, `coreCommit`,
  `flutterCommit`, `runUrl`, `signing`, `nativeInput`, `packages`,
  `validation` and `deviceRuntimeVerified: false`.
- Environment read by the packaging helpers: `GITHUB_SHA`,
  `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `GITHUB_SERVER_URL`, `RUNNER_TEMP`,
  `CORE_REVISION`, `FLUTTER_REVISION`. The OHOS helper reads
  `FLUTTER_OHOS_REVISION` and `FLUTTER_OHOS_TAG` instead of `FLUTTER_REVISION`,
  and also `GITHUB_ACTIONS`, `GITHUB_WORKSPACE`, `GITHUB_ENV`, `GITHUB_PATH`.

### Signing boundary

- The OHOS job runs `ohos_build.py sanitize` before any build step. It empties
  `app.signingConfigs` and removes each product's `signingConfig` in the CI
  copy of `ohos/build-profile.json5`.
- The workflow reads no repository secret. It sanitizes the OHOS signing
  config in its disposable checkout. Do not infer that every local checkout or
  branch is free of signing config.
- Keep local signing material out of commits. Before a push, scan the
  outgoing commits for `storePassword` and `keyPassword`. The release
  signing config stays on the local machine only.
- A label must state the signing state. An unsigned IPA, HAP or APP does not
  install on a device.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| No unexpired native artifact for the name | `fetch_native_artifact.py` exits 1 with `Native input failed: No unexpired artifact ... Run the "Native artifacts" workflow first.` It writes no record and creates no extraction directory |
| Inner archive differs from its SHA-256 sidecar | Exit 1 before extraction |
| Archive member leaves the extraction directory | The `data` filter of `tarfile` rejects the archive |
| Python has no `tarfile.data_filter` | Exit 1: `Use Python 3.12 or newer.` |
| APK holds another ABI, lacks a toolchain library or lacks `assets/qfli_toolchain/<abi>.zip` | `package_app.py android` exits 1. The output directory stays empty |
| `--native-record` file is missing or is not JSON | Exit 1 before packaging |
| Windows install list differs from the build output, or uninstall leaves the executable | Exit 1 |
| Linux launcher has an unresolved shared library, or `apt-get remove` leaves the application directory | Exit 1 |
| macOS application is not universal, or the image lacks the application or the `/Applications` link | Exit 1 |
| IPA holds an entry outside `Payload/` or holds `embedded.mobileprovision` | Exit 1 |
| HAP, or a HAP nested in the APP, lacks a required entry or holds another ABI directory | `ohos_build.py package` exits 1 |
| `ohos_build.py` runs outside GitHub Actions | Exit 1: `Use this helper only in the disposable GitHub Actions checkout.` |
| Only one of `OHOS_COMMAND_LINE_TOOLS_URL` and `OHOS_COMMAND_LINE_TOOLS_SHA256` is set | Exit 1 |
| A job produces no file in `dist/app/` | The upload step fails |

## 5. Good / Base / Bad Cases

- Good: all jobs of the run on the pushed commit conclude `success`, the
  artifact list holds the seven names, and the report states the signing state
  and the untested device execution.
- Base: unit tests and the YAML parse pass locally. The cloud run is pending.
  Report the packages as not verified.
- Bad: call an unsigned IPA or HAP installable, report device execution from a
  package layout check, or report cloud success from local checks.

## 6. Tests Required

- `python -m unittest discover -s tool/ci -p "test_*.py"` passes. Assertion
  points: artifact selection (name, expiry, branch, run id), digest parsing,
  rejection of a path outside the target, exit 1 and message of `main()` for a
  missing input, APK entry checks per ABI, the exact output file set of the
  `android` command (package, `LICENSE`, `SHA256SUMS`, `SIGNING.txt`,
  `provenance.json`), LF line endings of the records, removal of signing
  material from the real `ohos/build-profile.json5`, HAP entry checks, the
  exact output file set of `ohos_build.py package` (two packages,
  `hap-contents.json`, `SIGNING.txt`, `provenance.json`, `LICENSE`,
  `SHA256SUMS`), one `SHA256SUMS` line for every other file of that directory,
  and the failure cases of `package()` (outside GitHub Actions, missing build
  output, filled output directory, APP without a nested HAP, nested HAP
  without a required entry).
- The workflow YAML parses and holds the jobs `android`, `windows`, `linux`,
  `macos`, `ios`, `ohos`.
- Cloud: seven jobs conclude `success` (Android runs once per ABI). The run
  lists seven artifacts.
- Before each push: `git log github/main..HEAD` holds only CI commits. Author,
  committer and message hold no AI signature.

`test_ohos_build.py` runs `package()` against a temporary directory. It patches
`ohos_build.PROJECT` and sets the GitHub variables with `mock.patch.dict`.

No unit test runs the Windows, Linux, macOS and iOS commands of
`package_app.py`. Only the cloud run covers them.

## 7. Wrong vs Correct

Wrong: publish the workflow with a push of local `main`. The local branch
holds unpublished commits and a release signing configuration.
Correct: branch from `github/main` in a separate worktree, commit only the
workflow and `tool/ci/`, push the branch, wait for a green run, then
fast-forward GitHub `main` from that branch.

Wrong:

```yaml
run: python3 tool/ci/fetch_native_artifact.py --run-id ${{ inputs.native_run_id }}
```

Correct:

```yaml
env:
  NATIVE_RUN_ID: ${{ inputs.native_run_id }}
run: |
  python3 tool/ci/fetch_native_artifact.py ${NATIVE_RUN_ID:+--run-id "$NATIVE_RUN_ID"}
```

Wrong: copy the license only into the installer and the Debian package.
Correct: `write_records` and `ohos_build.py package` copy `LICENSE` into every
download directory.

## Known limits (2026-11-17)

- No cloud run has used `workflow_dispatch`. Platform selection and
  `native_run_id` are covered only by review and by the unit tests of
  `select_artifact`.
- `actionlint` and `shellcheck` were not available. Only a YAML parse and a
  manual review covered the workflow file.
- Native artifacts expire after 30 days. After expiry, run "Native artifacts"
  first.
- The workflow uses the pinned Node.js 24 action releases: checkout v7.0.1,
  upload-artifact v7.0.2 and download-artifact v8.0.2.
- Windows publishes a setup program, a portable ZIP and an unsigned
  single-file launcher. Linux publishes a Debian package, a tar.gz bundle and
  an unsigned AppImage. x64 and x86_64 name the same desktop architecture.
- The `choco install innosetup` fallback of the Windows job pins no version.
- `git diff --check` reports the blank context lines of
  `tool/ci/stock-flutter-core.patch`. Each line holds the single space of the
  unified diff format. Exclude that file from the whitespace check:
  `git diff --check <base> <head> -- . ':(exclude)tool/ci/stock-flutter-core.patch'`.
- GitHub can cancel a `macos-15` job that waits about 15 minutes for a runner.
  The annotation reads `The job was not acquired by Runner of type hosted even
  after multiple attempts`. No step of the job ran, and the run concludes
  `failure` (run `44112310414`: macOS and iOS cancelled, five jobs green).
  Report that commit as not verified on macOS and iOS. Use "Re-run failed
  jobs" on the run page, or push a commit that changes a trigger path. A
  re-run needs an authenticated call. The public API cannot start one.


## Validation update (2026-11-20)

Run 44797136694 on ci/ui-core-installers-20261121 completed with all seven
jobs successful. Artifact provenance matched app commit
6908e44ecb5edbc8a3a1388d40ec8d3166a35ac5 and core commit
cbaa4a4166461baafff7c1a343bd3ca1865fcc4f. The run used checkout v7.0.1 and
upload-artifact v7.0.2. It used a push event; workflow_dispatch remains
untested. See the archived Trellis task for artifact metadata and signing
limits.
