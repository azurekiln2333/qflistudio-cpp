# CI installer builds for six platforms

## Goal

GitHub Actions builds downloadable application packages for Android, iOS, OHOS, Linux, Windows and macOS.
Today the repository only builds native dependency packages. A user cannot download an installable application from CI.

## Background

- The only workflow is `.github/workflows/native-artifacts.yml`. It builds native dependency packages for Android (arm64-v8a, x86_64), OHOS ARM64 (plus WASI resources) and iOS (XCFramework). It builds no APK, HAP or IPA and nothing for desktop.
- GitHub remote: `github` = `azurekiln2333/qflistudio-cpp` (public). `github/main` = `ba5c33a`. Local `main` is 20 commits ahead. Those commits stay unpublished (user decision). Commit `ed4c9c0` holds a release signing configuration.
- The application depends on the sibling repository `azurekiln2333/qflistudio-core` (public) through `../qfli_studio_core`. The sibling application `qfli_dart` pins core `573d1b6eecf1c2b392ad753264a5a09f62f8335e`, stock Flutter 3.41.9 (`00b0c91f06209d9e4a41f71b7a512d6eb3b9c694`) and Flutter OHOS `3.41.9+ohos-1.0.2` (`62357a93d653bf844f730bb1f4b7cc9e2139d14e`). Its workflows are green and serve as templates.
- `github/main` analyzes clean against core `573d1b6` with the local Flutter OHOS SDK (`flutter analyze`: no issues, checked 2026-11-17 in a scratch export).
- Mobile and OHOS packages need the native dependency packages. Successful run `44001588302` on `main` provides unexpired artifacts (30-day retention).
- Desktop applications call a host `clang` or `gcc` from `PATH` (`lib/clang_runner.dart`). They bundle no compiler.

## Requirements

- R1. One workflow builds application packages for all six platforms. A manual run can select one platform.
- R2. Android: one APK per ABI (arm64-v8a, x86_64) that contains the native toolchain libraries and the toolchain asset for that ABI.
- R3. iOS: an unsigned Xcode archive and an unsigned IPA that link the portable runtime and contain the WASI SDK resources.
- R4. OHOS: an unsigned ARM64 HAP and APP that contain the native runner library and the WASI resource archive.
- R5. Windows x64: an installer executable and a portable ZIP.
- R6. Linux x64: a Debian package and a tar.gz bundle.
- R7. macOS: a disk image with an ad hoc signed universal application.
- R8. Mobile and OHOS jobs take native inputs from the newest unexpired `Native artifacts` output on `main`. A manual run can pin a run id. A missing or expired input fails with a clear message.
- R9. Each download holds checksums, a signing note and a provenance record (application commit, core commit, Flutter commit, native input run, validation list).
- R10. The CI copy never uses local signing material. No secret, key or keystore path is added to the repository.
- R11. Only CI commits reach GitHub. Commits use conventional messages and carry no AI signature. A scan confirms this before each push.
- R12. A Chinese document explains the packages, the download steps and the signing limits.

## Acceptance Criteria

- [x] AC1 (R1): a run of the new workflow on GitHub finishes green for all jobs.
- [x] AC2 (R2): each Android download holds an APK whose `lib/` has exactly one ABI with `libflutter.so`, `libapp.so`, `libqfli_clang.so`, `libqfli-ld.lld-.so`, `libqfli_executor.so`, `libc++_shared.so`, plus `assets/qfli_toolchain/<abi>.zip`.
- [x] AC3 (R3): the iOS download holds an `.xcarchive.zip` and an `.ipa`. The IPA has `Payload/Runner.app/Runner` (arm64) and `forge-wasi-sdk/toolchain.json`.
- [x] AC4 (R4): the OHOS download holds a HAP and an APP. The HAP has `libs/arm64-v8a/libqfli_ohos_runner.so`, `libflutter.so`, `libapp.so` and `resources/rawfile/qfli_toolchain/ohos-wasi.zip`.
- [x] AC5 (R5): the Windows job installs the setup executable silently, compares the installed file list with the build output and uninstalls it.
- [x] AC6 (R6): the Linux job installs the `.deb` through apt, resolves every shared library of the launcher and removes the package.
- [x] AC7 (R7): the macOS job mounts the disk image, verifies `arm64` and `x86_64` in the executable and passes `codesign --verify --deep --strict`.
- [x] AC8 (R8): a job with no usable native input fails with a message that names the `Native artifacts` workflow. Evidence is a unit test and a review. No cloud run showed this failure.
- [x] AC9 (R9): every download holds `SHA256SUMS`, `SIGNING.txt` and `provenance.json`.
- [x] AC10 (R10, R11): `git log github/main..<pushed head>` shows only CI commits, no `claude`, `anthropic` or `co-authored` text, and no file from the 20 local commits.
- [x] AC11 (R12): `python scripts/ste-lint-zh.py tool/ci/README.md` reports no finding that needs a rewrite.

## Acceptance evidence (2026-11-17 UTC)

Two runs of "Application installers" ended with seven of seven jobs `success`:

- Run `44125206686`, branch `main`, commit `1969ef4`.
- Run `44120892921`, branch `ci/app-installers`, commit `5a9522a`.

The public GitHub API gave the run, job and step results and the artifact names and sizes.
No package was downloaded, opened or installed. Each content check ran inside its job.

| Criterion | Evidence | Limit |
| --- | --- | --- |
| AC1 | Both runs | No manual run happened. Review alone covers the platform selection of R1 |
| AC2 | Step "Verify and package the APK" passed in both Android jobs. `test_ci_helpers.py` tests the entry checks | No APK was downloaded |
| AC3 | Step "Package and verify the unsigned IPA" passed | No unit test runs the `ios` command |
| AC4 | Step "Verify and package the HAP and APP" passed. `test_ohos_build.py` tests the entry checks and `package()` | No package was downloaded |
| AC5 | Step "Build and verify the installer" passed | No unit test runs the `windows` command |
| AC6 | Step "Build and verify the Debian package" passed | No unit test runs the `linux` command |
| AC7 | Step "Build and verify the disk image" passed | No unit test runs the `macos` command |
| AC8 | `MainTest.test_missing_input_fails_and_names_the_source_workflow` checks exit 1 and the message. No workflow step uses `continue-on-error` | No cloud run showed this failure |
| AC9 | One `write_records` call serves the five `package_app.py` commands. `ohos_build.package()` writes the same records. Unit tests check the output file set of the `android` command and of the OHOS `package` command. Each upload uses `if-no-files-found: error` | The file list of a download was not read |
| AC10 | Scan of `ba5c33a..1969ef4`: five commits, 13 new files, no match in author, committer, message or diff. No file overlaps the 20 local commits. `ed4c9c0` is not an ancestor | None |
| AC11 | Lint of the committed `tool/ci/README.md`: 0 findings | None |

Device execution and UI execution were not tested (out of scope).

## Out of Scope

- Store signing, notarization, Apple provisioning, OHOS release signing, Android release keystore.
- GitHub Releases publishing. Downloads are Actions artifacts (30 days).
- Device or UI execution tests. CI verifies build, package layout and installer round trips only.
- Publishing the 20 local commits or the uncommitted core changes.
- Web packages. `flutter analyze` and `flutter test` gates.
- A bundled desktop compiler. Desktop packages still need a host `clang` or `gcc`.
