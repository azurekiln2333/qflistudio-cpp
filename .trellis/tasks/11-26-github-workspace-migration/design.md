# Design

## Source of truth

GitHub main becomes the canonical portable source and progress snapshot. Generated outputs live in Actions artifacts or caches. Evidence records live in Trellis and contain metadata only, never package archives or credentials.

## Reconciliation

Build a manifest of old remote heads, local refs, linked worktree changes, ignored candidates, and recoverable snapshots. Compare ancestry and patch equivalence. Preserve newer main content when dirty worktrees contain stale snapshots. Never use blanket git add, merge-all, reset, or clean.

The backup branch includes signing history. Recover only reviewed safe changes. Record the exclusion and safe-equivalence proof. History rewriting and credential rotation are separate owner actions if needed.

## Dependency and CI contract

The E-drive clone uses a differently named core sibling. Choose a portable core dependency layout together with the core coordinator. Keep local manifests, lockfiles, fixed CI checkout revisions, and preparation helpers consistent. No local pub get.

Native workflow outputs feed installer jobs through explicit provenance checks. Cloud validation covers source checks and package inventories. Artifact names and digests bind outputs to source/dependency revisions. Signing metadata states whether a package can actually be installed.

## Coordination and migration

The source coordinator is the sole Git writer during reconciliation. Four Herdr pi workers audit separate areas. Re-resolve Herdr pane identity before every handoff. Target Codex starts final checks only after the source gate and pull comparison. Cross-product changes belong to their owners.

## Preservation and cleanup inventory

Preserve source refs and evidence. Do not copy ignored build trees to E. Move enumerated private/generated content to D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127 after checking resolved source/destination boundaries and avoiding collisions. Record what moved. Do not delete files or worktrees and do not unregister WSL. The cleanup document is an inventory for a later owner decision. A failed remote or CI check prevents a completed migration claim.

## Push gate

The coordinator commits reviewed changes on main and writes the exact HEAD to D:/MyNewProjects/_orchestra/push/qflistudio-cpp.json with any path-specific allow reasons. The orchestrator owns review and push. Read the corresponding result JSON before synchronizing the destination. No worker or coordinator runs git push directly.
