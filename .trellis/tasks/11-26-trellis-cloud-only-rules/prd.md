# Trellis completeness and cloud-only rules

## Goal

Make project progress complete and accurate in a fresh clone. Make the cloud-only execution rule durable for every agent.

## Requirements

- Reconcile tasks, archives, research, specifications, journals, and PROJECT_STATUS.md against current evidence.
- Keep machine identity/session/cache state separate from portable progress.
- Track reusable project instructions needed by agents. Do not rely on ignored local skill copies as the sole workflow definition.
- Define local prohibitions in AGENTS.md and workflow guidance: no builds, tests, lint, dependency installs, emulators, or local CI runners.
- Allow read-only inspection, source/document edits, Git synchronization, metadata validation, and Herdr coordination.
- Repair the target core dependency layout without creating build output or duplicating shared core ownership.

## Acceptance

Required project knowledge is tracked and current. A fresh clone names accurate open gates. Agent rules are discoverable at repository entry. The target depends only on documented portable inputs.

## Dependency

Use the Git audit to avoid losing worktree-only progress. Coordinate shared core via Herdr. Run product/text checks in GitHub.
