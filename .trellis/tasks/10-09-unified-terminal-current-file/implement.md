# Implementation plan

## Planning and coordination

- [x] Create the approved Trellis task.
- [x] Start pi-c-terminal in right Herdr pane w6:p2.
- [x] Inspect shared-core and C/Java repository changes.
- [x] Identify inherited UI behavior and remaining C-specific gaps.
- [x] User approved the final plan; task activated as in_progress.
- [x] Captured 51 pre-implementation source files and their SHA-256 manifest.

## Execution

- [x] pi reads curated specs and this task before editing.
- [x] Add or reuse one source-selection helper and behavior-focused regressions.
- [x] Wire selection consistently into desktop, interpreter, Android/iOS/HarmonyOS and browser routes where currently implemented.
- [x] Replace C run titles with concise relative-path command text.
- [x] Verify bridge payloads and retain full project assets/writeback.
- [x] Run available targeted tests and relevant static/native checks.
- [x] Codex reviews task deltas; pi fixes actionable issues.
- [x] Codex updates source-selection/runtime specs and records the final independent review.
- [x] Phase 3.4 Git decision: user approved the concrete plan and temporary deferral; preserve working-tree changes until the runtime baseline is committed.
- [ ] finish-work/archive/journal after current-task code is committed; do not auto-commit other runtime work.

## Validation commands

- flutter test test/c_app_test.dart test/clang_runner_test.dart test/native_clang_runner_test.dart test/android_clang_runner_test.dart
- flutter test test/source_selection_test.dart (if introduced)
- flutter analyze
- From ../qfli_studio_core: flutter test test/terminal_pane_test.dart test/editor_run_test.dart
- node --check web/forge-worker.js
- Use the installed Android Gradle wrapper and local JBR to compile changed Kotlin if needed.
- Run existing browser/native checks only where the modified path requires them and the toolchain is available.

## Review gates

- Do main and main2 actually produce distinct outputs rather than just different titles?
- Are ordinary helper C/C++ files preserved, including comments or declarations mentioning main?
- Are all runtime routes consuming the selected list rather than silently rediscovering files?
- Are failures/cancellation and program output preserved?
- Is shared-core work left with its current owner?
- Are final staged changes limited to this task and separated from pre-existing runtime work?

## Validation limits

Apple builds and physical device execution require their actual toolchains/devices. Passing channel or desktop tests is not equivalent to device execution. State skipped checks explicitly.
## Final implementation gate

Passed: 141 application tests (0 skipped), 22 shared UI tests, final independent review, targeted analysis, Android Kotlin compile and 10 worker payload checks. Exact scope and platform limitations are in research/verification.md. Implementation is complete. The user approved temporary Git deferral; commit and finish-work remain deferred until the existing runtime baseline is committed.
