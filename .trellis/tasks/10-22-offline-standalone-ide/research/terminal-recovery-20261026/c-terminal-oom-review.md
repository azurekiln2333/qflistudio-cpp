# C terminal window compiler OOM review (read-only)

Status: SOURCE-ONLY review. No SDK, compiler, test, control or native command was
launched. I read window artifacts, the runner, the sibling worktree and git state,
and used `Get-FileHash`/`Get-CimInstance`/`git` only. No source was edited and only
this file was written.

Target: `build/core-terminal-window-20261025T233353Z` (grant
`C-terminal-errors-20261026-02`), with `build/core-terminal-window-20261025T223956Z`
(grant `-01`) as the control that must not be conflated with it.

## 1. Headline

The two windows did **not** fail the same way, and only one is an OOM.

| window | format | tests | test output |
| --- | --- | --- | --- |
| `-01` 22:39:56Z | `Formatted 2 files (2 changed)` | compiled, ran, killed at 170 s | reached `+36`, stderr 0 bytes |
| `-02` 23:33:53Z | `Formatted 2 files (0 changed)` | compile died at 00:00 | no test ever ran, stderr 149 bytes |

- `-01` is a **timeout after a hang**: 36 tests passed in 7 s and the suite stalled
  on `stdout failure keeps ownership until exit and cleanup`, then the runner's
  170 s deadline killed it. `tests.stderr` is empty, so there is no OOM record.
- `-02` is the **compiler OOM**: the resident frontend compiler exhausted its heap
  before the first test started.

Both were recorded as `"timedOut": true` with `exitCode 124`, because
`exitCode 124` is `TerminateJobObject(124)` from `OwnedJob.stop()`. The report field
`timedOut` therefore does not distinguish "slow" from "hung" from "dead compiler".

## 2. The `-02` OOM, exactly as evidenced

`tests.stdout` (47 bytes of progress plus trace):

```
00:00 +0: loading .../test/terminal_pane_test.dart
00:00 +0 -1: loading .../test/terminal_pane_test.dart [E]
  Error: The Dart compiler exited unexpectedly.
  package:flutter_tools/src/compile.dart 929:15  DefaultResidentCompiler._compile.<fn>
  Null check operator used on a null value
  package:flutter_tools/src/test/test_compiler.dart 257:34  TestCompiler._onCompilationRequest
```

`tests.stderr` (149 bytes, complete):

```
Exhausted heap space, trying to allocate 39595168 bytes.
Exhausted heap space, trying to allocate 39500256 bytes.
Unhandled exception:
Out of Memory
```

Reading of this evidence:

- The failure is at **kernel compile time**, not in any assertion. Zero tests ran, so
  the window evaluated no assertion at all.
- `Exhausted heap space` twice, ~95 KB apart in requested size, then
  `Unhandled exception: Out of Memory`: the VM could not serve a normal-size
  allocation on two consecutive attempts. That is heap growth failure, not one
  oversized object.
- `Null check operator used on a null value` at `test_compiler.dart:257` is
  **secondary**. It is flutter_tools reacting to the compiler socket closing; it is
  the symptom, not the cause. The cause is the compiler process dying.
- `format` in the same window changed nothing, so the OOM is not attributable to a
  half-applied reformat inside that window.

## 3. Why `-01` is not an OOM, and why that matters

`-01` bound **different bytes** and got further:

- `-01` test hash `25880ae6…`; `-02` test hash `5d5b8aac…`.
- `-01` ran to `00:07 +36: stdout failure keeps ownership until exit and cleanup`,
  then produced nothing for the remaining ~163 s of the 170 s budget.

Consequences:

1. A test file of this shape **did compile** in `-01`. The compiler is not
   categorically unable to build this suite, so `-02` is either a content-dependent
   blow-up of the newer revision or a run-time memory-pressure event, not a fixed
   toolchain limit.
2. `-01` exposes a **second, independent defect**: the new control
   `stdout failure keeps ownership until exit and cleanup` started and never
   finished. That is exactly the "errored stream left open, no attachment hang"
   behaviour `build/core-terminal-error-candidate/design.md` claims to fix. The
   window therefore produced evidence *against* the candidate, pending confirmation
   that the stall is in the test and not in the harness.
3. Any review that reads only `-02` will wrongly treat this as an infrastructure
   OOM and miss the hang.

## 4. Provenance gaps (blocking for "evidence")

These are the reasons the current artifacts cannot yet carry a pass or a
corpus-level "environment is at fault" claim.

1. **The producing runner is not in the repository.** Both reports contain exactly
   two steps (`format`, `tests`). The only runner on disk,
   `build/run_core_terminal_window.py`, defines four
   (`format`, `analyze`, `focused`, `tests`) and its mtime (2026-10-26 06:38:19
   local / 22:38:19Z) precedes both windows (06:39:56 and 07:33:53 local). A
   four-step runner would have appended an `analyze` step before `tests`. Neither
   report has one. So the 2-step program that wrote these reports is unidentified,
   and nothing in `report.json` records a runner path or hash. Until the runner is
   named and hash-bound, these windows are not reproducible evidence.
2. **The window mutates the shared core.** `-01`'s `format` step reported
   `Formatted 2 files (2 changed)`, i.e. `dart format` rewrote
   `lib/editor/terminal_pane.dart` and `test/terminal_pane_test.dart` inside a
   window whose purpose is validation. That both violates "validation observes"
   and explains part of the hash drift below.
3. **The recorded candidate base is stale for the test file.**
   `candidate-sha256.json` records test base `e8a63f86…`, but CORE `HEAD` is
   `2f9039a` and its test is `8f6af737…`. The source base `023242fd…` *does* match
   `HEAD`. So the candidate snapshot was cut against an older test file.
4. **Three versions of the same two paths, none linked.**
   - candidate snapshot: source `1f069305…`, test `429ddeca…`
   - `-01` validated: source `7bf7d365…`, test `25880ae6…`
   - `-02` validated: source `7bf7d365…`, test `5d5b8aac…`
   - worktree at audit time: source `7bf7d365…`, test `80108642…`
   No artifact asserts that the bytes validated are the candidate under review.
5. **The worktree moved after the window.** The test file was rewritten again at
   2026-10-26 07:50:07 local (now `80108642…`, 60,487 B, CRLF) with an unchanged
   `+435` diff shape. The `-02` bound hash no longer matches the worktree.
6. **No toolchain or memory record.** `report.json` binds the two inputs and the
   Job records, and nothing else: no Dart/Flutter version, no peak memory, no
   compiler exit status distinct from the kill status.

## 5. OOM cause: what the logs support and what they do not

Supported by the record:

- The frontend compiler process died of heap exhaustion while compiling
  `test/terminal_pane_test.dart` in a single-file, `--concurrency=1` run.
- Compile unit scale at audit time: test file 1,613 lines / 44 `testWidgets`;
  library `terminal_pane.dart` 2,138 lines whose imports pull
  `flutter/material`, `flutter/services`, `auth_store`, `process_supervisor`,
  `studio_profile`, `api_client`, `cloud_sql`, `online_program`, `app_paths`,
  `local_audit_service`, `local_stats_service`, `shell_backend`, `local_shell`,
  `terminal_input`, `studio_localizations`. One TU, one large transitive graph.

Not supported, and not to be claimed:

- **Not** proof of a host memory shortage. `OwnedJob`
  (`build/baseline_200_owned_job.py`) sets only `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`;
  it sets no process or job memory limit, so the Job is not a cap *if* the
  producing runner used it (unverified, see 4.1).
- **Not** proof of sufficiency either. Host state now is 32,506 MB RAM with
  14,348 MB free, 58,289 MB commit with 11,357 MB free, pagefile peak 5,480 of
  25,783 MB. Nothing samples memory *at run time*, so whether the compiler hit the
  Windows commit limit during `-02` is unknown.
- **Not** attributable to `--concurrency=1`, which is already the serial setting, nor
  to `--no-pub`, which only skips dependency resolution.
- The two windows ran 54 minutes apart on the same suite. Content changed between
  them, and `-01` compiled. Content-dependence is therefore at least as likely as
  pure memory pressure, and the two cannot be separated from these logs alone.

## 6. Narrow next validation route, preserving every assertion

Constraints honoured: nothing is deleted, no assertion is weakened, no test is
skipped in the final gate, and no source is edited by this review.

### 6.0 Runner fixes that must land first (record, not tests)

- Bind the runner: write its path and sha256 into `report.json`. Keep exactly one
  runner, and delete or clearly retire the other. Today there are two behaviours
  and one file.
- Split the deadline. One 170 s global budget cannot cover
  `format` + `analyze` + `focused` + `tests`; give each step its own timeout and
  keep a global ceiling above the sum.
- Never let `dart format` rewrite shared-core sources inside a validation window.
  Run `format --output=none --set-exit-if-changed`, or format in a scratch copy.
- Record both `timedOut` and `fatalCompilerError`, and sample the process-tree
  peak working set every poll. Right now a dead compiler, a hang and a slow build
  all collapse into `"timedOut": true`.
- Persist identity: Dart `3.11.5` (read from
  `D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/version`) and the Flutter
  version string, as recorded text.

### 6.1 The steps, cheapest first, each a gate

**S1 — static gate, no kernel compiler.**
`flutter analyze --no-pub lib/editor/terminal_pane.dart test/terminal_pane_test.dart`
from `D:/MyNewProjects/qfli_studio_core`. Validates types, imports and that all 11
controls reference real API. It cannot and must not be reported as a test pass.

**S2 — single bound compile, highest-value assertion.**
`flutter test --no-pub --concurrency=1 --plain-name "stdout failure keeps ownership until exit and cleanup" test/terminal_pane_test.dart`
This matches exactly one test: the name is a `for (final failingStream in
['stdout','stderr'])` interpolation at test line 1181, so the literal plain name
"stdout failure keeps ownership until exit and cleanup" resolves to one test.
It re-proves the candidate's central claim and, critically, tells you whether the
`-01` stall reproduces. Compile cost equals the whole file, so this does not reduce
memory; it reduces ambiguity and run time.

**S3 — the only step that actually lowers peak compiler memory.**
Move the 11 new controls out of `test/terminal_pane_test.dart` into a sibling test
file (for example `test/terminal_pane_error_test.dart`) that imports the same
library and the same fakes. Every assertion is preserved; only the per-compile unit
shrinks. Then compile and run one file per step. This is the correct response if S2
OOMs again.

**S4 — full regression, one file per step.**
Run the split file and the original file as two separate steps with independent
timeouts, then `test/editor_run_test.dart`.

Do **not** run the historically documented pair
`flutter test test/terminal_pane_test.dart test/editor_run_test.dart`
(see `.trellis/tasks/10-09-unified-terminal-current-file/research/verification.md:37`)
as a single step: that compiles both units in one compiler process and doubles peak
memory, which is the wrong direction after an OOM.

### 6.2 Decision rule

- If S2 OOMs while free physical memory is above roughly 8 GB and no Job memory cap
  is set, the OOM is a compiler blow-up on this content, and S3 is mandatory.
- If S2 hangs at the same test as `-01`, the OOM is a red herring for this run and
  the real defect is the candidate's attachment/exit handling; fix that before
  spending another window on compile memory.
- If S2 passes and S4 passes, the candidate is validated for these assertions,
  host-only.

## 7. Limits of this review

- No process was started; every number above is read from files or from the current
  host counters, not from the run.
- The OOM is not attributed to a specific cause. The two candidate causes (content
  blow-up, run-time memory pressure) are both consistent with the logs and are not
  separable without the telemetry in 6.0.
- Nothing here is a pass, and nothing here is device or OHOS evidence. The 200-host
  baselines published at `b420b13` are unrelated to this shared-core window.
- The candidate in `build/core-terminal-error-candidate/` remains unrun for
  validation purposes; `-01` and `-02` neither confirm nor refute it.

## 8. Files read

- `build/core-terminal-window-20261025T233353Z/{report.json,format.stdout,format.stderr,tests.stdout,tests.stderr}`
- `build/core-terminal-window-20261025T223956Z/{report.json,format.stdout,tests.stdout,tests.stderr}`
- `build/run_core_terminal_window.py`
- `build/core-terminal-error-candidate/{design.md,candidate-sha256.json}`
- `D:/MyNewProjects/qfli_studio_core/{lib/editor/terminal_pane.dart,test/terminal_pane_test.dart,test/editor_run_test.dart}`
- `git -C D:/MyNewProjects/qfli_studio_core` log/status/diff
- `build/baseline_200_owned_job.py` (limit semantics only)
- `Get-CimInstance Win32_OperatingSystem` / `Win32_PageFileUsage`
- `.trellis/tasks/10-09-unified-terminal-current-file/research/verification.md`

### Audit-time hashes (worktree moved during this review)

| path | bytes | mtime local | sha256 |
| --- | --- | --- | --- |
| `lib/editor/terminal_pane.dart` | 82,279 | 2026-10-26 06:39:56 | `7bf7d36524eb4db8b4d57d10aace5227446769f95622879af80ac7216d6beffd` |
| `test/terminal_pane_test.dart` | 60,487 | 2026-10-26 07:50:07 | `80108642508b99db3bbd8cd5f14cf81c93b5696792fe8ce28ebdbbb12bb7590c` |
