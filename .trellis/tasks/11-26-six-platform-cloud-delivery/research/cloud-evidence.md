# Six-platform cloud delivery evidence

## Accepted run

- Repository: `azurekiln2333/qflistudio-cpp`.
- Branch: `ci/cloud-validation`.
- Workflow: `.github/workflows/app-installers.yml` (`Application installers`).
- Successful run: `45892017304`, attempt `2`, `workflow_dispatch`, target `all`.
- Tested source: `82f344657b5074698aa934db77408599d26024c5`.
- Run result: `completed / success`; all 20 jobs report `success`.
- Completion: `2026-11-26T22:29:59Z` (November 27, 2026, UTC+08:00).
- This source includes main `918233c5f32e848e63df11fa4e25639cdf17053a` through merge `50bfd0b83377cd87f5521e6a585f15eff08b7430`.
- The evidence-only follow-up commit does not change the validated workflows or source. Its delivery SHA is recorded in the external cpp-ci report.
- No main push, rebase or force push was performed. The coordinator owns integration into main.

## Pinned inputs and native provenance

| Input | Accepted revision / source |
| --- | --- |
| Shared core | `cbaa4a4166461baafff7c1a343bd3ca1865fcc4f` (unchanged) |
| Core directory | `../qflistudio-core` |
| Dart package name | `qfli_studio_core` (unchanged) |
| Stock Flutter | `3.41.9` @ `00b0c91f06209d9e4a41f71b7a512d6eb3b9c694` |
| Flutter OHOS | `3.41.9+ohos-1.0.2` @ `62357a93d653bf844f730bb1f4b7cc9e2139d14e` |
| Native workflow | Reusable `.github/workflows/native-artifacts.yml` at the tested application source |
| Native artifact owner run | `45892017304` (the same parent run, not an older standalone native run) |
| Android native inputs | `qfli-native-android-arm64-v8a`, `qfli-native-android-x86_64` |
| iOS native input | `qfli-native-ios`, assembled from three slice artifacts in this run |
| OHOS native input | `qfli-native-ohos-arm64-v8a` |
| Desktop native run ID | `null`: desktop packages consume no mobile native artifact |
| actionlint | Official `v1.7.11` Linux amd64 binary; SHA-256 `900919a84f2229bac68ca9cd4103ea297abc35e9689ebb842c6e34a3d1b01b0a` |

Mobile jobs verify native archive sidecars before extraction and propagate the verified `nativeInput` record and `nativeRunId` to final package provenance. Stock builds prepare the pinned core compatibility patch. OHOS uses its unpatched pinned core. This task did not update dependency revisions or signing logic.

## Validation results and resolved failures

- Strict `flutter analyze --no-pub`: `No issues found!`.
- Full `flutter test --no-pub --concurrency=1`: **268 tests passed**. No tests were filtered, skipped by the workflow, retried to hide failures or changed by this task.
- Flutter validation runs on `windows-2022` because existing PATHEXT fixtures use real files and require case-insensitive filesystem behavior. `QFLI_CC` / `QFLI_CXX` select the hosted GCC/G++ toolchain through existing application interfaces.
- Serial test execution removes contention around startup fixtures with short wall-clock floors. No warning/info exemptions were needed for Flutter analysis.
- Python helper tests pass in GitHub Actions, including core path/pin assertions, release-output archives and final package provenance.
- actionlint checks both workflow files and invokes shellcheck. Only SC2016 on two intentionally literal Markdown summary blocks is suppressed.
- First run `45873295906` exposed Linux fixture assumptions and literal Markdown shellcheck findings. Second run `45874175450` exposed startup timing contention. Both failures were recorded and fixed without editing product or `test/` sources.
- Run `45874912699` had all 20 jobs successful at `5d2b932f566b6713dc5e5b369a6508fdd938c422`, but content review found its OHOS archive held only stamp files. It is **not accepted** as complete intermediate-output evidence.
- After merging main, run `45890573181` was superseded by the OHOS payload correction. It is not the accepted run.
- Accepted run `45892017304`, attempt 1: 19 successful jobs, Android x86_64 failed while downloading Kotlin POMs because Maven Central returned HTTP 429. The failed-job rerun endpoint was used without changing source. Attempt 2 completed successfully.
- Local `gh run watch` connections occasionally ended with EOF/TLS errors. Reconnecting did not alter source or artifact provenance.

## Flutter intermediate outputs and size boundary

Do not upload whole `build/`, SDK, Gradle, DerivedData or Hvigor caches. Estimated cache sizes were 1–5 GB for Android and 2–10 GB for iOS. The pre-upload decision was to retain only bounded release outputs for seven days. The external report records these estimates before implementation.

Each Flutter artifact contains a tar.gz preserving modes/symlinks, `SHA256SUMS`, and `provenance.json` with source/core/Flutter/native-run identity, archive byte size and SHA-256. Android is split by ABI to avoid concurrent upload collisions.

| Artifact | Actual release payload, captured before installer assembly |
| --- | --- |
| `flutter-build-android-arm64-v8a` | `build/app/intermediates/flutter/release` from the ARM64 job |
| `flutter-build-android-x86_64` | `build/app/intermediates/flutter/release` from the x86_64 job |
| `flutter-build-windows` | `build/windows/x64/runner/Release` |
| `flutter-build-linux` | `build/linux/x64/release/bundle` |
| `flutter-build-macos` | `build/macos/Build/Products/Release/*.app` |
| `flutter-build-ios` | `build/ios/archive/*.xcarchive` |
| `flutter-build-ohos` | `ohos/entry/libs/arm64-v8a/libapp.so` and `ohos/entry/src/main/resources/rawfile/flutter_assets` |

The accepted OHOS archive is **7,421,736 bytes** before the GitHub artifact wrapper, not the rejected 498-byte stamp-only archive. Its inner tar.gz SHA-256 is `d6cf72a5b8bf11f46790fff6f7384c69d30fd92cd87235c1206ff6d20952ee9f`. The archive helper now rejects missing/empty AOT, missing assets and stamp-only output; cloud tests cover those failures. The uploaded artifact wrapper is 7,422,814 bytes, with its distinct API digest listed below.

## Final packages, checksums and signing limits

Every `app-*` artifact includes its package files, `SHA256SUMS`, `provenance.json`, `SIGNING.txt` and `LICENSE`. The provenance records application/core/Flutter commits, Flutter version, native input/run ID, package sizes and SHA-256 values. OHOS also includes its HAP inventory. Existing package layout and install/uninstall checks remain enabled.

| Artifact | Final package files | Signing state |
| --- | --- | --- |
| `app-android-arm64-v8a` | `qfli-forge-android-arm64-v8a-test-signed.apk` | Ephemeral test/debug signature |
| `app-android-x86_64` | `qfli-forge-android-x86_64-test-signed.apk` | Ephemeral test/debug signature |
| `app-windows-x64` | `qfli-forge-windows-x64-setup.exe`, `qfli-forge-windows-x64.zip`, `qfli-forge-windows-x64-portable.exe` | Unsigned |
| `app-linux-x64` | `qfli-forge-linux-x64.deb`, `qfli-forge-linux-x64.tar.gz`, `qfli-forge-linux-x64.AppImage` | Unsigned |
| `app-macos-universal` | `QFLIForge-macos-universal.dmg` | Ad hoc signed, not notarized |
| `app-ios-arm64-unsigned` | `QFLIForge-ios-arm64-unsigned.ipa`, `QFLIForge-ios-arm64-unsigned.xcarchive.zip` | Unsigned; requires Apple signing before device installation |
| `app-ohos-arm64-unsigned` | `qfli-forge-ohos-arm64-unsigned.hap`, `qfli-forge-ohos-arm64-unsigned.app` | Unsigned; requires HarmonyOS certificate/profile before device installation |

Cloud package success is not device acceptance. UI execution and mobile device runtime are not established. `deviceRuntimeVerified` remains false. No package, native dependency, SDK or build cache was downloaded or executed locally.

## Evidence collection

Metadata was read from GitHub after successful completion. Artifact payloads were not downloaded. API `digest` values below describe uploaded artifact ZIPs, not their inner installers or tar.gz files. Inner files have separate `SHA256SUMS` entries. Retention follows workflow policy and is corroborated by `expires_at` (measured from upload time, with API rounding).

```text
gh run view 45892017304 --repo azurekiln2333/qflistudio-cpp --json status,conclusion,headSha,attempt,jobs
gh api repos/azurekiln2333/qflistudio-cpp/actions/runs/45892017304
gh api repos/azurekiln2333/qflistudio-cpp/actions/runs/45892017304/artifacts --paginate
gh run view 45892017304 --repo azurekiln2333/qflistudio-cpp --log-failed
```

## Job conclusions

| Job | Conclusion |
| --- | --- |
| Flutter analyze and test | success |
| Actionlint workflow checks | success |
| Python CI helper tests | success |
| Android x86_64 APK | success |
| Build native dependencies / OHOS ARM64 native and resources | success |
| Build native dependencies / iOS iphoneos-arm64 | success |
| Build native dependencies / iOS iphonesimulator-x86_64 | success |
| Build native dependencies / iOS iphonesimulator-arm64 | success |
| Build native dependencies / Android x86_64 | success |
| Build native dependencies / iOS XCFramework and resources | success |
| Android arm64-v8a APK | success |
| OHOS ARM64 unsigned HAP and APP | success |
| Check native artifact availability | success |
| iOS ARM64 unsigned IPA | success |
| Windows x64 (x86_64) packages | success |
| Linux x64 (x86_64) packages | success |
| Build native dependencies / Android arm64-v8a | success |
| Build native dependencies / Record native artifact run ID | success |
| Build native dependencies / OHOS WASI resources (data only) | success |
| macOS universal disk image | success |

## Artifact inventory

All 28 artifacts were unexpired at collection. Size is exact API bytes. Every digest is SHA-256.

| Artifact | Bytes | Digest | Retention | Expires at (UTC) |
| --- | ---: | --- | ---: | --- |
| `app-android-arm64-v8a` | 68025117 | `sha256:7490391ef8a7b9867650e6dd53ac5e1075a73e379ba1823502e3ac2ba3dcff27` | 30 days | 2026-12-26T22:14:31Z |
| `app-android-x86_64` | 71217620 | `sha256:a019cbe0e1451b4bb186457c0ecaa27dc43f471bbe3e541a4d834d0a5e81f74f` | 30 days | 2026-12-26T22:29:56Z |
| `app-ios-arm64-unsigned` | 212139026 | `sha256:e29ed25472f6abc79058ea785934e8c042227279751aa930136e0389100a0558` | 30 days | 2026-12-26T22:17:39Z |
| `app-linux-x64` | 63748305 | `sha256:9a37bef833b666811675b1aabc5535670940fbdc67aac5b6196c0d381f8d256c` | 30 days | 2026-12-26T20:39:44Z |
| `app-macos-universal` | 30680383 | `sha256:e8abf6ca49e9957100753812beacbc93b6864eac90a0d9b8b1a78c4dad0def05` | 30 days | 2026-12-26T20:42:09Z |
| `app-ohos-arm64-unsigned` | 224472567 | `sha256:e42e78a5ca958e969b3d246e09b45ad80c293a23015c82c6774c6764d4fe8757` | 30 days | 2026-12-26T22:14:08Z |
| `app-windows-x64` | 50511622 | `sha256:3da39c6642871cdd9b24455383f5b7aac1f5a2668108e50d5b942c5f4de1e95b` | 30 days | 2026-12-26T20:41:07Z |
| `flutter-build-android-arm64-v8a` | 12518133 | `sha256:be9638898aed7fc7cbc21e1b9132710903ef1a8d95ebbc590419e314acc1e996` | 7 days | 2026-12-03T22:14:28Z |
| `flutter-build-android-x86_64` | 12650644 | `sha256:39eee0e843b0902b9860099c34f5203c2fd2387c746d87365911343337c0a60d` | 7 days | 2026-12-03T22:29:54Z |
| `flutter-build-ios` | 118742538 | `sha256:957979000c94d496a19734b9f0ed7466fa58fbb4ca0dcfd5697391f78c9445b3` | 7 days | 2026-12-03T22:16:37Z |
| `flutter-build-linux` | 24010520 | `sha256:a38e5b6e49e3efb7bff7380d03fcdbae24f41e1839bcb41d220c38c6bb4125c1` | 7 days | 2026-12-03T20:39:18Z |
| `flutter-build-macos` | 26840763 | `sha256:fa795c9ea012caddeecefef73a111d20a55d865536e3a693bce2fedea0051b23` | 7 days | 2026-12-03T20:41:51Z |
| `flutter-build-ohos` | 7422814 | `sha256:a529ff832d4889bc8eb0593fb06e1d615a4a4f76a4bf31bcb99f472f26f8ac48` | 7 days | 2026-12-03T22:14:06Z |
| `flutter-build-windows` | 17635389 | `sha256:323f32df99ccc19d5f41ee92102b0a1e03c0a34a8cc4e37e8a3bbe995cbd4b4e` | 7 days | 2026-12-03T20:40:28Z |
| `ios-slice-iphoneos-arm64` | 104814889 | `sha256:6dc9f83975806d0a9e1a9c9c724bf8b0516eccd77f87b03aa6c9a4433f5a0ebd` | 7 days | 2026-12-03T22:01:31Z |
| `ios-slice-iphonesimulator-arm64` | 104911056 | `sha256:abbdb5e89bb9225247039bdd4447aedc2d286995bdf437254fac5523d016b8c2` | 7 days | 2026-12-03T21:58:11Z |
| `ios-slice-iphonesimulator-x86_64` | 103023276 | `sha256:eb2545a29e4581703d7567b4275ec2742ce7f4c96c66fbebfa701a07962e7c68` | 7 days | 2026-12-03T21:54:48Z |
| `logs-android-arm64-v8a` | 251311 | `sha256:69fae1de848c2a6e1cb58b93dd28f973c64eb3dc1e3206a9164aceca7ef58808` | 7 days | 2026-12-03T21:10:20Z |
| `logs-android-x86_64` | 238015 | `sha256:d70b37fa240f4fab1fc308301cb4894f93adc806cd33cf107dcea7daa57877ef` | 7 days | 2026-12-03T21:06:55Z |
| `logs-ios-iphoneos-arm64` | 5366261 | `sha256:26ee7f61dbc9dee7a123782aa2f874b21d99599859471cfa4f2a8742c821bcd6` | 7 days | 2026-12-03T22:01:45Z |
| `logs-ios-iphonesimulator-arm64` | 5365220 | `sha256:f34858c34290246ff50348a84e2c6de1ea14613cb982444e80469b3e39cdd175` | 7 days | 2026-12-03T21:58:23Z |
| `logs-ios-iphonesimulator-x86_64` | 5295055 | `sha256:dd4aacaad7cb8d8391594e4dfb087a063bc47ad5ef80ce4aa20234d61add040d` | 7 days | 2026-12-03T21:54:58Z |
| `logs-ohos` | 42875603 | `sha256:057e8121e75c03463dac960702d297e8a8127a0fcd2fd675da24c826a410ec6b` | 7 days | 2026-12-03T21:27:01Z |
| `qfli-native-android-arm64-v8a` | 54923920 | `sha256:2f81b23ad7472965e385eb6ed44edb9107eeaa284c73406804e511b6024d0f7b` | 30 days | 2026-12-26T21:10:19Z |
| `qfli-native-android-x86_64` | 57682511 | `sha256:ed1b6c408a3978ffdb1267ad31e3ae5d18c45446bcb1a00e8e6878dca6b27193` | 30 days | 2026-12-26T21:06:51Z |
| `qfli-native-ios` | 432818562 | `sha256:61f9c4b41c0ae818dbee87ec735040149c078ac9df044790cb82b5c786bf8547` | 30 days | 2026-12-26T22:09:06Z |
| `qfli-native-ohos-arm64-v8a` | 132986439 | `sha256:b394fb54cbae9f5429738a236c4b14489c5a9d56af7b8ab2fefedf3ed71c400f` | 30 days | 2026-12-26T21:26:53Z |
| `qfli-ohos-wasi-resources` | 15937792 | `sha256:278ff69dd350540601bdc5fe3443abe689975d1e4a78f080ca8df812f86904ca` | 30 days | 2026-12-26T20:37:48Z |
