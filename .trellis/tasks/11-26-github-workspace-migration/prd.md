# GitHub workspace migration and cloud-only delivery

## Goal

Make the C/C++ product reproducible from GitHub with complete project progress. Move development to the E-drive clone. Run all builds and tests in GitHub Actions.

## Scope and ownership

- Source: D:/MyNewProjects/qfli_c and its six registered linked worktrees.
- Destination: E:/MyNewProjects/QFLIProjects/qflistudio-cpp.
- Canonical repository: azurekiln2333/qflistudio-cpp on GitHub.
- The product-line request is distributed across workspace coordinators. This task owns C/C++ only. Coordinate shared core and WSL ownership through Herdr.
- The actual parent directory is QFLIProjects. The singular QFLIProject does not exist.

## Requirements

R1. Account for every local branch, every advertised branch of all five old remotes, dirty worktree files, and recoverable source/progress snapshots before cleanup. Consolidate reviewed, safe work into main without losing newer fixes.
R2. Preserve Trellis tasks, archives, specifications, research, and journals in GitHub. Correct stale progress claims. Keep credentials and machine session metadata out of Git.
R3. Exclude generated native, Flutter, platform, packaging, cache, log, and test output from source commits. Preserve required source assets and dependency lockfiles.
R4. Use GitHub-hosted execution for builds, tests, lint, dependency preparation, and package checks. Cover Windows, Linux, macOS, iOS, Android, and OHOS. Track native inputs and Flutter outputs separately from source.
R5. Record the source commit, dependency revisions, native artifact origin, package inventory, digests, retention, and signing state. A workflow file alone is not acceptance evidence.
R6. Keep only GitHub remotes in the destination. Pull the reviewed main, compare Git trees and tracked bytes, verify portable dependency paths, and leave both repositories clean after all progress commits.
R7. Publish durable agent rules against local builds/tests and automatic dependency downloads. Coordinate exclusively through Herdr. Prefer gpt-6.1-sol; retry limits, compact or replace sessions, then use deepseek-v4.1-flash only if needed.
R8. Hand off to the destination Codex after reconciliation. Include evidence, remaining gates, and an exact cleanup inventory. Preserve private and generated content under D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127. Do not delete files, remove worktrees, or unregister WSL in this migration.

## Acceptance criteria

- Every branch/worktree has an evidence-backed disposition. No unique safe source or project progress remains only on D drive.
- GitHub main, source main, and destination main have the same commit and tree. All required Trellis content is committed. Final git status is clean in both primary repositories.
- The destination has only GitHub remote URLs. Dependency resolution does not require an old D-drive directory or untracked patch.
- Cloud checks and six-platform package results refer to the accepted source/dependency/native versions. Missing signatures and device acceptance remain explicit.
- No agent runs a local build/test/install. No new generated outputs appear in the destination.
- The destination Codex acknowledges the handoff through Herdr. Cleanup steps identify exact paths, preservation checks, owner, and ordering.

## Boundaries and review gates

Do not publish secrets, merge signing-only backup changes wholesale, force-push history, delete unresolved worktrees, or unregister shared WSL during planning. A backup-branch exception requires review because its unmatched patch touches signing configuration. Production signing credentials and device acceptance cannot be inferred from successful packaging.

## Current status

Planning was approved on 2026-11-26. The user approved implementation and renewed execution on 2026-11-27 through the unified migration directive. Push only through D:/MyNewProjects/_orchestra/push/qflistudio-cpp.json. Do not run git push directly. See research/baseline.md for historical observations. The four child tasks cover Git reconciliation, Trellis/rules, cloud delivery, and migration/cleanup. The parent coordinator owns final integration and the completion record.
