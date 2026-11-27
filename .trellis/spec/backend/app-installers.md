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
python3 -B ../qflistudio-core/tool/ci/prepare_flutter_core.py
    --flavor official|ohos --sdk-root <flutter-checkout> --sdk-revision <pinned-sha>
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
  qflistudio-core/    azurekiln2333/qflistudio-core @ CORE_REVISION
  flutter/             flutter/flutter @ FLUTTER_REVISION (validation and stock builds)
  flutter_ohos/        Flutter OHOS tag FLUTTER_OHOS_TAG @ FLUTTER_OHOS_REVISION (OHOS job)
```

- The workflow pins the core, both Flutter trees and every action by commit.
  After a clone, compare `git rev-parse HEAD` with the pinned commit.
- Core is pinned to `1ae4674a4b153701b0c3b3ff04b1a1b77a318611`.
  The Flutter validation job and five stock Flutter platform jobs invoke
  core's `prepare_flutter_core.py` with flavor `official` before resolution.
  The OHOS job invokes flavor `ohos`, which preserves the native view.
  Both modes verify the exact SDK revision on GitHub-hosted runners.
  The Dart package name remains `qfli_studio_core`.
- `actions/checkout` uses `persist-credentials: false`.
- The workflow does not pin Python. Linux and macOS steps call `python3`.
  Windows steps call `python`. Helpers use the standard library only.
  `fetch_native_artifact.py` requires `tarfile.data_filter`.
- Both Windows compilers receive `/DFileVersion` from
  `windows_file_version(version)`: `1.2.3+4` becomes `1.2.3.4`, and `1.2.3`
  becomes `1.2.3.0`. Pass the application version through
  `package_windows` to `build_windows_portable`; the build ID is not a version.
- NSIS scripts use `!ifndef`, `!error` and `!endif` for required definitions.
  Lines beginning with `#` are comments, not preprocessor directives.
  Require `FileVersion` rather than supplying a fallback that hides missing
  arguments. An undefined `${FileVersion}` fails `VIProductVersion`.
- The portable launcher accepts `/EXTRACTONLY [directory]`. Pass the directory
  as a separate argument, not as `/D=...`: NSIS consumes `/D=` before
  `$CMDLINE` reaches `GetParameters`. `GetOptions` already trims separator
  spaces and removes surrounding quotes. Store its result directly in
  `$Target`; do not trim characters or unquote it again. An omitted directory
  keeps the `$EXEDIR\QFLIForge` default. Extract-only mode never starts the app.

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
  `flutterCommit`, `flutterVersion`, `nativeRunId`, `runUrl`, `signing`, `nativeInput`, `packages`,
  `validation` and `deviceRuntimeVerified: false`.
- Environment read by the packaging helpers: `GITHUB_SHA`,
  `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `GITHUB_SERVER_URL`, `RUNNER_TEMP`,
  `CORE_REVISION`, `FLUTTER_REVISION`, `FLUTTER_VERSION`. Desktop packages
  consume no native artifact and record `nativeRunId: null`. Mobile packages
  copy the run ID from the verified `nativeInput` record. The OHOS helper reads
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
| Portable extraction lacks a source file, adds an unexpected file or writes no completion marker | Exit 1 before the second extraction; a launcher process failure also propagates |
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
- Base: helper tests and workflow checks pass in GitHub Actions. Platform
  builds remain pending. Report the packages as not verified.
- Bad: call an unsigned IPA or HAP installable, report device execution from a
  package layout check, or report cloud success from local checks.

## Hosted validation and Flutter build outputs

- `actionlint` runs the fixed official v1.7.11 Linux binary after checking its
  SHA-256. It checks every `.github/workflows/*.yml`, including shellcheck.
  Only SC2016 in two literal Markdown summary blocks is suppressed.
- `flutter-validation` checks out the same core and stock Flutter revisions as
  packaging. It prepares the core, runs `flutter pub get`, then strict
  `flutter analyze --no-pub` and `flutter test --no-pub --concurrency=1`.
  No `--no-fatal-infos` or `--no-fatal-warnings` flag is used.
- Tests run on `windows-2022`: PATHEXT fixtures use real files and assume a
  case-insensitive filesystem. The existing QFLI_CC/QFLI_CXX interface selects
  the hosted GCC/G++ toolchain. Serial execution limits contention around the
  startup fixtures' short wall-clock floors. Do not skip failing tests.
- All six packaging jobs require helper tests, actionlint and Flutter validation.
  The reusable native workflow waits for these checks as well.
- `archive_flutter_build.py` runs after the release build, before installer
  assembly. It archives only bounded release outputs, not SDK or build caches.
  A tar.gz preserves modes and symlinks inside the uploaded ZIP artifact.
  Missing expected output fails the job.

| Artifact (7-day retention) | Release output |
| --- | --- |
| `flutter-build-android-<abi>` | `build/app/intermediates/flutter/release` |
| `flutter-build-windows` | `build/windows/x64/runner/Release` |
| `flutter-build-linux` | `build/linux/x64/release/bundle` |
| `flutter-build-macos` | `build/macos/Build/Products/Release/*.app` |
| `flutter-build-ios` | `build/ios/archive/*.xcarchive` |
| `flutter-build-ohos` | `ohos/entry/libs/arm64-v8a/libapp.so` and `ohos/entry/src/main/resources/rawfile/flutter_assets` |

Each Flutter artifact includes the tar.gz, its `SHA256SUMS` and
`provenance.json` with source/core/Flutter/native-run identity and archive size.
Android artifacts are ABI-qualified because the two jobs upload concurrently.
Final `app-*` artifacts retain their existing 30-day policy and signing logic.
OHOS requires both nonempty AOT and assets payloads. Assemble `.stamp` files
alone must never satisfy this contract.

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
- Cloud: all validation, reusable-native and platform jobs conclude `success`
  (Android runs once per ABI). The run lists seven `app-*` artifacts and seven
  `flutter-build-*` artifacts, plus native dependencies, slices and diagnostics.
- Before each push: `git log github/main..HEAD` holds only CI commits. Author,
  committer and message hold no AI signature.

`test_ohos_build.py` runs `package()` against a temporary directory. It patches
`ohos_build.PROJECT` and sets the GitHub variables with `mock.patch.dict`.

`WindowsPortableTest` uses temporary dummy files and mocks every compiler
and executable invocation. It checks numeric version arguments (including
versions without a build number), propagation through `package_windows`,
paths with spaces, NSIS required definitions, staging cleanup after compiler
failure and rejection of a missing compiler output. Extraction checks assert the
positional directory argument, paths with spaces, repeat invocation, rejection
of missing or unexpected files, the completion marker, process failures and
untrimmed `GetOptions` output in the script. The tests perform no native build.
Actual Windows compiler execution and installation remain cloud-only checks.
No unit test runs the Linux, macOS and iOS commands of `package_app.py`.

## 7. Wrong vs Correct

Wrong: pass `portable.exe /EXTRACTONLY /D=C:\temp\extract` and expect
`GetParameters` to retain the directory.
Correct: pass `portable.exe /EXTRACTONLY "C:\temp\extract with spaces"` and
use the `GetOptions` result directly as the extraction directory.

Wrong: push migration commits directly or assume a clean worktree proves that
every outgoing file is safe to publish.
Correct: integrate reviewed work on main, commit only reviewed paths, and use
the orchestrator's exact-commit push gate. Check the matching gate result before
pulling the destination. The migration execution contract records this boundary.

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

This section records historical limits. Later validation and migration evidence
supersede claims about which dispatch modes have been exercised.

- No cloud run has used `workflow_dispatch`. Platform selection and
  `native_run_id` are covered only by review and by the unit tests of
  `select_artifact`.
- Historical runs before cloud validation lacked actionlint and shellcheck.
  The `actionlint` job now runs both on GitHub-hosted Ubuntu.
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

## Migration acceptance and native reuse (2026-11-27)

Run `45892017304`, attempt 2, accepted all six platforms at application commit
`82f344657b5074698aa934db77408599d26024c5`: 20 successful jobs and 28 artifacts.
The migration task records exact artifact metadata and signing limits.

A manual main run may use `target=all` and `native_run_id=45892017304` only
after comparing native sources, native workflow, dependency pins and build
configuration with that accepted commit. The selector accepts an explicit run
from another branch; it does not prove source equivalence. The coordinator must
record that comparison. Reject reuse after any relevant input drift or expiry.

A reuse run skips the reusable native job and still runs hosted validation plus
all application jobs. Expect seven application and seven Flutter artifacts.
Record the older native owner run separately. Do not claim new native artifacts
or identical application/native commits. Native checksums are verified in the
hosted mobile jobs before extraction.

The independent `project-records.yml` workflow checks controlled Chinese in
`AGENTS.md` and `.trellis/PROJECT_STATUS.md`. These text checks also run only on
GitHub-hosted runners. A records-only change does not require a native rebuild.
