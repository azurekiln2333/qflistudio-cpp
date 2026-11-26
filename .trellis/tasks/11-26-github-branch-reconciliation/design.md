# Design

Use live ls-remote results, local object ancestry, git cherry, and path-level comparisons. Separate missing objects from proven differences. Fetch only after implementation approval. A single coordinator performs Git writes.

The known backup branch contains signing-specific history. Review it separately. Mark already-contained branches as reconciled without manufacturing merge commits. Preserve dirty worktree evidence until its disposition is committed.
