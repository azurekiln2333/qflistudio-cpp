# C/C++ Curriculum Content Audit

Read-only audit performed 2026-10-12 against `D:/MyNewProjects/qfli_c` and the
read-only sibling `D:/MyNewProjects/qfli_studio_core`. No product code or shared
core files were modified.

## 1. Where tutorial/example data actually lives

The C app (QFLIForge) renders its Tutorial and Examples tabs from the shared
core's **aggregate** content assets:

- `qfli_studio_core/assets/content/tutorials.json` (3.56 MB, top-level `entries`)
- `qfli_studio_core/assets/content/examples.json` (1.69 MB, top-level `entries`)
- read by `qfli_studio_core/lib/content/asset_content_repository.dart`
  (`AssetContentRepository`, asset keys `packages/qfli_studio_core/assets/content/tutorials.json`
  then `assets/content/tutorials.json`).

The core's older per-language bundle `qfli_studio_core/assets/tutorials/<lang>.json`
is consumed only by `TutorialService`, which is referenced solely from
`qfli_studio_core/test/tutorial_test.dart` and `test/studio_profile_test.dart`.
The running C app does **not** use it.

## 2. App entry / import / run flow (confirmed)

- `qfli_c/lib/main.dart:25-41` defines `forgeProfile` with
  `productKey: StudioProductCatalog.forgeKey` (`'forge'`), `isOffline: true`,
  `showHomeTabs: false`.
- `qfli_studio_core/lib/pages/home_page.dart:214-236` builds the Tutorial tab as
  `LocalTutorialsTab(language: profile.id, ...)` and the Examples tab as
  `ExampleCodeTab(language: profile.id, ...)`, with **no `repository` argument**.
- `qfli_studio_core/lib/pages/local_content_pages.dart:45,125` therefore
  constructs `AssetContentRepository()` itself.
- `qfli_studio_core/lib/content/local_content_adapter.dart:84-90` filters by
  `ContentFilter.forProduct(productKey)`.
- `qfli_studio_core/lib/content/content_repository.dart:33` maps
  `'forge' -> {'c', 'cpp'}`.
- Lesson detail: `local_content_pages.dart` `_LessonPage` (tap a lesson).
  Example detail: `ExampleDetailPage` (`local_content_pages.dart:325+`), which
  loads the bundled example into an editable snippet
  (`_ExampleCodeTabState._loadExamples` at lines 140-166).

## 3. Current counts and placeholder evidence

Aggregate `tutorials.json`: 16 languages x 100 entries = 1600 tutorial entries.
Aggregate `examples.json`: same 1600 entries. Filtered to `forge` = `{c, cpp}`:
**200 tutorial entries (100 C + 100 C++) and 200 example entries.**

Placeholder proof (aggregate `tutorials.json`, per language, distinct
`lessons[0].explain`):

| language | entries | unique explain |
| --- | --- | --- |
| java | 100 | **100** (authored) |
| python | 100 | 1 (placeholder; authored source exists, generator not run) |
| c | 100 | **1** (placeholder) |
| cpp | 100 | **1** (placeholder) |
| dart | 100 | 1 |
| lua | 100 | 1 |

For C: 100 entries have only **1** distinct `lessons[0].explain`, **1** distinct
`lessons[0].summary`, **1** distinct first-exercise prompt, and **24** distinct
lesson titles. Titles follow a generic software-engineering template
(`C 001: 数据建模与不变量`, `C 002: 输入校验与错误边界`, ...). C and C++ share
the **identical** concept sequence; only the language label and the code snippet
differ. `cpp.json` legacy bundle has only 2 lessons; `c.json` has 12.

## 4. Reusable authored-curriculum blueprint (already in the core)

Java is the reference implementation of a *substantive* curriculum:

- `qfli_studio_core/tool/java_content/java_topic.dart` (topic model)
- `qfli_studio_core/tool/java_content/java_topics.dart` (127 KB, 100 authored topics)
- `qfli_studio_core/tool/generate_java_content.dart` (emits aggregate rows)
- `qfli_studio_core/tool/verify_java_content.dart`
- Java sample `java-tutorial-001` has real `objective`, `prerequisites`,
  `pitfalls`, substantial `explain`, a complete `code`, and exact `output`.

Python mirrors this (`tool/python_content/`, `generate_python_content.dart`,
`verify_python_content.dart`) with a runtime enum (`embedded`/`cpython`) and an
executor (`tool/python_content/run_embedded.py`). Its generator imports
`python_content/python_topics.dart`, which is currently absent from disk (the
generator has not been run to completion).

Both generators: read the live aggregate file, replace only their own language
rows, preserve all other rows and top-level metadata, and write a manifest of
foreign fingerprints so the verifier can prove other languages were untouched.

## 5. Integration path (resolved: approach A, scoped asset merge)

There is no app-local content override. `StudioProfile` exposes no content
repository/hook (`studio_profile.dart` fields: templates, runner,
webPreviewFactory, toolsPageBuilder, documentToolBuilder,
terminalCommandDelegate, editorFileTools, entryFileNames, isOffline, productKey,
showHomeTabs, runtimeKind, runtimeStatus, supportedFileExtensions). The core's
`home_page.dart` builds `LocalTutorialsTab`/`ExampleCodeTab` without a
`repository`, so `AssetContentRepository` (core assets only) is always used.

Consequence: the C/C++ rows in
`qfli_studio_core/assets/content/{tutorials,examples}.json` are the single
source of truth for the C app. The chosen approach (A) keeps the authored
topics, generator, and verifier in `qfli_c` and performs a **coordinated,
serialized, freshness-checked scoped merge of only the C/C++ rows** into those
two aggregate files, executed through the known coordinator
`exec_command require_escalated` gate. Atomic rename + a precheck alone is not
sufficient against concurrent language writers; the merge aborts on any
foreign-fingerprint change and backs up only the owned C/C++ rows for rollback.
No new core repository hook and no navigation change are introduced, so no core
source file is edited — only the two content JSONs.

`content_validator.dart:22` sets `releaseMinimumPerType = 100`, counting by
`type`, for both `tutorials` and `examples`. C and C++ must therefore each keep
**at least 100** tutorial rows and 100 example rows, so the target is
**100 C + 100 C++ = 200 pairs** (not a reduction to 60).

## 6. Lessons from the read-only audit that constrain the plan

- Authored topics, generator, and verifier live in `qfli_c`; the only shared-core
  change is the coordinator-gated scoped merge of C/C++ rows into the two
  aggregate content JSONs (coordinated/serialized, freshness-checked,
  foreign-fingerprint-guarded, own-row backup, concurrent-writer aware). No other
  core file, hook, or navigation change.
- Keep each language at >= 100 tutorial and >= 100 example rows to satisfy the
  release validator.
- Reuse the Java/Python generator+verifier pattern rather than inventing a new
  content pipeline.
- Native compiler execution is the primary and only criterion; the in-app
  interpreter is a separate C-only smoke check. `compiler_unavailable` is a hard
  environment failure, never a fallback.
- Compiler capability: resolved. Independent compile+run verification confirmed
  a working modern host toolchain in the **`qfli-java-build` WSL2 distro**
  (clang++ 18.1.3 / g++ 13.3.0; verified through C++23 and C17/C2x; project tree
  reachable via `/mnt/d`). The earlier GCC 4.9.2-only finding came from probing the
  broken `Ubuntu` WSL and Windows, and is superseded. Android NDK clang and the
  in-repo WASI clang 22 are **cross** compilers and are not host-example
  validators. Standards are still chosen per sample with the exact `-std`
  recorded; only a feature no available toolchain can compile becomes an
  enumerated `standard_unavailable`.
- Preserve the aggregate `entries` schema: `id`, `language`, `type`, `locale`,
  `level`, `title`, `summary`, `concepts`, `source`, `license`, `updatedAt`,
  `lessons[]` (each with `id`, `title`, `summary`, `concepts`, `objective`,
  `prerequisites`, `explain`, `code`, `output`, `pitfalls`, `exercises[]`), and
  for examples `code`, `expectedOutput`, `inputFixtures`, `templateType`,
  `sourceLessonId`.
