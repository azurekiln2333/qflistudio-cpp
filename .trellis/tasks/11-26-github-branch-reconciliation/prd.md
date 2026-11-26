# GitHub branch reconciliation

## Goal

Account for all C/C++ source and progress before consolidating reviewed work on GitHub main.

## Requirements

- Inspect all advertised heads from github, cnb, gitcode, gitee, and gitlab.
- Inspect all local branches, linked worktrees, and recoverable snapshots.
- Classify ancestry, patch equivalence, dirty source, stale snapshots, progress, generated output, and sensitive configuration.
- Preserve unique safe changes. Never replace newer main files with older worktree snapshots.
- Record signing-only exclusions. Do not publish sensitive backup history or rewrite shared history during ordinary consolidation.

## Acceptance

Every ref and dirty path has a recorded disposition. All safe unique source/progress exists on main. The final GitHub head matches reviewed local main. No merge hides an unresolved conflict or credential.

## Dependency

The parent owns approval and final integration. Trellis corrections and cloud verification follow this task. Cleanup waits for all children.
