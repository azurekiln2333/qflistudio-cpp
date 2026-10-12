# Implementation plan: C/C++ substantive curriculum

Implementation approved by the user on 2026-10-12: `确认实施`, following the
final 200-pair planning summary. Shared-core writes still use the coordinator
external-write gate after local preparation and verification.

## Decisions already resolved (no open technical question)

- Count: **100 C + 100 C++ = 200 pairs**, preserving the core release validator
  minimum of 100 entries per type for both tutorials and examples
  (`content_validator.dart:22`).
- Integration: **approach A** — authored topics, generator, and verifier live in
  `qfli_c`; the generator emits C/C++ replacement rows and performs a
  **coordinated/serialized, freshness-checked scoped merge** into the shared
  core's two aggregate content JSONs. Rollback restores only the owned C/C++
  rows. No new core repository hook and no navigation change.
- Verification: **native compiler execution is the primary and only criterion**;
  `compiler_unavailable` is a hard environment failure, never an interpreter
  fallback. The in-app interpreter is a separate smoke check.
- Standards: chosen **per sample** to match the runner actually used. A modern
  toolchain is confirmed in the `qfli-java-build` WSL distro (modern
  `clang++`/`gcc`); the Windows TDM-GCC 4.9.2 (C11 / C++14) is a working
  fallback. Record the exact `-std` per example.

## Status

Implementation is complete and validated by repository/live data and desktop
runner automation:

- Canonical verifier `tool/verify_forge_content.dart`: **200/200** native
  compile+run (WSL clang++ 18 / g++ 13); `negative_probe.dart`: **10/10** failure
  and isolation probes.
- `flutter test`: **174/174**, including `test/forge_content_integration_test.dart`
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
