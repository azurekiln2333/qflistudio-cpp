> **HISTORICAL / CLOUD-ONLY OVERRIDE — 2026-11-27**
>
> The text below is a preserved historical PR draft, not current instructions or new verification evidence. Current AGENTS.md takes precedence. Do not download native packages, build artifacts, SDKs, installers, or caches to a local workspace. Do not run local builds, tests, lint, analysis, or dependency installation. Any download, extraction, checksum validation, or build described below may occur only in a disposable GitHub-hosted runner. Keep artifacts on GitHub. Historical run IDs and validation claims were not revalidated in this preservation pass. Do not execute the historical local-download or local-SDK instructions.

Build native dependency packages on hosted runners for Android ARM64/x86_64, complete OHOS ARM64, and iOS device ARM64 plus simulator ARM64/x86_64. Users can download the packages into the existing app build paths without rebuilding LLVM locally. GPL-3.0 LICENSE matches QFLIStudio.

Verified cloud results:
- Android and full OHOS: https://github.com/azurekiln2333/qflistudio-cpp/actions/runs/43940966765
- All iOS slices and XCFramework assembly: https://github.com/azurekiln2333/qflistudio-cpp/actions/runs/43952556198

The first run is red because its original iOS jobs failed; its Android and OHOS jobs succeeded. The separate final iOS run passed completely.

Each package contains checksums, source/SDK identity, license files and native validation records. Final packages remain for 30 days. Android packages extract into native/build/android-package; the full OHOS package extracts at the repository root; iOS extracts into native/build/ios-portable/package and uses the Python 3.9-compatible installer on the Mac.

Validation: both Android downloads passed SHA256, file inventories, ZIP CRC, binary hashes and all 8 link fixtures. The full OHOS download passed all 19 file hashes and 4114 resources; its API18 archives also linked the actual bridge against the local API26 SDK with ARM64/16KiB checks. All iOS slices passed architecture/export/native-link checks and XCFramework assembly. The final iOS download also passed all 10042 file hashes, source identity and XCFramework layout checks. Bash/PowerShell/Python syntax, actionlint and controlled Chinese checks passed.

These are native dependencies, not APK/HAP/IPA installers. App/device execution is not established by these builds. Web builds remain outside this workflow.
