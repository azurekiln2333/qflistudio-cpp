# Validation and cloud evidence

## Selected sources

- Application base: github/main 1969ef40d69134e45eaab6b558d71b96cf9be68a.
- Core: published main cbaa4a4166461baafff7c1a343bd3ca1865fcc4f.
- Native input: successful main run 44001588302. All four mobile packages were unexpired.
- Preview core 72c0b09 was not included.
- Isolated app and core use sibling worktrees.
- App branch: `ci/ui-core-installers-20261121`. Core commit: `cbaa4a4166461baafff7c1a343bd3ca1865fcc4f`.
- Original dirty app/core worktrees were preserved.

## Local validation

- flutter pub get succeeded. The lock adds crypto, web_socket and web_socket_channel.
- flutter analyze reported no issues.
- flutter test --concurrency=2 passed 217 tests.
- Editor regressions passed at desktop C and phone C++ sizes.
- Python CI helpers passed 90 tests.
- The selected core compatibility patch applied and passed its check.
- Task context validation and git diff --check passed.
- Chinese lint passed for the project status and this record.

The installed SDK is the existing OHOS Flutter build with Dart 3.11.5. The cloud workflow used its pinned official Flutter builds. No device UI or runtime acceptance is implied.

## Cloud run

Run 44797136694 completed successfully on 2026-11-20 UTC.
https://github.com/azurekiln2333/qflistudio-cpp/actions/runs/44797136694
The branch was ci/ui-core-installers-20261121.
The application commit was 6908e44ecb5edbc8a3a1388d40ec8d3166a35ac5.
The shared core commit was cbaa4a4166461baafff7c1a343bd3ca1865fcc4f.
All seven jobs succeeded. Android ran for two ABIs.

| Artifact | Package files |
| --- | --- |
| app-android-arm64-v8a | qfli-forge-android-arm64-v8a-test-signed.apk |
| app-android-x86_64 | qfli-forge-android-x86_64-test-signed.apk |
| app-windows-x64 | qfli-forge-windows-x64-setup.exe, qfli-forge-windows-x64.zip |
| app-linux-x64 | qfli-forge-linux-x64.deb, qfli-forge-linux-x64.tar.gz |
| app-macos-universal | QFLIForge-macos-universal.dmg |
| app-ios-arm64-unsigned | QFLIForge-ios-arm64-unsigned.ipa, QFLIForge-ios-arm64-unsigned.xcarchive.zip |
| app-ohos-arm64-unsigned | qfli-forge-ohos-arm64-unsigned.hap, qfli-forge-ohos-arm64-unsigned.app |

Artifact metadata matched both expected commits. ZIP metadata CRC and SHA256SUMS format checks passed. The verifier transferred 1,170,571 bytes using range requests. It did not download full packages or recompute payload hashes. No device run was performed.

Evidence is stored in cloud-evidence/ beside this record. Artifact retention ends 2026-12-20 UTC.

Android uses a temporary debug key. Windows and Linux packages are unsigned. macOS is ad hoc signed and not notarized. iOS and OHOS packages are unsigned.

## Main branch build after synchronization

Run 44822103705 completed successfully on 2026-11-20 UTC.
The run built app commit f2529c32da5e52ba1efbd0c44d685284f494e1fc.
The workflow pinned core commit cbaa4a4166461baafff7c1a343bd3ca1865fcc4f.
All seven jobs succeeded and uploaded non-expired artifacts.
Android, iOS, and OHOS jobs checked out the pinned core and verified native inputs.

| Artifact | Size in bytes |
| --- | ---: |
| app-android-arm64-v8a | 67638542 |
| app-android-x86_64 | 70828637 |
| app-windows-x64 | 31873405 |
| app-linux-x64 | 40235182 |
| app-macos-universal | 29868789 |
| app-ios-arm64-unsigned | 210506901 |
| app-ohos-arm64-unsigned | 223796963 |

The run confirms cloud build success, not device installation or runtime acceptance.
The verifier did not download full packages or recalculate payload hashes.

## Native workflow coverage

Native 工作流构建 Android 两种架构。
iOS 包含真机与模拟器静态库。
OHOS 构建 ARM64 编译器和 WASI 资源。
该工作流不生成桌面工具链包。
桌面包构建 Flutter runner 和插件。
桌面 C/C++ 编译仍调用系统 clang 或 gcc。
