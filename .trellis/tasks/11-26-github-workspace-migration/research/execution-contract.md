# Unified migration execution contract

The user resumed execution on 2026-11-27. The source coordinator is Herdr w5R:p1. The destination coordinator is w6J:p1. The authoritative machine-local directive is D:/MyNewProjects/_orchestra/qfli-unified-migration.md.

## Publication

Use GitHub main as the canonical source. Do not push directly. Write an exact-commit request to D:/MyNewProjects/_orchestra/push/qflistudio-cpp.json, then inspect qflistudio-cpp.result.json. The gate requires main, a clean worktree, fast-forward ancestry, acceptable tracked files, and commit messages without attribution trailers. A passing result must identify the requested commit before the target pulls it.

## Preservation

Move excluded private/generated content to D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127 with a path manifest. Check absolute path boundaries, tracked-file absence, and destination collisions first. Do not delete files, remove worktrees, or unregister WSL. Review portable source/progress before moving mixed output trees. Retain signing material only in the local backup. The tracked OHOS profile keeps its existing DevEco configuration; this migration does not claim credential validity or sign a release.

## Execution boundary

Do not execute local builds, tests, analyzers, linters, dependency installs, emulators, or WSL. Do not download cloud artifacts. Local work is limited to text edits, Git operations, file/metadata inspection, preservation moves, Trellis bookkeeping, and Herdr coordination. Copy the parent E-drive cloud rules into the versioned repository AGENTS.md.

## Accepted CI baseline

Run 45892017304, attempt 2, completed successfully at 82f344657b5074698aa934db77408599d26024c5. GitHub returned 20 successful jobs. The run produced 28 artifacts, including seven application packages, seven Flutter output archives, native inputs, iOS slices, WASI resources, and logs. See the cloud-delivery task's cloud-evidence.md for names, digests, retention, and signing limits.

The CI branch tip b8e48afba505ac636877dfb1c5958702485b0832 adds only that evidence document to the tested commit. Main fast-forwarded to it. Build, validation, native, dependency, and workflow input files were unchanged between the tested commit and that tip.

A final main dispatch may explicitly reuse native_run_id=45892017304 only while the native sources, workflow, dependency pins, and build configuration remain equal to the accepted baseline. Record the new application commit and older native run separately. A matching source comparison does not turn them into the same commit. Rebuilding every native input is unnecessary when the reviewed inputs are identical.

## Completion evidence

Verify live GitHub main, source HEAD/tree, destination HEAD/tree, both clean statuses, GitHub-only target fetch/push URLs, portable Trellis coverage, and absent generated output in the destination. Capture target Codex acknowledgement through Herdr. Write the final done.json only after all required checks pass. Otherwise write blocked.json with concrete unfinished gates and completed steps. Never report completion from a worker DONE label alone.
