# Implementation

- [x] Audit local packages, hashes and OHOS prebuilt linkage.
- [x] Verify GitHub repository write access and Actions enablement.
- [x] Add Linux Android build bootstrap and portable package-tool discovery.
- [x] Add workflow with Android ABI jobs and an independent WASI resources job.
- [x] Add package manifest/checksums and user-facing artifact instructions.
- [x] Run syntax and targeted validation; review changes independently.
- [x] Commit task changes and push test branch; observe real Actions runs.
- [x] Fix Linux Android libc++ discovery and add early resource preflight.
- [x] Add full OHOS SDK bootstrap, archive build and artifact export.
- [x] Add iOS slices, XCFramework assembly and local installation helper.
- [x] Run all three platform workflows and inspect uploaded artifacts.
- [x] Update build contract and verification records with actual outcomes.

Rollback: revert the CI commits on the test branch. Existing local native
outputs, main branch and Windows build entry points remain available.

## Observed cloud runs

- Run 43919882389 exposed duplicate curl/tar executable resolution on Linux.
  Fixed with explicit first-command selection. The run was superseded.
- Run 43920643526 produced the OHOS WASI resource artifact. The downloaded
  tarball SHA256, inner inventory and all 4114 resources were verified locally.
  Android LLVM compilation succeeded but resource fixture validation failed:
  Ubuntu clang-15 could not find the packaged C++ algorithm header.
- Public CI commits are cherry-picked onto a branch based on GitHub main in
  native/build/ci-publish, then pushed as ci/native-artifacts.
  Original unpushed commits and local signing configuration are not included.
- Run 43940966765 built both Android ABIs successfully. Both downloads
  passed archive SHA256, 20-file inventories, ZIP CRC, binary hashes and source
  identity checks. The resources-only download also passed verification.
  Full OHOS also succeeded and uploaded artifact 14266297771. The overall
  run is red because its original iOS jobs failed independently.
  Its download passed all 19 file hashes, 4114 resources, adapter/patch hashes,
  and source identity checks. The downloaded API18 archives also linked the
  actual bridge against the local API26 SDK, with ARM64 and 16KiB checks.
  Existing local packages were not replaced. Device execution is unverified.
- The original iOS jobs exposed a nested CMake try_compile archive-rule failure.
  Commit d615e99 propagates the Apple libtool rules through an override file.
  Run 43944200018 verified that archive preflight and the compiler probes pass,
  then failed because iOS defaults LLVM auxiliary targets to App Bundles.
- Commit 2febe32 disables the bundle default, checks the CLI install rule in
  early preflight and builds the smaller interpreter before target LLVM.
  The matching CMake default was reproduced locally: ON failed, OFF passed.
  Run 43948687527 passed early archive and CLI install checks, then exposed
  a missing root Ninja link pool in the WasmEdge dependency build.
- Commit 5e4d284 defines the runtime pool and defers host TableGen until the
  smaller runtime succeeds. A nested CMake/Ninja reproduction failed without
  the root pool and passed with it. Run 43952556198 retries only iOS.
  All three Apple slices and the XCFramework assembly job succeeded.
  The final iOS artifact is 14278134493. Its download passed all 10042 file
  hashes, source identity, three slice manifests and XCFramework layout checks.

## Completion evidence

- GPL LICENSE matches the main QFLIStudio project byte-for-byte. Public
  commit 6e8a7a9 contains the license and translated README notices.
- Complete platform trial results and artifact hashes are in
  research/complete-mobile-trial.json. Every final native download was verified.
- No existing native packages or user caches were removed or replaced.
- Test branch ci/native-artifacts and PR #1 contain the published changes.
  The main branch was not merged. Native app/device execution remains a
  separate gate; these artifacts are not APK/HAP/IPA installers.
