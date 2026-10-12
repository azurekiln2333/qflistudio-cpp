# Proposed commits (task-owned only) — awaiting user confirmation

`qfli_c` currently has ~61 dirty entries; most are pre-existing and unrelated to
this task. Stage **only** the paths below — never `git add -A`. Task remains
`in_progress` until the user confirms the commit. Nothing is staged by this plan.

## Commit 1 — authored C/C++ curriculum + pipeline (qfli_c)

Suggested message:

```
feat(forge): add 200 substantive C/C++ tutorial and example topics

Author 100 C and 100 C++ paired lessons (beginner/intermediate/advanced) with
Chinese explanations, runnable samples, expected output, pitfalls and exercises.
Add the generator, native verifier, negative/isolation probes, scoped merge and
C/CPP-only patch builder, plus live-core integration tests and the curriculum
spec. Verified 200/200 native compile+run (WSL clang18/g++13); flutter test
174/174; live core equals authored source.
```

Files to stage (all new/untracked unless noted):

```
tool/forge_content/forge_topic.dart
tool/forge_content/c_topics_beginner.dart
tool/forge_content/c_topics_intermediate.dart
tool/forge_content/c_topics_adv_a.dart
tool/forge_content/c_topics_adv_b.dart
tool/forge_content/c_topics_adv_c.dart
tool/forge_content/cpp_topics_beginner1.dart
tool/forge_content/cpp_topics_beginner2.dart
tool/forge_content/cpp_topics_beginner3.dart
tool/forge_content/cpp_topics_beginner4.dart
tool/forge_content/cpp_topics_intermediate1.dart
tool/forge_content/cpp_topics_intermediate2.dart
tool/forge_content/cpp_topics_intermediate3.dart
tool/forge_content/cpp_topics_intermediate4.dart
tool/forge_content/cpp_topics_intermediate5.dart
tool/forge_content/cpp_topics_intermediate6.dart
tool/forge_content/cpp_topics_advanced1.dart
tool/forge_content/cpp_topics_advanced2.dart
tool/forge_content/cpp_topics_advanced3.dart
tool/forge_content/cpp_topics_advanced4.dart
tool/forge_content/forge_topics.dart
tool/forge_content/generate_forge_content.dart
tool/forge_content/native_compiler_host.dart
tool/forge_content/verify_forge_content.dart
tool/forge_content/negative_probe.dart
tool/forge_content/merge_forge_content.dart
tool/forge_content/build_core_patch.dart
tool/generate_forge_content.dart      # thin public entry
tool/verify_forge_content.dart        # thin public entry
tool/merge_forge_content.dart         # thin public entry
test/forge_content_pipeline_test.dart
test/forge_content_integration_test.dart
.trellis/spec/frontend/forge-curriculum.md
.trellis/spec/frontend/index.md       # MODIFIED (already tracked): adds entry
```

Notes on accuracy:
- `tool/` is entirely untracked now, so every `tool/...` path above is a new file
  (including `tool/generate_forge_content.dart` etc.).
- `.trellis/spec/frontend/index.md` is the only **modified tracked** file.
- `.trellis/tasks/10-12-c-cpp-substantive-curriculum/**` (task metadata) is
  coordinator-owned; include it only if the coordinator wants task records in the
  same commit (it is untracked today).

Do NOT stage (excluded):

- `tool/android_native_audit.dart` — pre-existing, unrelated, untracked.
- `tool/forge_content/staging/**` and `tool/forge_content/merge-backups/**` —
  generated/operational artifacts, reproducible; not source.
- The removed scratch checkers (`check_c_topics.dart`, `check_topics.dart`,
  `probe_native.dart`) — already deleted; not in the tree.
- Every pre-existing dirty change under `lib/`, `android/`, `ios/`, `web/`,
  `native/`, `ohos/`, `packages/`, `assets/`, `pubspec.*`, and untracked
  `.gitattributes` / `AGENTS.md`.

## Commit 2 — shared core content (separate repo; coordinator gate)

Apply the C/CPP-only patch and commit in `qfli_studio_core` only. Suggested
message:

```
content(forge): replace C/C++ tutorial and example rows

Replace the placeholder C/C++ rows with 100 C + 100 C++ authored tutorials and
paired examples. Only language in {c, cpp} rows change; all foreign-language rows
and top-level metadata are preserved.
```

Procedure (never stage the whole asset file):

```sh
cd qfli_c
dart run tool/generate_forge_content.dart
dart run tool/forge_content/build_core_patch.dart
# coordinator, in qfli_studio_core:
git apply --cached <qfli_c>/tool/forge_content/staging/core-patch/tutorials.json.patch
git apply --cached <qfli_c>/tool/forge_content/staging/core-patch/examples.json.patch
git commit -m "content(forge): replace C/C++ tutorial and example rows"
```

The patches are built against the git index baseline and replace only `{c, cpp}`
rows in place, preserving foreign rows and all metadata.

## Validation before requesting confirmation

```
dart run tool/verify_forge_content.dart          # 200/200
dart run tool/forge_content/negative_probe.dart  # 10/10
flutter test                                     # 174/174
dart analyze <task tools + tests>                # No issues
```
