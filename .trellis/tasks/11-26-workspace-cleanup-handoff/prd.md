# Workspace migration and cleanup handoff

## Goal

Finish the C/C++ workspace migration with source/progress equality, clear ownership, and safe storage reclamation.

## Requirements

- Preserve destination work before any pull. Keep only GitHub remotes there.
- Compare source and destination commit/tree, tracked file content, required Trellis files, and dependency layout.
- Keep the target free of build/test/cache/install outputs.
- Hand off through Herdr to the confirmed target Codex with evidence and pending work.
- Inventory exact old output/worktree paths and WSL ownership. Separate generated data from source, credentials, and other products.
- Move classified private/generated content to D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127. Inventory deletion candidates only. Do not delete files, remove worktrees, or unregister WSL in this migration.

## Acceptance

Both repositories are clean and match GitHub main after final bookkeeping. The target Codex acknowledges ownership. A path-specific cleanup procedure names preservation conditions. No shared/unowned data is deleted.

## Dependency

This task waits for Git reconciliation, Trellis/rules, and cloud delivery. WSL is machine-wide and requires coordination with other product owners.
