# Independent review of the native 200-example host run

Review date: 2026-10-26.
Evidence directory: `build/baseline-200-v2-native-20261025T172552Z-7d34ef1a`.
Run ID: `20261025T172552Z-7d34ef1a`.
Consumed grant: `C-native200-20261026-01`.

## Result

A separate read-only calculation reproduced **200/200 passing examples**:
100 C IDs (`c-example-001` through `c-example-100`) and 100 C++ IDs
(`cpp-example-001` through `cpp-example-100`). Both the frozen inventory and
result list contain exactly these 200 unique IDs.

The calculation read the recorded files directly. It did not import or run
the verifier, compiler, examples, WSL, or process-control helpers.
It compared each frozen source, stdin fixture, expected output, referenced
compile step, and referenced execute step. All 200 compile steps and all 200
execute steps exited with code 0. All 200 execution stderr streams were empty.
Each C command records `-std=c17`. Each C++ command records `-std=c++20`.

All **200 stdout streams were byte-exact matches** for their frozen expected
outputs. There were **zero byte-exact differences** in this run.

## Output comparison policy

The verifier's acceptance policy is strict UTF-8 decoding, CRLF-to-LF
replacement, removal of all final LF characters, zero execution exit status,
and empty execution stderr. It does not trim spaces or internal newlines.
The independent calculation recomputed that policy from the recorded bytes.
All 200 normalized comparisons passed. No normalization difference was needed
to make any of these 200 native examples pass because their stdout bytes
already matched exactly.

## Ledger and cleanup evidence

The ledger has **402 sequential steps and 402 distinct leader identities**:
two compiler-version steps plus 200 compile/execute pairs. Each leader has a
recorded PID, process group, session, and start tick. Its PID equals its group
and session ID. Each step contains its matching leader in the before-cleanup
observations. Before-cleanup members belong to that group. Any members left
before reaping are recorded as zombies in that group.

All **402 steps** record `cleanupVerified: true` and an empty
`remainingAfterReap` list. All 402 JSON sidecars match their ledger entries.
All 1,206 stdin/stdout/stderr files match the ledger's SHA256 values.
All stdout/stderr Base64 payloads match their corresponding files.
The 400 example compile/execute references are distinct and point to their
own example directories and expected step types.

The report's embedded ledger matches `steps.json`. The start, report, and
completion records agree on the run ID, nonce, and supervisor identity.
The launch manifest hash and completion report/ledger hashes match the files.
No discrepancy arose in these read-only checks.

The Windows owner record reports suspended creation and assignment before
resume for PID `73608`, creation FILETIME `134374307109045573`.
It records terminal exit code 0, Job active-process count 0, closed handles,
no cleanup errors, `evidenceVerified: true`, and `slotReleased: true`.
Its recorded elapsed time is 104.184 seconds. This audit checks the durable
owner record; it does not independently observe the historical live handle.

## Recorded compiler identities

The version steps record GCC 13.3.0 and Ubuntu Clang 18.1.3.
The run report records these resolved executable paths and hashes:

| Resolved executable | Recorded SHA256 |
| --- | --- |
| `/usr/bin/x86_64-linux-gnu-gcc-13` | `1b99826121ae6682a634e5efe09bd3e3df58ce58e0b28f849114ab5b89139c26` |
| `/usr/lib/llvm-18/bin/clang` | `8ef402d453d1ba4902e4ee0f0f847f6cfa01400c95aa43c24e97818b9c0e3f45` |

This review did not start WSL to rehash the installed compiler binaries.
The hashes above are the run's recorded identities.

## Evidence fingerprints

| File | Recomputed SHA256 |
| --- | --- |
| `manifest.json` | `b0f2eb4578a55ccd4b66f30844648182ab565986acd6a4e2926403a69405468a` |
| `report.json` | `9b3fbfc8b099ce352cae79b98a9798d65aae75420d5aba1a99fcd98349d6cdcd` |
| `steps.json` | `63df066df23f01cefb2c7c31100085fee89ba09650997fea40cd5613859d10b0` |

## Limits

This is actual host-native example evidence for the frozen run inputs.
It does not establish the separate WASI baseline, packaged OHOS behavior,
installed-device behavior, or current source-to-packaged-binary correspondence.
The report explicitly marks host-only evidence, false packaged/device flags,
and binary-source correspondence `UNPROVEN`.

Recorded process identities, nonces, hashes, and sidecars detect stale or
inconsistent local evidence. They do not authenticate evidence against
arbitrary same-user forgery. Private POSIX process groups do not contain a
process that deliberately escapes its session. Empty historical group
observations do not replace a fresh named grant for another execution.

This review added only this Markdown file. It did not modify the frozen
scripts, original run evidence, source tree, Git index, or active WASI run.
