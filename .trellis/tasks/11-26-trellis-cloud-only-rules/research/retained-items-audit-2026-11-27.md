# Portable Trellis retention audit

Date: 2026-11-27.
Worker: Herdr `w5R:p3`.
Source coordinator: `w5R:p1`.
Scope: documentation and portable historical summaries only.

## Authority and evidence boundary

`AGENTS.md` and the parent migration task's
[`execution-contract.md`](../../11-26-github-workspace-migration/research/execution-contract.md)
control this work.
All builds, tests, analysis and lint belong on GitHub-hosted runners.
Historical local-command examples do not grant permission to run them.

This audit distinguishes three states:

- Tracked source and progress already present in the repository.
- Portable summaries prepared for the coordinator's publication batch.
- Private, generated or unresolved material retained outside the repository.

A backup is preservation, not GitHub publication or migration acceptance.
This document grants no deletion, WSL, signing or device permission.
No task status, journal, cleanup document or native-recovery file was changed by this documentation pass.

## Existing progress retained without rollback

The earlier [`trellis.md`](trellis.md) records six historical linked worktrees
and the later cloud-validation worktree.
Its inventory found no missing shareable path in the main worktree.
Those are historical observations, not final clean-tree or target-equality checks.
Older task paths already represented by archives must not become duplicate active tasks.

| Former active task | Retained archive under `.trellis/tasks/` |
| --- | --- |
| `10-09-unified-terminal-current-file` | `archive/2026-11/10-09-unified-terminal-current-file/` |
| `10-12-c-cpp-substantive-curriculum` | `archive/2026-11/10-12-c-cpp-substantive-curriculum/` |

Two installer-worktree report variants remain alongside the newer reports:

| Retained path, relative to `11-18-desktop-env-icons-packages/` | Historical knowledge |
| --- | --- |
| `reports/ci-readiness.worktree-ci-app-installers.md` | Earlier cloud readiness and package evidence |
| `reports/wp-env-core.worktree-ci-app-installers.md` | LLVM-MinGW identity, WinLibs layout and unaccepted installation boundaries |

The earlier audit recorded byte-identical preservation of those variants.
This pass confirmed the destinations exist, without overwriting the current reports.
Branch, snapshot and native-candidate dispositions remain the reconciliation owner's responsibility.

## Portable additions prepared in this pass

| File | Purpose |
| --- | --- |
| [`platform-adapters-2026-11-27.md`](platform-adapters-2026-11-27.md) | Inventory of 53 tracked Claude definitions and 17 distinct platform adapter/configuration files |
| [`legacy-build-progress-20261026.md`](../../10-22-offline-standalone-ide/research/legacy-build-progress-20261026.md) | Curated October host-control, compiler, runtime, editor and curriculum knowledge |
| [`PROJECT_STATUS.md`](../../../PROJECT_STATUS.md) | Accepted CI baseline, publication boundary and remaining gates |

The two summary paths previously named by `PROJECT_STATUS.md` now have real files.
The platform-adapter inventory is an additional portable destination.
These summaries preserve conclusions and caveats rather than importing entire ignored trees.

## Platform and runtime-state disposition

At inspected source revision `a9a10880962262aee86b24ee7975fb7d0578aef3`,
Git tracks 53 files under `.claude/`.
The separate adapter summary records all 53 paths and all 17 distinct adapter candidates.
Equivalent workflow prose does not make platform event names or discovery paths interchangeable.

The external preservation root contains `portable-agent-definitions/`.
It retains the Cursor, CodeBuddy, ZCode and DeepSeek Harness layouts.
Those layouts are not newly installed or published by this pass.
There is no broad ignore exception or forced addition of ignored platform directories.
Any later activation needs explicit approval and its own hosted checks.

Local settings, developer identity, session pointers, runtime state, caches,
bytecode and credentials remain excluded.
The summary contains no secret values, raw device records or certificate bytes.

## Legacy build knowledge

The preserved root is:

```text
D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127/source/build
```

The legacy summary identifies selected source documents by SHA-256.
It separates accepted historical host results from unrun source candidates.
It also records disputed claims instead of treating every earlier review as final acceptance.

Existing tracked host evidence remains authoritative for those historical runs:

- `10-22-offline-standalone-ide/research/host-controls-20261026/`.
- `10-22-offline-standalone-ide/research/host-baseline-20261026/`.
- `10-22-offline-standalone-ide/research/terminal-recovery-20261026/`.
- `10-22-offline-standalone-ide/research/acceptance.md`.
- `10-22-offline-standalone-ide/research/shared-release-checkpoint-20261026.md`.
- `tool/host_baseline/`, relative to the repository root.

The first five paths are relative to `.trellis/tasks/`.
No build cache, SDK, installer, native archive or executable was copied into these summaries.
The native owner's 22-candidate queue is not adjudicated here.

## Reference integrity and inherited text

The tracked file
`.trellis/spec/cli/backend/workflow-state-contract.md`
now contains a recovery notice, not an invented runtime contract.
The two workflow references therefore have a destination.
Read the notice's explicit limitation before relying on that path.
This pass did not edit `workflow.md` or expand its managed content.

The `AGENTS.md` Trellis block remains verbatim.
Its inherited English semicolon remains intact.
The copied parent English cloud rules also remain verbatim.
Chinese rule/status prose consistently uses the agreed check and run terminology.
No local lint result is claimed.
Root owns hosted lint scoping and the resulting evidence.

## Publication and acceptance still open

Accepted application run `45892017304`, attempt `2`, succeeded at
`82f344657b5074698aa934db77408599d26024c5`.
Its evidence-only follow-up is `b8e48afba505ac636877dfb1c5958702485b0832`.
See [`cloud-evidence.md`](../../11-26-six-platform-cloud-delivery/research/cloud-evidence.md)
for jobs, artifact digests, retention and signing limits.
Neither revision automatically validates later migration edits.

The coordinator still owns final-head hosted checks, publication through the push gate,
source/remote/target commit and tree equality, clean worktrees and target acknowledgement.
Production signing, notarization and installed-device acceptance remain separate gates.
Old-directory cleanup still requires owner approval after preservation and target acceptance.

This worker ran no local lint, tests, builds, dependency preparation or WSL startup.
No artifacts were downloaded.
All documentation changes remain unstaged for the coordinator.
