# Independent source-selection review

Reviewer scope: read-only product review against research/baseline, with repros written only here.

## Confirmed selector regressions before pi's review fix

Command:

```
D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe --packages=.dart_tool/package_config.json .trellis/tasks/10-09-unified-terminal-current-file/research/check_selector_repro.dart
```

All five inputs returned `actualDefinesMain: true`, `expectedDefinesMain: false`, and `selected: ["entry.c"]`, thereby excluding the necessary helper.

- `static_helper_main`: internal-linkage C `static int main(void)` plus public answer wrapper.
- `conditional_body`: `int main(void)` is unconditional, but the definition is under `#if USE_MAIN`; the disabled branch leaves only a prototype.
- `crlf_macro_continuation`: main-shaped text is the unused expansion of a continued `#define`, with Windows CRLF endings.
- `spliced_line_comment`: main-shaped text is still part of a `//` comment after backslash-newline splicing.
- `comment_in_macro_name`: a comment between `#define` and `main` prevents recognition that the token is renamed by a macro.

The first two affect declaration/body classification; the remaining examples affect logical-line/comment/directive handling. The actual program needs answer() from helper.c; exclusion causes link failure. A real compiler and baseline/current runner comparison is prepared in check_runner_regressions_test.dart. Its first attempt sampled pi's intermediate source edit and failed to load due to an as-yet undefined _spliceLineContinuations; that transient result is not a product finding.

## Android authoritative-list regression

Original added start decoding used mapNotNull followed by takeIf(isNotEmpty), converting explicit empty/invalid lists into null and activating legacy discovery. Reported to coordinator. Pi has changed this to hasArgument plus strict parsing before run acceptance; review of the resulting code confirms only an absent key selects legacy discovery. Filesystem and selected-entry checks still run before compilation. Coordinator reports Kotlin compilation and targeted Dart tests passed after the fix.

## Browser review

Independent `node --check web/forge-worker.js`: pass.

The current source writes all uploaded files, validates an explicit sources list against the complete uploaded translation-unit set, passes only that list to qfli_web_compile, and passes the unchanged complete files array to executeWasm and runtime writeback. A VM harness is prepared in check_worker_payload.mjs. It mocks compiler and WASM execution only, so a passing harness establishes payload handling, not actual browser compiler/app/device execution.

## Verification limits

- Shared terminal tests and Android Kotlin build are owned by the coordinator; no duplicate build was started by this reviewer.
- Whole-repo analysis has pre-existing shared-core Web adapter/build-copy blockers, as recorded by the coordinator. The reviewer will run targeted lint/type analysis after pi becomes idle.
- iOS source review confirms the new file check no longer references the QFLI_PORTABLE_RUNTIME-only QFLIRegularFile symbol. No Xcode or device execution is available here.
- No product, shared-core or other-language files were changed by this reviewer.

## Stable-tree compiler and runner evidence

- `check_compile_helpers.dart` used the installed Dev-Cpp GCC with `-std=c11` (its C17 probe is unsupported, matching the runner's existing C11 fallback). For all five cases, compiling the entry plus helper succeeds with no diagnostics, the program prints 42 and exits 0; dropping the helper fails linking with an undefined answer symbol. Exact results: check_compiler_results.json.
- After pi's selector corrections, all five baseline/current ClangProgramRunner comparisons pass: baseline and current both return `(0, [42], [])`.
- Targeted Dart lint/type analysis of source_selection.dart, run_title.dart, clang_runner.dart, c_runner.dart, native_clang_runner.dart and both new unit-test files passes with no issues.
- The browser worker VM harness passed all 10 checks when run by the coordinator: exact selected compiler inputs, preservation of the complete upload/runtime/writeback files, legacy discovery only for absent sources, and eight invalid list cases rejected without compilation/execution. The reviewer could not start Node's VM command because the sandbox helper failed before launching it; this is not a runtime or script failure.

## Additional confirmed runner failures (sent to pi)

The stable-tree research/check_runner_regressions_test.dart run passed the five helper comparisons and failed these three assertions:

1. C interpreter complete-header retention: main.c includes entry.h, whose ordinary header content defines main. Saved baseline prints `header entry` and exits 0. Current c_runner.dart applies the selector to both .c and .h, deletes entry.h from the virtual files map, and fails with `找不到头文件 entry.h`, exit 1. Keep all headers and apply alternate-entry filtering only to translation units.
2. Desktop out-of-project entry: with project/main.c and a sibling outside.c, ClangProgramRunner compiles and executes outside.c, prints `OUTSIDE`, exit 0. The selected entry must be validated as a readable project-local file before source selection and return 127 with no program output when invalid.
3. Interpreter out-of-project entry: the same setup through CProgramRunner prints `OUTSIDE`, exit 0. Apply the same entry validation before native fallback/interpreter execution.

These are concrete remaining task-contract failures, not hypothetical hardening requests. Pi is handling product fixes; this reviewer has not edited product files.

## Raw-literal splice candidate closed

The coordinator's exact C++ raw-literal candidate was checked once. It is kept (`definesUnambiguousMain == false`), G++ C++11 compilation succeeds with no diagnostics, and the program prints 42 and exits 0. No product finding was raised from this candidate. Exact evidence: check_raw_literal_results.json.

## Final independent review gate: PASS

After pi became idle, the reviewer ran only the three previously failing assertions against the final source tree:

```
flutter test --no-pub --reporter expanded .trellis/tasks/10-09-unified-terminal-current-file/research/check_runner_regressions_test.dart --name 'interpreter retains the full header set|rejects an entry outside project'
```

Result: 3 passed, exit 0.

- Header program: baseline and current both `(0, [header entry], [])`.
- Desktop outside entry: `(127, [], [入口文件不在工程内。])`.
- Interpreter outside entry: `(127, [], [entry file is outside the project])`.

The reviewer also ran Dart analysis on `lib/c_runner.dart lib/clang_runner.dart test/c_app_test.dart test/clang_runner_test.dart`: no issues, exit 0. The earlier seven-file source-selector/title/runner analysis also passed after the selector corrections. Node worker syntax passed independently; the coordinator successfully ran the ten-case worker payload harness.

Code review confirms both runners validate resolved project/entry paths before selection or dispatch, and the C interpreter retains the complete header map while filtering only translation units. Android decoding rejects present invalid lists before accepting a run; only absent lists reach legacy discovery. No blocking findings remain in the task-owned implementation deltas.

Pi reports the final complete test/ suite at 141 passed, 0 skipped; this reviewer independently verified the five real helper baseline/current comparisons before the final header/path change, the three repaired regressions afterward, and the static checks above. Shared UI's 22 tests and Android Kotlin compilation are coordinator verification. Apple/device execution and the existing whole-repo shared Web adapter/build-copy analysis blockers remain outside this verified gate.

All product fixes were made by pi. The reviewer changed only research notes/repros, performed no staging/commits, and has stopped all compilation/test work. Task-owned temporary check-* and compiler-* directories may now be inspected and removed by the coordinator without touching baseline/spec-baseline or the retained scripts/results.
