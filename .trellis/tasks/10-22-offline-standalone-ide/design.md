# Design

Use this long-lived umbrella ledger and separately verifiable execution batches. Start with repository/device inventory and baseline checks. Keep the established signed in-process LLVM + WASI interpreter OHOS architecture.

Root owns Trellis, generated content integration and commits. Give workers exclusive paths. Shared-core research stays read-only until one writer owns agreed reusable API/UI changes. Product runtime analysis/debug/module capabilities remain in adapters with explicit capabilities, not fake controls. Serialize generated assets and shared-core changes.

Content stays app-owned through ForgeContentRepository. Preserve source/generated pair consistency, unique IDs, exact outputs, supported standards and target-specific expected values. Before expansion, extend validators to bind expected IDs to authored inventory while enforcing a minimum; silently truncated inventory must fail.

Tools use responsive direct page sections, retain precise BigInt semantics and explain target assumptions. Preserve state through rebuilds. Workspace state is keyed by project/root with migrations preserving existing paths and IDs. Revert only owned changes if needed; never overwrite shared files from a stale snapshot.

## Offline debugger integration (October 22)

The common editor will consume an optional typed StudioProfile debugger provider.
Providers execute only after an explicit Debug action. They own language runtimes,
transport, source snapshot preparation and true worker cleanup. Missing providers
remain unavailable; ordinary Run is not a debugger fallback.

Use immutable versioned full DebugSnapshot updates: phase, pause token, threads,
frames/read-only variables, bounded stdout/stderr/console buffers and truncation
flags. A local monotonically increasing revision must change for output changes
as well as native state changes. This accommodates Go's rolling64KiB buffers,
Lua's pause/finish snapshots and Python's currently final-result output without
inventing a live stream or duplicating accumulated text.

Breakpoints are canonical absolute project-local source paths with1-based lines.
Results distinguish pending, verified and rejected; acceptance does not prove an
executable line. Capabilities distinguish launch-only/paused/live updates, pause,
step-into/over/out and unsaved snapshot support. Pause tokens bind session and
pause generation so stale frame/step requests are rejected. No current provider
supports expression evaluation; the first shared Debug Console is read-only.

Session done/stop/dispose complete only after actual worker cleanup. Go adapters
must stop and poll termination before closing the native registration. Python
must retain its runtime lease until execute_into returns. The editor's Output
uses real run/analyzer/tool output; Ports lists only app-owned local listeners.
UI and actual provider integration/device acceptance remain separate gates.
