# Implementation

- [x] Audit local packages, hashes and OHOS prebuilt linkage.
- [x] Verify GitHub repository write access and Actions enablement.
- [ ] Add Linux Android build bootstrap and portable package-tool discovery.
- [ ] Add workflow with Android ABI jobs and an independent WASI resources job.
- [ ] Add package manifest/checksums and user-facing artifact instructions.
- [ ] Run syntax and targeted validation; review changes independently.
- [ ] Commit task changes and push test branch; observe real Actions runs.
- [ ] Fix cloud failures, verify produced artifacts, record run/download URLs.
- [ ] Update build contract and session record with actual outcomes.

Rollback: revert the CI commits on the test branch. Existing local native
outputs, main branch and Windows build entry points remain available.
