# C and C++ substantive tutorial curriculum

## Goal

2026-10-16 delivery update: this app now bundles its authored staging JSON and
loads it through `ForgeContentRepository`; no sibling repository write or shared
asset merge is required. All 200 paired sources remain substantive. Acceptance
requires both native-host execution and the complete WASI compiler/interpreter
matrix, with phone execution and ordinary Tutorial/Examples UI checked separately.
The signed phone audit passed 212/212 unique cases including all 200 courses;
the coordinator also accepted ordinary production Run/Stop, fresh Run,
Tutorial/lesson and the 200-entry Examples/detail UI. The independent curriculum
task is complete; the broader runtime task remains open.
Historical shared-core requirements
below describe the original delivery and are superseded for current integration.

2026-10-15 re-audit: the user requested checking for remaining placeholders and
replacing the C/C++ dataset only if any remained. The latest instruction forbids
writes to sibling workspaces and authorizes conventional commits after checks.
All 400 live C/C++ tutorial/example rows match the authored staging data and
contain no placeholder padding; the conditional replacement is unnecessary.
The original replacement requirements and historical merge evidence follow.

Replace the placeholder C/C++ learning content with **200 substantive,
non-repeating paired tutorials/examples** (100 C + 100 C++, balanced C and C++,
beginner through advanced engineering). Each pair must have a Chinese
explanation, a complete runnable program, exact expected output, pitfalls, and
at least one exercise, plus difficulty and prerequisites. The C app's Tutorial
and Examples tabs must consume them, and every example must be **verified on a
genuine native C/C++ compiler**.

## Background (confirmed facts)

Full evidence and file:line anchors are in `research/content-audit.md`.

- The C app renders Tutorial/Examples from the shared core's aggregate assets
  `qfli_studio_core/assets/content/{tutorials,examples}.json`, filtered to
  `productKey: 'forge'` = `{c, cpp}` (`studio_profile.dart:33`,
  `local_content_adapter.dart:84-90`, `content_repository.dart:33`).
- Current C/C++ aggregate content is placeholder: 100 C + 100 C++ tutorial rows
  with only **1** distinct lesson explanation, 1 distinct summary and 1 distinct
  exercise prompt per language; C and C++ share identical concept sequences.
- **Release validator requires >= 100 entries per type for both tutorials and
  examples** (`content_validator.dart:22`, `releaseMinimumPerType = 100`), so
  the C and C++ curricula must each keep **at least 100** tutorials and 100
  examples. The target is therefore 100 C + 100 C++ = 200 pairs.
- The core already ships a substantive-curriculum blueprint for Java and Python:
  authored topic files under `tool/<lang>_content/`, a generator that rewrites
  only that language's aggregate rows, and a real-execution verifier.
- The shared core is a sibling repo with other agents working in it; the C/C++
  row replacement there is required integration, not optional, but happens only
  after an explicit external-write approval.

## Requirements

- R1: Author **100 C + 100 C++ topics** (200 total) with balanced level
  coverage; no repeated filler text, template titles, or duplicated
  explanations.
- R2: Every topic is a **paired** tutorial lesson + example with: Chinese
  `explain`, complete `code`, exact `output`/`expectedOutput`, `pitfalls`,
  `objective`, `prerequisites`, `concepts`, `level`, and a language standard
  (C or C++). The standard is chosen **per sample** to match what the supported
  app runner can actually compile on the checking host, and the existing schema
  text fields carry any standards note (no new JSON field).
- R3: C and C++ curricula are **distinct**, not the same concept list with a
  swapped snippet.
- R4: Content is emitted into the aggregate `entries` schema the app already
  parses (tutorial and example rows), preserving all non-C/C++ rows and
  top-level metadata via a coordinated, freshness-checked scoped merge against
  the current file.
- R5: The app's Tutorial tab, Lesson detail, Examples tab, and Example detail
  must display the new content, and each example must compile and run via the
  **native desktop compiler** with stdout matching `expectedOutput`.
- R6: Provide a verifier that cross-checks authored source against emitted rows
  and **compiles and runs every sample with a genuine native C/C++ compiler**
  (the desktop toolchain already proven by `test/clang_runner_test.dart`). If the
  native compiler is unavailable the run fails with `compiler_unavailable` — a
  hard environment failure, never an interpreter fallback. The in-app interpreter
  is a separate smoke check only, never the criterion that counts an example as
  verified. A modern native toolchain is available (see Technical Notes), so
  C17/C++17/C++20 samples are expected to compile; the verifier still records the
  `-std` used per sample.
- R7: Workspace writes stay under `D:/MyNewProjects/qfli_c` until the known
  coordinator external-write gate (`exec_command require_escalated`) is executed.
  The only shared-core edit is the C/C++ row replacement in
  `assets/content/tutorials.json` and `assets/content/examples.json`, performed
  as a coordinated, freshness-checked, foreign-fingerprint-guarded scoped merge;
  rollback restores only the owned C/C++ rows. No other core file is touched and
  no new core repository hook or navigation is added.

## Acceptance Criteria

- AC1 (R1, R3): A verifier reports >= 100 C and >= 100 C++ tutorial rows and
  the same for examples, balanced levels, **zero** duplicate
  `explain`/`summary`/first-exercise strings within a language, and distinct
  C vs C++ concept coverage.
- AC2 (R2): Every emitted topic carries all required fields; a schema check
  fails on any missing `objective`, `prerequisites`, `pitfalls`, `level`, or
  per-sample standard record.
- AC3 (R4, R7): Regenerating leaves all non-C/C++ aggregate rows and top-level
  metadata byte-identical (fingerprint manifest proves it); only C/C++ rows in
  the two asset files change.
- AC4 (R5): The C app shows the C/C++ lessons in the Tutorial tab and examples
  in the Examples tab; opening an example and running it produces
  `expectedOutput` on the native compiler.
- AC5 (R6): The verifier compiles+runs every sample on the available native
  compiler and reports pass/fail counts; unavailable Apple/device execution is
  stated explicitly and never counted as verified.
- AC6 (R7): No file outside the two authorized core asset JSONs and the
  `qfli_c` workspace is modified.

## Out of scope

- Rewriting Java, Python, Dart, Lua, Web, or other language curricula.
- Adding new core repository hooks, navigation entries, or runtime engines.
- Editing core source files other than the two authorized content JSONs.
- Non-C/C++ UI changes.

## Integration and approval

- The integration is **approach A**: authored topics, generator, and verifier
  live in `qfli_c`; the generator writes C/C++ replacement rows into a local
  staging copy and performs the scoped merge into the shared core's two
  aggregate content JSONs.
- The external-write gate is a **known coordinator step**: after local artifacts
  are prepared and the verifier passes, the coordinator authorizes the merge via
  an `exec_command` with `require_escalated`. It is not an open product decision.
- Until that gate is executed, all artifacts and generated rows stay in `qfli_c`.

## Open questions

None blocking. The compiler question is resolved: independent verification
confirmed a working modern host toolchain (`qfli-java-build` WSL, clang++ 18 /
g++ 13, compile+run verified through C++23 and C17/C2x), so the earlier
GCC 4.9.2-only finding is superseded. The external-write merge gate
(`exec_command require_escalated`) is a known sequenced step, not a product
decision.

## Technical notes

- Verified toolchain (independently compile+run tested): **`qfli-java-build` WSL2
  distro** — host `clang++` 18.1.3 and `g++` 13.3.0; verified running through
  C++23 (`std::ranges`, `optional`, `string_view`, `if constexpr`) and C17/C2x.
  The project tree is compilable from inside via `/mnt/d`. The distro is
  `qfli_java`-owned: never delete/reconfigure it; hard-fail `compiler_unavailable`
  if absent.
- Secondary fallback: Windows Dev-Cpp TDM-GCC 4.9.2 (C11 / C++14).
- Not validators: Android NDK clang (18/19) and the in-repo WASI clang 22 are
  **cross** compilers (they emit target objects/WASM, not host executables).
- `lib/clang_runner.dart` desktop probe already spans C17/C11 and C++20/17/14/11,
  so no code change is needed to reach C++20 on WSL.
- Standards are chosen **per sample** to match the runner used, and the verifier
  records the exact `-std` (and WSL distro/version) per example so the ceiling is
  auditable. Advanced C++ stays native; only a feature no available toolchain can
  compile becomes an enumerated `standard_unavailable`, never an interpreter
  downgrade.
