# Implementation

- [x] Audit local packages, hashes and OHOS prebuilt linkage.
- [x] Verify GitHub repository write access and Actions enablement.
- [x] Add Linux Android build bootstrap and portable package-tool discovery.
- [x] Add workflow with Android ABI jobs and an independent WASI resources job.
- [x] Add package manifest/checksums and user-facing artifact instructions.
- [x] Run syntax and targeted validation; review changes independently.
- [x] Commit task changes and push test branch; observe real Actions runs.
- [ ] Fix Linux Android libc++ discovery and add early resource preflight.
- [ ] Add full OHOS SDK bootstrap, archive build and artifact export.
- [ ] Add iOS slices, XCFramework assembly and local installation helper.
- [ ] Run all three platform workflows and inspect uploaded artifacts.
- [ ] Update build contract and session record with actual outcomes.

Rollback: revert the CI commits on the test branch. Existing local native
outputs, main branch and Windows build entry points remain available.

## Observed cloud runs

- Run 43919882389 exposed duplicate curl/tar executable resolution on Linux.
  Fixed with explicit first-command selection. The run was superseded.
- Run 43920643526 produced the OHOS WASI resource artifact. The downloaded
  tarball SHA256, inner inventory and all 4114 resources were verified locally.
  Android LLVM compilation succeeded but resource fixture validation failed:
  Ubuntu clang-15 could not find the packaged C++ algorithm header.
- Public CI commits are cherry-picked onto GitHub main in native/build/ci-publish.
  Original unpushed commits and local signing configuration are not included.
