# Final branch disposition and native preservation

Worker: w5R:p2. Date: 2026-11-27. Root coordinator: w5R:p1.

This is the final worker-owned reconciliation snapshot. Root owns integration, commits, the push gate, publication, target comparison, and handoff acceptance. No branch, ref, worktree, or source backup was deleted. Nothing was pushed by this worker.

## Exact comparison snapshot

- Local refs observed at 09:36:36 +08:00.
- Comparison main: `a9a10880962262aee86b24ee7975fb7d0578aef3`.
- Main tree: `febb95b5f433d637c6884336e239a4ebe9924b36`.
- Live heads and tags queried on all five remotes from 09:36:36 to 09:36:40 +08:00. All queries succeeded. No remote advertised tags. No local tag exists.
- Counts below are `main-only / ref-only` from `git rev-list --left-right --count <fixed-main>...<tip>`.
- A zero ref-only count proves ancestry containment, not publication of later local commits.
- GitHub main was `918233c5f32e848e63df11fa4e25639cdf17053a`, eight commits behind this fixed local main.
- These observations supersede earlier active-CI and main counts in reconciliation.md. They do not rewrite that historical report.
- No fetch, prune, merge, reset, clean, ref deletion, commit, push, or Git configuration change ran in this resumed worker pass. Live queries used ls-remote.

## All nine local branches

| Branch | Exact tip | Main-only / ref-only | Final disposition |
| --- | --- | ---: | --- |
| `backup/main-before-sync-20261125` | `4463ebb62ae4bbaa3a949b4ffc478b33eebb4d0b` | 58 / 22 | Do not merge wholesale. Nineteen non-merge commits are patch-equivalent. Two commits are merges. The remaining signing-only difference is excluded below. Retain this ref. |
| `ci/app-installers` | `d673a2397547089901636b6a6d0ef75a623b863b` | 54 / 0 | Fully contained in main. No merge required. Retain ref and linked worktree. |
| `ci/cloud-validation` | `b8e48afba505ac636877dfb1c5958702485b0832` | 1 / 0 | Active CI delivery is now contained in main. The earlier two-commit-pending description is historical. Retain the worker branch and worktree for root. |
| `ci/ui-core-installers-20261121` | `dcb4355a6e9e3526db8b69956959dc1680a44872` | 56 / 0 | Fully contained in main. No merge required. Retain ref and worktree. |
| `main` | `a9a10880962262aee86b24ee7975fb7d0578aef3` | 0 / 0 | Keep as integration branch. Root still must commit reviewed records and publish through the gate. |
| `wp/ci-packaging` | `5f8f962bc44ab3a78bc0e6937a099924e539a983` | 58 / 0 | Fully contained in main. Do not restore stale dirty files. Retain ref and worktree. |
| `wp/env-core` | `5f8f962bc44ab3a78bc0e6937a099924e539a983` | 58 / 0 | Fully contained in main. No missing branch commit. Retain ref and worktree. |
| `wp/env-ui` | `5f8f962bc44ab3a78bc0e6937a099924e539a983` | 58 / 0 | Fully contained in main. No missing branch commit. Retain ref and worktree. |
| `wp/icons` | `7eb0dd5760daa441e279ee91490a47f6d17058da` | 57 / 0 | Fully contained in main. No merge required. Retain ref and worktree. |

### Backup exception

`git cherry` again returned 19 equivalent non-merge commits and one unmatched commit: `ed4c9c02892ac13900f37c6ad8cf4271e5d44ab7`. The two merge commits account for the rest of the 22 ancestry-unique commits.

The unmatched commit changes seven paths. Six postimages still equal the fixed main exactly. The only different postimage is `ohos/build-profile.json5`:

| Postimage | Git blob |
| --- | --- |
| Backup commit | `8e38d34c3f59d78d251c8616ee98566e209808e4` |
| Fixed main | `9bbf10d11d7a0a316608967c253621f78d2eea84` |

Earlier content review found equality after removing local signing settings. This pass rechecked all seven blob identities, not signing values. Do not merge the backup profile or publish a signing patch. Keep current tracked `ohos/build-profile.json5` unchanged. The owner-confirmed DevEco fields are ciphertext, not plaintext credentials. Certificate files remain local.

`refs/original/refs/heads/main` also points to `4463ebb62ae4bbaa3a949b4ffc478b33eebb4d0b`. It is the same recovery history, not an additional branch delta. Retain it. `refs/stash` is absent. No ref deletion is authorized.

## Every live remote branch

The corresponding remote-tracking branch tips matched these live advertisements. Each non-main remote branch is already an ancestor of the fixed local main.

| Remote branch | Exact advertised tip | Main-only / ref-only | Final disposition |
| --- | --- | ---: | --- |
| `github/ci/app-installers` | `1969ef40d69134e45eaab6b558d71b96cf9be68a` | 59 / 0 | Contained. No remote work to merge. Retain. |
| `github/ci/cloud-validation` | `82f344657b5074698aa934db77408599d26024c5` | 2 / 0 | Contained. Local CI tip has a later contained commit. No missing product work. Retain. |
| `github/ci/ui-core-installers-20261121` | `dcb4355a6e9e3526db8b69956959dc1680a44872` | 56 / 0 | Contained. Retain. |
| `github/main` | `918233c5f32e848e63df11fa4e25639cdf17053a` | 8 / 0 | Fast-forward ancestry is available. Root must use the exact-commit push gate. No publication claimed here. |
| `cnb/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 76 / 0 | Contained legacy mirror. Do not push to it. Retain source metadata. |
| `gitcode/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 76 / 0 | Contained legacy mirror. Do not push to it. Retain source metadata. |
| `gitee/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 76 / 0 | Contained legacy mirror. Do not push to it. Retain source metadata. |
| `gitlab/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 76 / 0 | Contained legacy mirror. Do not push to it. Retain source metadata. |

The four symbolic remote HEAD refs are aliases, not separate branches:

| Symbolic ref | Target | Tip |
| --- | --- | --- |
| `refs/remotes/cnb/HEAD` | `refs/remotes/cnb/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` |
| `refs/remotes/gitcode/HEAD` | `refs/remotes/gitcode/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` |
| `refs/remotes/github/HEAD` | `refs/remotes/github/main` | `918233c5f32e848e63df11fa4e25639cdf17053a` |
| `refs/remotes/gitlab/HEAD` | `refs/remotes/gitlab/main` | `23ea13cda6fec378ff20209af81f2d909c99eab5` |

Fetch and push URLs were both inspected for every source remote. GitHub uses `https://github.com/azurekiln2333/qflistudio-cpp.git` in both directions. The four legacy source remotes remain untouched. No target-clone command ran. The target's GitHub-only remote and final source/target equality remain root's checks.

## Worktrees and recoverable snapshots

A new read-only worktree status snapshot found the same 46 dirty paths across the six old worktrees. Detailed historical per-path content dispositions remain in reconciliation.md: 34 equivalent postimages and 12 stale versions. No old worktree file was restored or deleted. This pass refreshed status, not a new full content comparison.

| Worktree under `D:/MyNewProjects/_wt/` | Branch | Dirty paths | Action |
| --- | --- | ---: | --- |
| `qfli-c-ui-sync/qfli_c` | `ci/ui-core-installers-20261121` | 0 | Retain. |
| `qfli_c-ci-app-installers` | `ci/app-installers` | 2 | Retain. Earlier path dispositions remain the evidence. |
| `qfli_c-wp-ci` | `wp/ci-packaging` | 7 | Retain. Do not overwrite newer main helpers. |
| `qfli_c-wp-env-core` | `wp/env-core` | 26 | Retain. Earlier path dispositions remain the evidence. |
| `qfli_c-wp-env-ui` | `wp/env-ui` | 11 | Retain. Earlier path dispositions remain the evidence. |
| `qfli_c-wp-icons` | `wp/icons` | 0 | Retain. |
| `qfli_c-cloud-validation` | `ci/cloud-validation` | 0 | Retain the current CI worker worktree. |

The main worktree contains reviewed recovery and companion-worker edits. It is not clean. Root owns their integration. Native/build was ignored and unindexed, so its move does not establish Git cleanliness.

The earlier read-only recovery review classified five unreachable commits, thirteen root-tree snapshots, reflog entries, and independent blobs. Their dispositions remain in reconciliation.md and its external indexes. This resumed pass did not rerun fsck or claim a fresh unreachable-object inventory. No old object, ref, or worktree was removed.

## Native recovery and exact preservation outcome

The 22 portable candidates were already curated before this resumed pass. They are preserved under `research/native-recovery/`, with a second curated copy beside the complete backup. They are source/research candidates, not newly integrated product behavior. None was executed locally. The startup helper's device target is redacted. The historical ci-tools PR draft now has an explicit HISTORICAL / CLOUD-ONLY override. Original content remains unchanged in the complete backup.

The guarded move succeeded at **2026-11-27 09:40:12 +08:00**:

- Source: `D:/MyNewProjects/qfli_c/native/build`.
- Backup: `D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127/source/native/build`.
- Method: one `Move-Item -LiteralPath`, no force or overwrite, on the same NTFS volume.
- Exact parent-index inspection: 1,069 entries, zero affected paths or gitlinks at native/build or an ancestor path.
- Source entry absent and destination entry present after the move.
- Root NTFS file ID unchanged: `0x0000000000000000000e0000002b4410`.
- Source and destination ancestor chains contained no reparse point. The destination had no case-insensitive name collision.
- Process inspection found no source-path reference or named build tool. This is not proof that every possible handle was absent.

Independent no-follow inventories before and after the move recorded:

| Metadata category | Before | After |
| --- | ---: | ---: |
| Ordinary files | 524,658 | 524,658 |
| Ordinary directories, excluding root | 60,177 | 60,177 |
| Reparse points | 142 | 142 |
| Total entries, excluding root | 584,977 | 584,977 |
| Logical ordinary-file bytes | 58,117,692,669 | 58,117,692,669 |
| Enumeration errors | 0 | 0 |

Both sorted per-entry metadata manifests have SHA-256 `baeea268f18293a029066a55ce24f3640edf8ea20658e7f3ca2aca7040890fef`. Each manifest is 148,913,863 bytes. Records contain relative path, entry kind, ordinary-file length, attributes, creation/last-write UTC ticks, and the exposed link target. Separate no-follow fsutil queries retain raw reparse payloads, including WSL payloads for which .NET LinkTarget is null.

**This is metadata preservation evidence, not content hashing of the complete tree.** The ordinary-file byte total is logical length, not allocated storage or reclaimed space. Only selected recovery originals and curated files received content SHA-256 checks.

There are 125 Windows symbolic-link tags (`0xa000000c`) and 17 WSL symbolic-link tags (`0xa000001d`). Links were never traversed. Their payloads were not repaired or rewritten. Absolute WSL payloads can still name the former source path. Do not follow or execute them.

The whole nested `llvm-project/.git` directory moved intact. Certificate files and the signing-only review profile remain only in the local complete backup. Preservation does not authorize publication or deletion of any of them.

The older 70,338 ordinary-file records and three individually reviewed links are classification coverage only. They excluded whole SDK/source subtrees. They must not be reported as the fresh full-tree counts above.

## Evidence and remaining root gates

External evidence root: `D:/MyNewProjects/_pi_reports/qfli_c/2026-11-27/`.

- `cpp-git-final-refs-resumed.json`: fixed-base local/ref comparisons and backup cherry results.
- `cpp-git-final-remotes-resumed.json`: five live heads/tags queries, both URL directions, and exact counts.
- `cpp-git-final-worktrees-resumed.json`: current worktree status snapshots.
- `cpp-git-final-backup-comparison.json`: seven backup postimage identities.
- `cpp-git-native-move-preflight.json`: exact path/volume/index/recovery provenance preflight.
- `cpp-git-native-move-attempt.json` and `cpp-git-native-move-outcome.json`: one-time move and immediate postconditions.
- `cpp-git-native-metadata-before.json` and `cpp-git-native-metadata-after.json`: no-follow summaries and raw link payloads.
- The two matching `.jsonl` metadata manifests: all 584,977 entries.
- `cpp-git-native-preservation-verified.json`: independent final metadata/provenance read-back and evidence hashes.
- `cpp-git-resume.md`: completed worker handoff.

Root must still integrate reviewed records, commit, use the push gate, inspect current cloud results, compare source/target HEAD and tree, verify both clean states, and obtain target acknowledgement. This report does not claim any of those gates have passed. P5's cleanup/handoff documents remain untouched by this worker. No local test, build, lint, product analysis, dependency installation, artifact download, WSL startup, target write, deletion, or Git write ran.

STATUS: WORKER COMPLETE. Root owns final integration and publication.
