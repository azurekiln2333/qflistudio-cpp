# Owned files for a narrow commit

`qfli_c` has ~58 unrelated pre-existing dirty changes. This lists only the files
this task owns, so a coordinator can stage exactly this task's change. Paths are
repo-relative. Do not stage anything outside this list.

## New files (this task)

Authored model + C track + aggregator + generator (C worker):

- `tool/forge_content/forge_topic.dart`
- `tool/forge_content/c_topics_beginner.dart`
- `tool/forge_content/c_topics_intermediate.dart`
- `tool/forge_content/c_topics_adv_a.dart`
- `tool/forge_content/c_topics_adv_b.dart`
- `tool/forge_content/c_topics_adv_c.dart`
- `tool/forge_content/forge_topics.dart`
- `tool/forge_content/generate_forge_content.dart`
- `tool/generate_forge_content.dart` (thin public entry)
- `tool/forge_content/check_c_topics.dart` (C native checker)
- `tool/forge_content/build_core_patch.dart` (C/CPP-only patch builder)

C++ track (C++ worker):

- `tool/forge_content/cpp_topics_beginner1..4.dart`
- `tool/forge_content/cpp_topics_intermediate1..6.dart`
- `tool/forge_content/cpp_topics_advanced1..4.dart`
- `tool/forge_content/native_compiler_host.dart`
- `tool/forge_content/verify_forge_content.dart`
- `tool/forge_content/merge_forge_content.dart`
- `tool/forge_content/check_topics.dart`, `tool/forge_content/probe_native.dart`
- `tool/verify_forge_content.dart`, `tool/merge_forge_content.dart` (thin entries)

Tests + spec:

- `test/forge_content_integration_test.dart` (this worker)
- `test/forge_content_pipeline_test.dart` (C++ worker)
- `.trellis/spec/frontend/forge-curriculum.md` + `index.md` entry

Generated (regenerate, do not hand-edit):

- `tool/forge_content/staging/**` (optional to commit; reproducible)

Task metadata (coordinator-owned):

- `.trellis/tasks/10-12-c-cpp-substantive-curriculum/**`

## Not owned (never stage)

- Any `lib/**`, `android/**`, `ios/**`, `web/**`, `native/**` change already in
  the working tree (pre-existing, other workers).
- `../qfli_studio_core/**` (separate repo; external-write gate only).

## Shared-core commit (external-write gate)

Never stage the whole working `assets/content/{tutorials,examples}.json` (it may
contain other languages' edits). Use the C/CPP-only patch builder:

```sh
cd qfli_c
dart run tool/forge_content/generate_forge_content.dart       # stage rows
dart run tool/forge_content/build_core_patch.dart             # C/CPP-only patches
# coordinator, in qfli_studio_core:
git apply --cached tool/forge_content/staging/core-patch/tutorials.json.patch
git apply --cached tool/forge_content/staging/core-patch/examples.json.patch
```

The patches are built against the **index** version of the core assets, replace
only `language in {c, cpp}` rows in place, and preserve every foreign row and all
top-level metadata (`updatedAt` included).
