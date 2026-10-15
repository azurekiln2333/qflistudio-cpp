# Implementation plan: C/C++ substantive curriculum

Implementation approved by the user on 2026-10-12: `确认实施`, following the
final 200-pair planning summary. Current delivery bundles app-owned content;
no further shared-core write is part of this task.

## Decisions already resolved (no open technical question)

- Count: **100 C + 100 C++ = 200 pairs**, preserving the core release validator
  minimum of 100 entries per type for both tutorials and examples
  (`content_validator.dart:22`).
- Integration: authored topics, generator, verifier and bundled JSON live in
  `qfli_c`; `ForgeContentRepository` loads the app's assets. Historical scoped
  shared-core merges remain documented but are unnecessary for current delivery.
- Verification: **native compiler execution is a required content gate**;
  `compiler_unavailable` is a hard environment failure, never an interpreter
  fallback. The full WASI host matrix, signed-phone audit and ordinary product UI
  are separate required gates for the OHOS delivery.
- Standards: chosen **per sample** to match the runner actually used. A modern
  toolchain is confirmed in the `qfli-java-build` WSL distro (modern
  `clang++`/`gcc`); the Windows TDM-GCC 4.9.2 (C11 / C++14) is a working
  fallback. Record the exact `-std` per example.

## Status

2026-10-16 update (supersedes the historical status and shared-core merge steps
below): the app bundles its own staging JSON through `ForgeContentRepository`.
No sibling workspace is written. Re-derived generator output matches all 400
bundled rows after ignoring timestamps, with 100 distinct explanations, summaries,
programs, titles and first exercises in each language. The native report contains
exactly 200 unique passing examples and no shape/source mismatches. The final
WASI runtime's complete matrix passed 200/200 with binary/asset/payload hashes; see
`research/curriculum-portability-review-2026-10-16.md` for the current result.

The signed-phone audit passed 212/212 unique cases, including all 200 courses.
Earlier failures in two cancellation
audit snippets were fixture diagnostics (missing C17 feature-test declaration
and a deprecated C++ volatile increment), not accepted runtime passes. Do not
infer the full phone result from the host report. The coordinator also accepted
the production `lib/main.dart` HAP after strict verification and `install -r`,
preserving `sss`/`tt` data: ordinary C++ Run, Stop 130 and fresh Run passed;
Tutorial/lesson and the 200-entry Examples/detail views displayed real content.
See the runtime task's `research/ohos-production-ui-2026-10-16.json` and this
task's final curriculum review. This independent curriculum task is complete;
the cross-platform runtime task is not closed by this result.

Current completion checklist:

1. [x] Preserve all 100 C + 100 C++ substantive tutorial/example pairs.
2. [x] Verify authored generator output equals bundled JSON; no filler or gaps.
3. [x] Verify production repository loads the app-owned bundled assets.
4. [x] Review canonical 200/200 native compile/run evidence and standards.
5. [x] Finish the 200/200 matrix on the final portable runtime and retain digests.
6. [x] Complete the coordinator's signed-phone compiler/runtime/curriculum audit.
7. [x] Complete ordinary editor, Tutorial and Examples UI acceptance.

### Historical status, 2026-10-15

Re-audited on 2026-10-15 under the user's renewed request. Both authored and
live app assets contain 100 substantive C and 100 substantive C++ pairs, with
zero duplicate explanations, summaries or first exercises and zero placeholder
signatures. All 200 examples passed native compile/run again; all 10 negative
probes and 33 focused integration/pipeline tests passed. No tutorial data
replacement was needed. No sibling workspace was written. See
`research/c-review-2026-10-15.md`, `research/cpp-live-review-2026-10-15.md`
and the refreshed `research/cpp-content-verification.json` for per-item evidence.
The restarted Pi's final review is
`research/final-curriculum-review-2026-10-15.md`: all 400 live C/C++ rows still
match staging, and all 200 native result IDs remain unique and successful.
The OHOS audit source includes every topic; phone execution is still blocked
by lock-screen error 10106102. Keep the device/UI gate open.

The current instruction authorizes standardized Git commits. Any manual
device/UI check is reported separately from these data/native-run gates.

Implementation is complete and validated by repository/live data and desktop
runner automation:

- Canonical verifier `tool/verify_forge_content.dart`: **200/200** native
  compile+run (WSL clang++ 18 / g++ 13); `negative_probe.dart`: **10/10** failure
  and isolation probes.
- Initial delivery `flutter test`: **174/174** (current full suite: **176/176**),
  including `test/forge_content_integration_test.dart`
  which loads the aggregate through `ContentCatalog` + the `forge` filter, asserts
  the live core equals the authored source, and runs representative C and C++
  examples through the real desktop `ClangProgramRunner`.
- Coordinator external-write gate executed: live core now holds 100 C + 100 C++
  tutorials and examples (200 each), byte-identical to the staged source.

**Not performed**: a manual desktop-UI click-through of the Tutorial/Examples
tabs (opening a lesson, running an example from the UI). The run path is covered
by the desktop-runner automation above, but the human UI pass is not claimed.

## Execution order

1. [x] Create `tool/forge_content/` model + topic sources (data only).
2. [x] Author 100 C topics across three files (beginner/intermediate/advanced).
3. [x] Author 100 C++ topics across three files.
4. [x] Write `tool/generate_forge_content.dart` (Java/Python generator pattern):
       read-live, fingerprint-foreign, emit C/C++ rows, stage locally.
5. [x] Stage `tool/forge_content/staging/forge_tutorials.json` and
       `forge_examples.json` (staging under `tool/`, not bundled in the app).
6. [x] Write native-compiler verification: canonical
       `tool/forge_content/verify_forge_content.dart` (200/200) plus
       `negative_probe.dart` (10/10 failure/isolation probes).
7. [x] Add focused integration tests (`test/forge_content_integration_test.dart`,
       12 tests) and the peer pipeline test (`test/forge_content_pipeline_test.dart`,
       20 tests).
8. [x] Coordinator external-write gate executed: live core now has 100 C + 100 C++
       tutorials and examples, byte-identical to the staged source (0 rows
       differ); foreign rows preserved; own-row backup/report local.
9. [~] Desktop UI click-through: NOT performed. The run path is covered by the
       integration test's real desktop `ClangProgramRunner` run and the live-asset
       equality test; a manual Tutorial/Examples UI pass remains a coordinator step
       and is explicitly not claimed.

## Curriculum and file layout

C track (100): `c_topics_beginner.dart` (34), `c_topics_intermediate.dart` (30),
`c_topics_adv_a.dart` (10), `c_topics_adv_b.dart` (13), `c_topics_adv_c.dart` (13).

C++ track (100): `cpp_topics_beginner1..4.dart` (34),
`cpp_topics_intermediate1..6.dart` (41), `cpp_topics_advanced1..4.dart` (25).

Aggregated by `forge_topics.dart`; each topic = one tutorial row + one example row
+ >= 1 exercise. Levels per language are each >= 25.

## Validation commands

```powershell
cd D:\MyNewProjects\qfli_c
# canonical pipeline (pure Dart, no Flutter)
dart run tool/generate_forge_content.dart            # public entry; stages rows
dart run tool/verify_forge_content.dart              # 200/200 native compile+run
dart run tool/forge_content/negative_probe.dart      # 10/10 failure + isolation
# app tests
flutter test test/forge_content_integration_test.dart
flutter test test/forge_content_pipeline_test.dart
flutter test
```

Verifier must print pass/fail counts and an explicit list of unavailable
execution environments (e.g. Apple/device) rather than claiming success.

## Risky files / rollback points

- The two shared-core aggregate JSONs (only authorized change; coordinated,
  serialized, freshness-checked, fingerprint-guarded).
- `qfli_c/pubspec.yaml` assets list (only if staging assets are bundled).
- Large generated JSON (regenerate, never hand-edit).
- Rollback after a live merge restores **only the owned C/C++ rows** from the
  pre-merge row backup, after a live-merge review. Never restore a whole asset
  file from backup (would clobber concurrent writers). Authored topic sources
  remain the recoverable source of truth.

## Two-worker ownership (as delivered)

- C worker: `tool/forge_content/forge_topic.dart`, `c_topics_*.dart`,
  `forge_topics.dart`, `generate_forge_content.dart`, `build_core_patch.dart`,
  `tool/generate_forge_content.dart` (thin entry),
  `test/forge_content_integration_test.dart`.
- C++ worker: `cpp_topics_*.dart`, `native_compiler_host.dart`,
  `verify_forge_content.dart`, `merge_forge_content.dart`, `negative_probe.dart`,
  `tool/{verify,merge}_forge_content.dart` (thin entries),
  `test/forge_content_pipeline_test.dart`.
- Shared (serialized): `forge_topics.dart`, staged artifacts. Neither worker edits
  `qfli_studio_core` except through the coordinator-approved scoped merge.

## Review gates

- >= 100 C and >= 100 C++ tutorial rows, and >= 100 of each for examples.
- Zero duplicated explanation/summary/exercise strings per language; C vs C++
  curricula genuinely distinct.
- Every sample executed on a genuine native compiler with matching output.
- Non-C/C++ aggregate rows and top-level metadata untouched (fingerprints).
- Tutorial and Examples tabs show and run the new content.
- Only the two authorized core asset JSONs change in the shared core.

## Follow-up checks before `task.py start`

- Confirm the shared-core merge is executed only through the coordinator
  `require_escalated` gate (after local artifacts + verifier pass).
- Use the confirmed modern toolchain (`qfli-java-build` WSL) for native sample
  verification; keep the Windows TDM-GCC path as a fallback.
- Ensure `implement.jsonl` and `check.jsonl` hold real spec/research entries
  (done, including the reviewer verification plan).
