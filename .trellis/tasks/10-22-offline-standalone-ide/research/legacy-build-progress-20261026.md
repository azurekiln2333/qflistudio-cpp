# Curated legacy build progress through 2026-10-26

Curated on 2026-11-27 by Herdr worker `w5R:p3`.
Purpose: retain portable knowledge from the preserved root build tree.
This is historical research, not a new validation run or a current-source acceptance claim.

## Preservation source and current authority

The preserved root is:

```text
D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127/source/build
```

Paths described as legacy paths below are relative to that root.
The date in this filename describes the historical checkpoint, not the curation date.
Selected source documents and their SHA-256 identities appear at the end.
Private/device records, certificate material, SDKs, caches and binaries were not copied.
No legacy runner or command was executed during curation.

Current repository `AGENTS.md` overrides historical local-execution instructions.
Future builds, tests, analysis and lint must run on GitHub-hosted runners.
Historical grants, prepared directories and release messages do not authorize reuse.

Keep these existing tracked sources as the acceptance record for their own dates:

- [`acceptance.md`](acceptance.md).
- [`shared-release-checkpoint-20261026.md`](shared-release-checkpoint-20261026.md).
- [`host-controls-20261026/`](host-controls-20261026/).
- [`host-baseline-20261026/`](host-baseline-20261026/).
- [`terminal-recovery-20261026/`](terminal-recovery-20261026/).
- [`tool/host_baseline/README.md`](../../../../tool/host_baseline/README.md), relative to the repository root.

## What was accepted, and what was not

| Historical result | Preserved conclusion | Boundary |
| --- | --- | --- |
| Original native host curriculum | All 100 C and 100 C++ programs passed with GCC C17 and Clang C++20. All 200 actual outputs were also byte-exact. All 402 recorded Linux groups ended empty. | Existing frozen host inputs, not current packaged OHOS or device proof |
| Original WASI host curriculum | Two distinct stdin inputs passed the actual transport gate. All 200 programs passed. All 403 groups ended empty. The 18,739-entry SDK inventory remained stable. | Existing bound probes and SDK, not newly built probe provenance |
| Earlier live process controls | Three Windows Job cases and five Linux group cases passed their recorded assertions. | Controls are distinct from the 200-program batches |
| Control-window timing | The runner took 14.789 seconds, but ACCEPT-to-RELEASE took 430.965 seconds against a 60-second grant. | Resource release was accepted, full-window timing failed |
| Native curriculum timing | Full publication took 252.408 seconds within a 1,265-second grant. | Historical recorded window only |
| WASI curriculum timing | Full publication took 962.050 seconds within a 1,265-second grant. | Historical recorded window only |
| Schema-2 fake controls | The historical report records 34 passing fake/stub cases. | No operating-system containment proof |
| C V3 candidate | Independent source review accepted the scoped custody/deadline design. Author controls recorded 12 Windows and 11 Linux pure passes. | Live custody, WSL, compiler/build and device checks remained unrun |
| V3 live-control harness | Independent source review accepted its controls-only design. The release checkpoint records 18 pure passes. | Planned normal/orphan/blocked-input live cases remained unrun |
| Curriculum expansion | The +160 coverage plan existed. | No new runnable pairs were authored or delivered by that checkpoint |

The accepted live-control cases covered normal exit, surviving descendants,
timeout cleanup, repeated cleanup signals and heartbeat loss.
A Windows Job containing `wsl.exe` does not by itself prove Linux descendants ended.
Private POSIX groups do not contain deliberately escaped sessions.

## Review sequence and contradictory evidence

Early readiness and schema-repair documents describe preparations before live execution.
Their `UNRUN` statements belong to those stages.
They do not cancel later accepted host-control or curriculum results.
Conversely, later host results do not validate every later source candidate.

The early provenance review identified missing persisted archive checks,
SDK inventories, exact stdin transport and live containment evidence.
Later archive metadata and accepted host batches addressed parts of that historical list.
Do not carry the whole early blocker list forward as if nothing happened afterward.
Binary-to-current-source correspondence and current package/device acceptance remained distinct gaps.

The live-control result also retained author boilerplate saying the author had not run it.
That wording conflicted with executed manifests and actual case evidence.
Keep the original evidence auditable and explain the discrepancy in companion text.
Do not silently rewrite raw reports to make them appear internally cleaner.

One final control review could not independently establish the outer exit/release message from its input files.
The existing tracked acceptance ledger records the coordinator's later outer-process observation.
The difference is evidence scope, not permission to infer outer termination from an inner Boolean.

## Durable process-control lessons

The schema-2 work improved the evidence contract:

- Bind the exact runner, manifest, run ID, nonce, input bytes and tool identities.
- Recompute success from original case IDs, actual exits and actual output bytes.
- Preserve stdout, stderr, stdin identities, per-step sidecars and incremental ledgers.
- Require nonempty step evidence and matching process/group identity before release.
- Treat permission failures, malformed identities and uncertain membership as unknown, not empty.
- Latch cancellation so cleanup can retain custody through failures.
- Keep resource cleanup, validation success, outer termination and final publication separate.

The historical schema-2 success tolerance normalized CRLF to LF and trailing LF.
It also reported byte-exact output separately.
The later original-200 native batch actually matched all expected output bytes.
Do not describe the older predicate itself as universally byte-exact.

An early review noted that generated control fixtures lacked their own manifest hashes.
A later final review found those fixture bytes equal to the already-bound embedded source.
That narrowed the immediate concern, while explicit fixture hashes remained a reproducibility improvement.

These are lessons for reviewed hosted tooling.
They do not authorize restoration or local use of the old launchers.

## Compiler/runtime provenance and the revised host plan

The historical `compiler-linux` tree built `native/compiler`, not the top-level picoc path.
It used Unix Makefiles and produced an x86_64 Linux probe, not a Windows executable.
Manual `*-fast.o` side objects were not necessarily members of the generated CMake link set.
A `compile_commands.json` covering LLVM dependencies did not describe the owning adapter translation unit.

Early compiler-readiness advice claimed ordinary Make would avoid regeneration because of timestamps.
The later independent review rejected that as a no-network guarantee.
Normal targets can invoke `cmake_check_build_system` before a post-build hash check.
`FETCHCONTENT_*DISCONNECTED=OFF` does not prove a download happened,
but it also does not prove that regeneration or outbound access is excluded.

The revised source plan selected direct, serial `/fast` recipes for each owning library and then its probe.
It bound top-level Makefiles, owning rules, dependency/progress files, flags, link inputs and archive-cleanup scripts.
It rejected unexpected configure/dependency orchestration instead of silently falling back.
The third step used the actual NAPI bridge regression with fresh owning-source objects.

The claim was intentionally narrow:

- Fast-target outputs were observed incremental outputs.
- Make success and unchanged output hashes did not prove freshly compiled probe objects.
- The bridge harness explicitly recompiled its owning compiler/runtime sources into fresh objects and an addon.
- Full dependency-source closure, extracted SDK closure, zero-outbound isolation and transitive executable closure were not established.
- Host NAPI behavior was not the original curriculum under newly built probes.
- Host results were not OHOS ABI, HAP or installed-device acceptance.

The later runtime boundary review also noted that a `/fast` path does not rerun configure-time patch helpers.
Its patch state comes from the retained dependency tree.
A dependency archive newer than patch files does not prove the archive contains those patches.
Timestamps and separate matching file hashes do not establish a source-to-binary causal edge.

The final tool inventory added required role `bridge-cxx` with selector `clang++-18`.
It brought the declared role count to 19 and addressed a missing PATH-selected compiler entry.
It still did not prove that this selector equaled the compiler named by an absolute cache path.
Candidate linker entries were not proof of the linker internally selected by the compiler.
No live build acceptance was created by that source-only improvement.

## V3 custody and deadline checkpoint

The observer review found that earlier finalization could close Windows handles
without matching Linux cleanup proof.
The V3 design therefore retained exact process/Job handles and Linux leader identity through uncertainty.
It retried failed individual handle closes instead of discarding custody.

The reviewed Windows candidate identity was:
`81a27c110360f6fe0e0f10127078574851411dd7c32a4092208c5c28cd94d96e`.
The reviewed Linux candidate identity was:
`017f38e1bc1d1d8f57bc62e2df45aca277beaea4130752f0f680b98a980d5041`.

Its intended contract included:

- Start budgets at Windows execute entry, before imports or preflight.
- Carry shared absolute payload/grant expiry without restarting the budget after setup.
- Recheck launch admission immediately before starting work.
- Use `NO_START_ADMISSION` only when start was never attempted and any created Job is proved empty.
- Retain HOLD after an uncertain attempted start or uncertain cleanup.
- Close started-child handles only after matching Linux proof, exact root termination and Job active0.
- Never signal a numeric process group again after reaping its retained leader.
- Publish no success after forced cleanup or a latched HOLD.

Pure controls establish only their simulated state transitions.
They do not prove live Win32, POSIX, WSL, storage-failure or clock behavior.
Admission checks are cooperative, not atomic creation deadlines or hard real-time guarantees.
Cleanup may exceed deadlines while retaining custody.
Permanent identity loss or unreadable evidence can require explicit coordinator intervention.

The reviewed live-control harness identity was
`0f6bd130253568468bb500e85185af7e7617b8188726b4283e6d0e9a0a1b879e`.
Its planned live scope was normal exit, orphan cleanup and FIFO-blocked input cancellation.
Its deterministic expiry/cancel-admission cases were pure-only coverage.
The preserved review and release checkpoint both kept live execution unrun.

## Shared-editor and terminal knowledge

The October source audit identified an attached-output error path
that could skip terminal-session finalization and strand the run lane.
The safe design retains worker ownership until exit and cleanup,
rather than unconditionally clearing a running flag after a transport error.
The audit itself was not a live reproduction.

The historical terminal failures had different causes:

- One window compiled, reached 36 passing tests and then stalled in the stdout-error ownership case.
- Another failed in the Dart frontend compiler before any test ran, with heap-exhaustion output.
- A wrapper timeout/exit 124 did not distinguish a hang from compiler death.
- Runner/input drift and missing runner identity weakened direct candidate attribution.

Do not turn the second failure into a failing product assertion or call the first an OOM.
Later terminal-recovery and shared-core checkpoints have their own scoped results.
They do not retrospectively authenticate every earlier candidate snapshot.

The same source audit found existing coverage for unsaved diagnostics snapshots,
stale-result rejection, workspace persistence, orphan guards and truthful preview panels.
Fake-provider coverage did not establish every product analyzer or real native debugger.
Shared-core findings belong to the core owner and are historical leads, not current defects asserted by this migration.

## Historical OHOS package and signing boundary

The legacy OHOS readiness report found matching stored hashes for selected source,
static archives, runner and HAP files.
It also found missing causal build/link records and incomplete whole-application input coverage.
Dart AOT, assets, ArkTS output, dependency resolution and shared-core bytes were not all bound by that older list.
One compiler-archive field appeared to describe a different intermediate stage without a clear label.

The portable conclusion is limited:
matching old files does not prove a current full-application build from current source.
A signature-check log without the checked package hash is not a complete package-binding record.
An older `.app` or `pack.info` must not be substituted for a newer HAP's provenance.
A host bridge suite does not establish user-created headers or mixed-source execution on an installed device.

This summary deliberately omits certificate identities, private signing paths,
device identifiers, raw device captures and package payloads.
Current policy keeps `ohos/build-profile.json5` tracked with its DevEco encrypted fields.
That policy does not prove credential validity or authorize production signing.
The accepted November cloud run has its own signing limits in the cloud-delivery evidence.

## Curriculum expansion remains a plan

The historical inventory was 200 pairs, with 100 C and 100 C++ entries.
The proposed expansion was 80 additions per language, reaching 360 pairs.
Original IDs must survive, with new IDs 101 through 180 in each language.
The runnable standard ceiling was C17 and C++20.

The preserved order was current packaged/installed-device OHOS baseline first,
then substantive authoring and per-case acceptance.
Independent coverage planning and tooling work did not close that baseline gate.
C and C++ authoring were separate owned changes.

Expansion would need consistent generator registration, validators, repository tests,
integration tests, pipeline counts and portable-regression inventories.
Adding catalog rows alone would not establish runnable accepted pairs.
Each pair would also need native, current portable and device results,
paired explanation/exercises, unique content and retained output/input identities.
No program or catalog row was added by this migration summary.
C/C++ evidence cannot close another product's acceptance gate.

## Selected preserved document identities

The values below identify the reviewed backup text, not application binaries.
They were read as file metadata during curation.
The native owner retains responsibility for native source candidates and raw trees.

| Legacy path | SHA-256 |
| --- | --- |
| `baseline-200-controls-final-review.md` | `185d0a333af707cb1ddd87c5698b8ed39f48c767c2b16a58f735690b85cd38b3` |
| `baseline-200-publication-inventory.md` | `b6041e626a35ddd821e057167c33f4f89299169e07d1ca9f6276c8cfe6767878` |
| `baseline-200-provenance-review.md` | `d7086a239a8cc6b1f005c4e295f165ce3a0ebb9239102b1b4d2442fb23a3ebb1` |
| `baseline-200-schema2-repair.md` | `05c746293972017731bff7b181c5c54663a4474cd634451a20f9497429f4bff1` |
| `c-current-compiler-rebuild-readiness.md` | `267549caefb44f53a6287e8e920fe9a5140a45d7342762d234d8b246a9e6ccad` |
| `c-current-runtime-final-review.md` | `4c5a410be607799c138e51d854ef78ee0e4c7a4eef3ec159f22500e304b7ab60` |
| `c-current-runtime-boundary-delta.md` | `f2b875eb195136cf77a346aa9ebb31707de290b4c52969bbe390bfdc3daf29d3` |
| `c-current-ohos-readiness.md` | `fa74d457621d27eea0386b3593c4006825e69ce0680b123e0a4a42152e60ce0f` |
| `c-expansion-coverage-plan.md` | `bf8f50958cff51b36a5f6ecbaaa270e683990fce82ee8252a47d2fd78660f376` |
| `core-current-acceptance-audit.md` | `639d351ba3d56ddf0979323491c8675a6b351802e0d4e89afadf26058acee29e` |
| `current-toolchain-independent-review.md` | `9da66aeb89c89629a56052cebf8d941b84df46648cd85b1ee355e7b9f92a9873` |
| `current-toolchain-observer-review.md` | `174b81b5a31548da2679593bb42f444b25c8cebf85c43b671363fcfdd6848de4` |
| `current-toolchain-readiness.md` | `86db5f6ffb00ebb685e3f164e6ec22e7de37cd8967cc8b9fc52c9c2e77336817` |
| `current_toolchain_v3_review.md` | `c767fa12e1197d00159301c86f4effb0d6836f5faddbbddd99c79149c0c03da0` |
| `current_toolchain_v3_independent_review.json` | `a7cf5cd491d97735dcf4e3663f54fafc06c1e03bbb8b34e1d1f6d49f4c37d3db` |
| `current_toolchain_v3_live_independent_review.json` | `97232ceb11a07e4e928d8d0b1e6ace49c7a803ba5045ed037bbba7b21afda564` |

## Curation completion is not migration completion

This file resolves the status page's previously missing legacy-summary destination.
It preserves conclusions without broadening Git's build-directory exceptions.
It makes no decision about native-recovery candidates or cleanup inventory.
The coordinator still owns publication, final-head hosted checks and source/target equality.
Production signing, device acceptance and old-directory deletion remain separately gated.
