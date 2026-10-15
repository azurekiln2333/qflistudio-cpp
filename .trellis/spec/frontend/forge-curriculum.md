# Forge Curriculum Contract (C/C++ learning content)

> Executable contract for authoring, generating, verifying and merging the
> QFLIForge C/C++ tutorial/example curriculum. English only.

---

## 1. Scope / Trigger

Applies whenever you author or change the QFLIForge learning content or its
pipeline: `tool/forge_content/**`, the generated aggregate rows, or the app's
tutorial/example tabs. This is cross-layer work (content source -> generator ->
aggregate JSON -> core content repository -> app UI -> runner), so code-spec
depth is mandatory.

The app renders Tutorial and Examples from the shared core's aggregate assets
`qfli_studio_core/assets/content/{tutorials,examples}.json`, filtered to
`productKey: 'forge'` = types `{c, cpp}`. The C/C++ rows in those two files are
the single source of truth for the app.

---

## 2. Signatures

Authored model and pipeline (all under `qfli_c`):

```dart
// tool/forge_content/forge_topic.dart
class ForgeTopic {
  const ForgeTopic({
    required int id,            // 1..100 within a language
    required String language,   // 'c' | 'cpp'
    required String level,      // 'beginner' | 'intermediate' | 'advanced'
    required String title,
    required String summary,
    required List<String> concepts,
    required String objective,
    required String explain,    // substantive Chinese prose, topic-specific
    required String code,       // complete runnable program
    required String output,     // exact stdout (verifier-normalized)
    required String standard,   // 'c17' | 'c11' | 'c++20' | 'c++17'
    List<String> pitfalls = const [],
    List<String> prerequisites = const [],
    String? input,              // optional stdin -> input.txt
    List<ForgeTask> tasks = const [],
  });
  String get tutorialId; // '$language-tutorial-0NN'
  String get exampleId;  // '$language-example-0NN'
}
class ForgeTask { final String prompt, hint, answer; }
```

Commands (run from `qfli_c`):

```sh
dart run tool/forge_content/generate_forge_content.dart   # stage rows locally
dart run tool/verify_forge_content.dart                  # native run: all 200
dart run tool/forge_content/negative_probe.dart          # failure/isolation gates
flutter test test/forge_content_integration_test.dart     # repository + run integration
```

---

## 3. Contracts

Source files (see `forge_topics.dart` for the full list):

- C track: `c_topics_beginner.dart` (34), `c_topics_intermediate.dart` (30),
  `c_topics_adv_a.dart` (10), `c_topics_adv_b.dart` (13), `c_topics_adv_c.dart` (13).
- C++ track: `cpp_topics_beginner1..4.dart` (34), `cpp_topics_intermediate1..6.dart` (41),
  `cpp_topics_advanced1..4.dart` (25).
- Aggregator `forge_topics.dart` exposes `cForgeTopics`, `cppForgeTopics`,
  `forgeTopics`. Never edit both tracks' topic files in the same change.

Generator output (local staging only, never the shared core by itself):
`tool/forge_content/staging/{forge_tutorials.json, forge_examples.json, forge_manifest.json}`.

Emitted aggregate row schema (matches `content_repository.dart`):

- Tutorial row: `id, language, type, locale, level, title, summary, concepts,
  source, license, updatedAt, lessons[]`.
- Lesson: `id, title, summary, concepts, objective, prerequisites, explain,
  code, output, pitfalls, exercises[]` (`exercises` items: `prompt, hint, answer`).
- Example row: `id, language, type, locale, level, title, summary, concepts,
  source, license, updatedAt, code, expectedOutput, inputFixtures, templateType,
  sourceLessonId`.

Hard constraints:

- **Standards ceiling**: runnable samples must stay within the packaged app
  maximum — C <= `c17`, C++ <= `c++20`. A `c++23`-only feature may be explained
  but must not be required by the paired runnable sample.
- **Self-contained samples**: `code` must compile and run on its own. The schema
  has no extra-file field and no hidden/verifier-only files are created. Teach
  modular decomposition in `explain` with an illustrative layout, never by
  `#include`-ing a file the app would have to invent.
- **Language is driven by `type`**, not the file name: a C++ row has
  `type: 'cpp'`, imports as `src/main.cpp`, and is compiled as C++. A C++ sample
  named `main.c` would compile as C and fail — never emit one.
- **No filler**: no templated titles, no repeated `explain`/`summary`, no
  `weighted=` placeholder signature, no one-line programs.
- **Foreign-row preservation**: a shared-core merge replaces only rows whose
  `language` is `c` or `cpp` — **strictly language-based, never by `type`** — so a
  foreign row that happens to carry `type: 'c'` is preserved untouched. Owned rows
  are replaced **in place**, preserving each foreign row's exact position, and
  **all** top-level metadata is preserved (nothing, including `updatedAt`, is
  overwritten). Backups capture only the owned rows and live under
  `qfli_c/tool/forge_content/merge-backups/`, never inside the shared core.
  Before writing, the merge re-reads the **complete** live document (metadata and
  row order) and aborts if the snapshot moved (concurrent writer).

---

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Topic id/title/code duplicated within a language | Generator `_check` throws `StateError`; do not stage |
| `code` single-line or contains `weighted=` | Generator throws `StateError` |
| Missing `objective`/`pitfalls`/`concepts`/`standard`/`output` | Generator throws `StateError` |
| C++ row not `type: 'cpp'` | Integration test fails (extension selection) |
| Sample stdout != `expectedOutput` | Native checker reports `FAIL`, exit 1 |
| Native compiler/WSL distro unavailable | Native checker reports `compiler_unavailable`, exit 2 (never a pass) |
| A feature no available toolchain can compile | Record `standard_unavailable` with the feature named; never reinterpret as interpreter-only |
| Foreign row carries `type: 'c'` but a non-C/C++ language | Treated as foreign; preserved untouched (ownership is `language`-based only) |
| Merge would change `updatedAt` or any top-level metadata | Rejected by the pipeline test; metadata is preserved verbatim |
| Foreign row position or content changes | Snapshot freshness check aborts the merge |
| Staged set is not exactly owned / ids not unique / empty code / wrong language | `validateStaging` reports errors and the merge aborts before any live read |
| Foreign-language fingerprint moved before merge | Abort the merge and re-run the read-check-merge cycle |

---

## 5. Good / Base / Bad Cases

- Good: every paired sample compiles and runs on the `qfli-java-build` WSL
  toolchain (gcc/g++ 13) with stdout exactly matching `expectedOutput`; C and C++
  curricula are distinct; the app loads 100 + 100 through the forge filter.
- Base: samples compile and run; the app UI is exercised by the integration test;
  Apple/device execution is explicitly out of scope and stated as such.
- Bad: claiming coverage from JSON shape alone, downgrading advanced C++ to the
  in-app interpreter, or emitting a C++ sample as `type: 'c'`.

---

## 6. Tests Required

- `dart run tool/verify_forge_content.dart`: compile and run
  every sample, assert exact stdout and exit 0; assertion point = per-topic diff.
- `flutter test test/forge_content_integration_test.dart`: assert
  (a) `ContentCatalog.fromJson` parses the staged files, (b) the `forge` filter
  yields 100 C + 100 C++ tutorials and examples, (c) every row carries the
  required fields, (d) levels are balanced (>= 25 each), (e) no duplicate
  explain/summary/first-exercise per language, (f) C vs C++ explanations differ,
  (g) `type` drives the extension (`cpp` -> `main.cpp`), (h) representative C and
  C++ examples run on the desktop runner with exact output, (i) an input fixture
  round-trips through `input.txt`.
- Generator run is idempotent and re-readable; `_check` rejects filler.

---

## 7. Wrong vs Correct

### Wrong

```dart
// C++ topic emitted with a C type, so it imports and compiles as C
ForgeTopic(id: 1, language: 'cpp', ..., standard: 'c++20')
// ...but the generator wrote type: 'c' or the sample was named main.c
```

### Correct

```dart
ForgeTopic(id: 1, language: 'cpp', type derives from language, standard: 'c++20',
  code: '#include <iostream>\nint main() { std::cout << "ok\\n"; }\n')
// generator emits type: 'cpp'; the app imports src/main.cpp and compiles as C++.
```

### Wrong

```text
# A sample that #includes a helper the app does not have
#include "utils.h"   // schema has no extra-file field
```

### Correct

```text
# One self-contained program; explain the would-be split across
# main.c / utils.h in `explain`, but keep `code` runnable on its own.
```
