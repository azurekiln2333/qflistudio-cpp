# Implementation

- [x] Inspect local/remote state and choose published core main.
- [x] Create isolated app/core worktrees and task artifacts.
- [x] Update core pins, narrow the stock Flutter patch and extend helper regression coverage.
- [x] Resolve dependencies, analyze and test the Forge integration.
- [ ] Review outgoing diff and run CI helper tests.
- [ ] Commit and push the isolated branch.
- [ ] Dispatch all installer jobs, inspect failures and repair within scope.
- [ ] Verify seven artifacts, promote the reviewed branch and record cloud evidence.

Validation: flutter pub get; flutter analyze; flutter test; python -m unittest discover -s tool/ci -p test_*.py; git diff --check.
Rollback: revert this task's commits. Never reset the original dirty worktrees.
