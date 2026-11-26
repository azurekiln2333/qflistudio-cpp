# Execution plan

1. Reconfirm target cwd, GitHub remote, and dirty state.
2. Pull accepted main with fast-forward-only protection.
3. Compare commit/tree, tracked-file content/status, Trellis manifest, and core layout.
4. Check target output directories without building or installing.
5. Send and acknowledge the Herdr handoff.
6. Publish exact old-directory and WSL cleanup steps with owner and preservation gates.
7. Perform only approved, ownership-verified cleanup.
8. Recheck target cleanliness and record final storage/migration evidence.

No cleanup runs during planning. No WSL distribution is started for this audit.
