# Curriculum and portability review, 2026-10-16

## Scope and data ownership

All work remains under `D:/MyNewProjects/qfli_c`. The app now bundles
`tool/forge_content/staging/{forge_tutorials,forge_examples}.json` and constructs
`ForgeContentRepository` from the production `forgeProfile` factory. Both assets
are explicitly listed in `pubspec.yaml`. No sibling asset/source write or merge
is needed for this delivery; earlier shared-core merge reports are historical.

## Authoring, generation and substantive-content checks

The actual generator was copied only to redirect its output into ignored
`native/build/forge-curriculum-review-20261016/regenerated`. It imported the real
authored topic files. All tutorial/example/manifest data match the bundled JSON
after ignoring only generation timestamps; production assets were not rewritten.

| Language | Tutorials | Examples | Beginner | Intermediate | Advanced |
| --- | --- | --- | --- | --- | --- |
| C | 100 | 100 | 34 | 30 | 36 |
| C++ | 100 | 100 | 34 | 41 | 25 |

Each language has 100 distinct explanations, summaries, programs, titles and
first exercises. Required fields are present, every program spans multiple
lines, and no `weighted=`, `TODO` or placeholder signature exists in the program
or explanation. Paired tutorial/example source and outputs are identical.
Standards remain C17 x100, C++17 x80 and C++20 x20.

The only explicit WASI expected-output fields belong to `c-example-067` (errno)
and `c-example-072` (target macros); native expected output is retained. These
fields select expected output without replacing executable source. In
particular, C++ thread lessons 090-093 retain exactly the source in the existing
Git HEAD and remain real thread/mutex/atomic/condition-variable programs.

Bundled SHA256:

- Tutorials: `2e0169ba45f9b438f327f46afca6a5e28a06a527478cb0ace26e55cee369aa31`.
- Examples: `91c92ac7265b0dc777f154bb8a51ff35cb94cab4ec0b7548f4c8409ed3455cac`.
- Manifest: `769136d6ce6045b5b378524984b54694c7a8f8af54d1689a522cd83af5cf54c3`.

Reproducible review artifacts are under
`native/build/forge-curriculum-review-20261016/`; `content-review.json` records the
counts and hashes. Existing native evidence
`research/cpp-content-verification.json`, generated at
`2026-10-15T19:40:50.326532Z`, has exactly 200 unique successful IDs, matching
current standards, zero shape errors and zero staged-source mismatches. This
review checked that evidence without relabeling it as a new native execution.

## Final WASI host matrix

The complete matrix passed **200/200** with the final patched core and
`runtime-probe-reviewed` at `2026-10-15T20:20:41.335486+00:00`. The durable
per-course report is `research/portable-curriculum-2026-10-16.json`; the canonical
working copy is `native/build/portable-curriculum-20261016.json`. The earlier
report is retained as `native/build/portable-curriculum-20261016-previous-runtime.json`
and is not relabeled as evidence for the final fixes.

- Compiler binary SHA256:
  `e09099acd231d8f69c53ae41e9f37453a8112e0fe67cdb77c6bdb94c738808af`.
- Runtime binary SHA256:
  `149bcd647cffc34c3088f9ff2a88283cfd5e018d403f6b52e01a84041fb00da2`.
- Complete report SHA256:
  `2af8df57ade7db9cfcb8a98d1de87f8f64c56b1101af583bef70c6c4a7308e74`.

All 200 result IDs are unique, each compiled and exited zero, stdout matches the
selected expected output, and stderr is empty. Every source hash matches the
current bundled row; both full asset hashes match the values above.

The persistent regression now rejects a missing/duplicate course or mismatched
tutorial/example source/output before compilation. Negative checks for a
missing language track, duplicate ID and changed paired source all pass. Reports
include tool and bundled-asset SHA256 plus per-course source, selected output and
stdin SHA256. All 200 original programs compile with the WASI threads target.

## Real phone and product UI gates

The coordinator's signed OHOS audit completed **212/212 unique cases** on the
nova 14 Ultra: 12 runtime/compiler/error/cancellation/output checks plus all
100 C and 100 C++ programs. The persistent device report is
`../../10-01-cross-platform-native-runtime/research/ohos-portable-device-2026-10-16.json`.
All 200 curriculum IDs are present once, exit zero and have empty stderr.
Audit HAP SHA256:
`e85120111893d9a319eb1160440037f26e2cd13e14b154fbf186e91087c7c1d2`.

The coordinator also accepted the ordinary production UI using the verified
`lib/main.dart` HAP installed with `install -r`; existing `sss` and `tt` user data
were retained. A new scratch C++ project ran `Hello, QFLIStudio+!`, Stop reported
130 during compilation, and a fresh Run succeeded. The Tutorial list and lesson detail displayed
the objective, source, output and exercises. The Examples list explicitly showed
200 entries, and example detail displayed source and expected output.

Persistent production HAP/hash/UI evidence is
`../../10-01-cross-platform-native-runtime/research/ohos-production-ui-2026-10-16.json`.
Production HAP SHA256:
`f7472a09e0bd8773cfd971908653a41a1f96df754ea7ca78e8b10d26f1000e69`.
Screenshots are `native/build/qfli-production-{run,stop,tutorials,lesson,examples}-20261016.jpeg`.
These are actual product UI checks, separate from the complete 212-case audit.
The independent curriculum task is complete; the broader cross-platform runtime
task remains open. No Android device run or Apple/Web completion is claimed.
