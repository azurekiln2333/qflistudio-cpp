# Execution plan

## Planning gate

- [x] Confirm source/destination paths and Herdr identities.
- [x] Obtain task-creation and planning consent.
- [x] Create parent and four linked child tasks.
- [x] Complete four read-only audit reports and decision review.
- [x] Present the final plan and obtain subsequent implementation approval.

## Ordered implementation

1. Recheck remote heads and concurrent workspace writers. Start the child owning the next deliverable.
2. Reconcile branch/worktree source and progress. Resolve signing-only history before publishing.
3. Correct Trellis status, agent rules, ignored output handling, and portable core dependencies.
4. Commit reviewed source/progress using explicit paths. Request publication only through the orchestrator push gate and verify its result.
5. Complete cloud validation and six-platform delivery checks. Record exact run and artifact metadata.
6. Commit updated acceptance evidence. Pull destination main with fast-forward protection.
7. Compare commit/tree, tracked-file status, dependency layout, Trellis manifest, and GitHub-only remotes.
8. Send the handoff through Herdr and obtain target Codex acknowledgement.
9. Publish the bounded cleanup inventory. Move excluded private/generated data to the designated backup. Do not delete files or unregister WSL.
10. Archive completed tasks and record the session. Publish bookkeeping and repeat source/remote/target equality checks.

## Validation boundary

Local commands are limited to Git/file metadata inspection, text editing, Trellis bookkeeping, and Herdr coordination. Do not run product tests, lint, builds, dependency installs, compilers, emulators, or local runners. Run scripts/ste-lint-zh.py in GitHub when Chinese technical files change. Administrative JSON/task validation may use python -B without bytecode.

## Stop conditions

Stop a write on unexpected dirty files, remote movement, secrets, unmatched worktree source, unknown WSL ownership, or incomplete CI evidence. Preserve observations in research. Do not claim clean/equal/complete from an earlier snapshot.
