# Root/platform preservation summary

Date: 2026-11-27. Worker: w5R:p5. Coordinator: w5R:p1.
Active task: `.trellis/tasks/11-26-github-workspace-migration`.

## Verified result

- Preserved 29 paths, 9,786 files, 5,811,262,437 bytes.
- Backup source root: `D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127/source`.
- Original relative paths were retained under that root.
- Complete root `build/`: 9,162 files, 4,855,516,423 bytes, now at `source/build` in the backup.
- P3 received the root build location through Herdr for portable historical-text curation.
- All 29 sources were absent and all destinations present at final read-back.
- Audit has 29 verified events and zero failure events.
- Verification compared relative entries, types, lengths and file UTC timestamps after same-volume moves. No moved-tree byte hashes are claimed.
- No tracked files moved. No links were followed. No data was deleted. No reclaimed-space claim is made.

## Evidence

External reports: `D:/MyNewProjects/_pi_reports/qfli_c/2026-11-27`.

- `cpp-handoff-preservation-result.json`: verified moves and totals.
- `cpp-handoff-preservation-plan.json`: classifications and preflight.
- `cpp-handoff-preservation-files.jsonl`: exact per-entry metadata.
- `cpp-handoff-resume.md`: worker completion and scope.
- Backup audit: `D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127/cpp-handoff-preservation.jsonl`.
- Active instructions: `cleanup-procedure.md` and `handoff-draft.md` in this directory.
- Prior drafts were copied to external `historical-cleanup-procedure-2026-11-27-pre-unified.md` and `historical-handoff-draft-2026-11-27-pre-unified.md`. They are obsolete history only.

## Retained, not lost or deleted

Link-containing generated roots remain at source: `linux/flutter/ephemeral`, `windows/flutter/ephemeral`, `ohos/build`, `ohos/entry/build`, `ohos/entry/oh_modules`, `ohos/node_modules`, `ohos/oh_modules`.
Their link targets were not followed or copied.
Agent definitions/runtime, Trellis progress/runtime, wrappers, lockfiles, manifests, editor configuration, diagnostic progress, source assets, Git metadata, worktrees and sibling repositories were not moved.
The four generated core-patch intermediates were preserved. Both source `.patch` files remain tracked.
`native/build` was untouched by this worker and remains p2's responsibility.

## Handoff boundary

The active drafts now name coordinator w5R:p1, fixed core path `../qflistudio-core`, and coordinator-accepted CI `45892017304`, attempt `2`.
They contain no executable destructive cleanup or WSL commands, stale final-SHA placeholders, or compare.sh execution instructions.
Root owns final integration, exact comparison, target pull, publication, journal/task JSON and target acknowledgement.
P3 owns `.gitignore` rules and portable historical curation. This worker did not edit `.gitignore`.
No local build, test, lint, analysis tool, install, artifact download, WSL operation, target edit, gate write, commit or push ran.

**Worker complete. Inventory and preservation only. No deletion or WSL unregister authorized.**
