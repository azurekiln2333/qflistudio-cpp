# Implementation

- [x] Inspect local/remote state and select published core main.
- [x] Create isolated app/core worktrees and task artifacts.
- [x] Update core pins, narrow the stock Flutter patch and extend regression coverage.
- [x] Resolve dependencies, analyze and test the Forge integration.
- [x] Review the outgoing diff and pass CI helper tests.
- [x] Commit and push the isolated branch.
- [x] Run all installer jobs and resolve any build failures.
- [x] Verify all seven artifact metadata records.
- [x] Promote the reviewed branch and save cloud evidence.
- [x] Import reviewed Trellis progress, excluding session traces.

Validation commands:

- flutter pub get
- flutter analyze
- flutter test --concurrency=2
- python -m unittest discover -s tool/ci -p test_*.py
- python .trellis/scripts/task.py validate 11-21-sync-core-ui-installers
- git diff --check
- python scripts/ste-lint-zh.py .trellis/PROJECT_STATUS.md
- python scripts/ste-lint-zh.py tool/ci/README.md

Rollback: revert this task's commits. Never reset the original dirty worktrees.
