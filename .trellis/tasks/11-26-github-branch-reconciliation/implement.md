# Execution plan

1. Refresh read-only ref/worktree inventory.
2. Fetch authorized remotes without pruning required recovery refs.
3. Compare all branch commits and worktree postimages against main.
4. Recover safe unique files with explicit staging.
5. Resolve sensitive backup disposition with the owner.
6. Commit reconciliation evidence and reviewed source.
7. Push GitHub main, then verify live remote SHA.

Do not run builds/tests. Do not delete branches/worktrees until their content and recovery evidence are accounted for.
