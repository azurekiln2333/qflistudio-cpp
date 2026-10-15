# C++ substantive-curriculum live review (w6:p1 Codex)

Date: 2026-10-15
Reviewer: pi w6:p1 Codex (C++ semantic review worker)
Scope: **C++ track only** (semantic review of all 100 C++ tutorial/example pairs).
Mode: read-only. No files written except this report. No staging regeneration, no
native re-run (owned by pi w6:p4), no device/build/sign, no commit.

## 0. Environment gate (passed)

- `Get-Location` = `D:\MyNewProjects\qfli_c`
- `git rev-parse --show-toplevel` = `D:/MyNewProjects/qfli_c`

Both equal the authorized workspace, so the review proceeded. No sibling
workspace or other language file was written. The shared core
`D:/MyNewProjects/qfli_studio_core` was opened **read-only** for comparison only.

## 1. Artifacts compared

| Artifact | Role |
| --- | --- |
| `qfli_c/tool/forge_content/staging/forge_tutorials.json` | local staged C++ tutorials (100) |
| `qfli_c/tool/forge_content/staging/forge_examples.json` | local staged C++ examples (100) |
| `qfli_c/tool/forge_content/cpp_topics_{beginner1..4,intermediate1..6,advanced1..4}.dart` | authored C++ source of truth |
| `../qfli_studio_core/assets/content/tutorials.json` | live aggregate (all languages) |
| `../qfli_studio_core/assets/content/examples.json` | live aggregate (all languages) |

Live core rows filtered `language in {c, cpp}` = **200 tutorials + 200 examples
= 400 rows**, matching the task's "400 行" figure.

SHA256 (review snapshot):

- staging `forge_tutorials.json` = `174C2341BCC06576A5DBB68701AE33EDC052FD0EE9FD94…`
- staging `forge_examples.json`  = `B6DE9EABCC35C8A56BC90C0F61BD37E6F7FB7B088DD2B5…`
- core `tutorials.json` = `4822AE2977A8B518EBB5B3492002ADCECDDD17085599D7…`
- core `examples.json`  = `AADB0AAEE7B9D028F2880904E85C5819CA778E34D07002…`

## 2. Quantity (counts)

| Language / type | Staging | Live core (filtered) |
| --- | --- | --- |
| C tutorials | 100 | 100 |
| C examples | 100 | 100 |
| C++ tutorials | 100 | 100 |
| C++ examples | 100 | 100 |
| forge total (c+cpp) | 400 | **400** (200 + 200) |

Core aggregate totals (all languages) = 1620 tutorials + 1620 examples
(python = 120; every other language = 100). C/C++ are exactly the required
minimum of 100 each for tutorials and examples (`releaseMinimumPerType = 100`).

## 3. Staging vs live core — difference / duplication

Rows compared by `id` with full-row JSON serialization (`ConvertTo-Json -Depth 40`):

- C++ tutorial ids: staging 100, core 100; ids only in staging = **0**; only in core = **0**.
- C++ tutorial rows differing: **0**.
- C++ example rows differing: **0**.
- Example ids only in staging = 0; only in core = 0.

Conclusion: the live core C++ rows are **byte-identical (module JSON
serialization) to the staged rows**. The coordinator external-write merge is
reflected in the live core for C++. No staging drift and no partial/reverted
merge.

**Duplication / placeholder statistics — C++ (staging, identical in core):**

| Metric | Value |
| --- | --- |
| entries | 100 |
| unique `lessons[0].explain` | **100 / 100** |
| unique `lessons[0].summary` | 100 |
| unique top-level `summary` | 100 |
| unique `title` | 100 |
| unique `lessons[0].code` | 100 |
| unique `lessons[0].objective` | 100 |
| unique first-exercise `prompt` | 100 |
| duplicate explain / summary / title / code / first-exercise groups | **0 / 0 / 0 / 0 / 0** |
| core live unique `lessons[0].explain` | **100 / 100** |
| core live unique title | 100 |
| core live unique first-exercise | 100 |

The placeholder signature that previously defined this content (1 distinct
explain / 1 distinct summary / 1 distinct exercise for all 100 rows) is **gone**
in both staging and live core for C++. C behaves the same (100/100), verified
read-only for context.

## 4. Schema / field completeness (C++)

Staging C++ tutorials: **0 field issues** across `objective`, `prerequisites`
(all but topic 001, the intended root), `pitfalls`, `exercises`, `explain`
length, `level`, `concepts`.

Staging C++ examples: **0 field issues** across `code`, `expectedOutput`,
`level`, `concepts`, `sourceLessonId`, and `type`.

- tutorial `type` distribution: `cpp=100` (no row mislabeled).
- example `type` distribution: `cpp=100`; `templateType` = `cpp` for all 100.
- core: tutorial/example rows where `type != language` = **0** (no mislabel;
  this matters because language drives extension selection — `cpp` -> `main.cpp`).

Exercise tasks: **0** empty prompt / hint / answer across all 100 C++ topics.

## 5. Level balance

Authored and staged C++ levels:

| Level | Count | Requirement |
| --- | --- | --- |
| beginner | 34 | >= 25 ✔ |
| intermediate | 41 | >= 25 ✔ |
| advanced | **25** | >= 25 ✔ |

Standards declared per sample in the authored source: `c++17` = 80,
`c++20` = 20. Every sample is inside the packaged app ceiling (C++ <= `c++20`).
No `c++23`-only runnable sample was found.

## 6. Prose / code substance (人工语义核查)

- `explain` length: min 79, max 250, avg 115.2 chars; 0 topics below 50 chars,
  1 below 80 chars (topic 020, "头文件、inline 与编译链接" – still a full
  sentence-level explanation, not filler).
- example `code` length: min 139, max 1997, avg 459.4 chars; 0 samples below
  60 chars.
- 0 single-line samples; 0 rows containing `weighted=`; 0 rows containing
  `TODO`/`FIXME`/`placeholder` markers.
- 363 distinct `concepts` values for the C++ track.

Spot-read in full: advanced topics 76–82 (`cpp_topics_advanced1.dart`) and
90–91 (`cpp_topics_advanced3.dart`), plus beginner topics 1–2. All explanations
are topic-specific, technically accurate prose (e.g. `if constexpr` +
`std::is_integral_v`, fold expressions, `requires`-clause overload ordering,
forwarding references, `condition_variable::wait` predicate anti-spurious-wake),
not a reused template. Pitfalls and exercises are tailored to the individual
topic (e.g. "具名的右值引用变量本身是左值"; "忘记在 done 后也 notify 会让消费者
永久等待").

### Advanced coverage (25 topics, verified against actual sample content)

Title-vs-content consistency check per advanced topic (promised feature must
appear in the paired example code or explain): **0 gaps**.

Coverage confirmed present: `type_traits`, variadic templates + fold
expressions (077, regex confirms `...`/fold), `concepts`/`requires` (078/079),
perfect forwarding (080), value categories (081), SFINAE→concepts (082), CRTP
(083), policy design (084), type erasure (085), custom allocator (086),
`std::span` (087), ranges pipelines (088), `<=>` (089), `std::thread` (090),
mutex + condition_variable (091), atomics + memory order (092), memory model
(093), exception-safety guarantees (094), `noexcept` + move traits (095),
benchmarking (096), advanced compile-time computation (097), compile-time vs
runtime polymorphism (098), generic algorithms + projections (099), and an
integrated expression-interpreter project (100).

Note: coverage breadth is genuine; `filesystem`/`coroutine`/`string_view`
appear in the beginner/intermediate track (`std::string_view` topic 024,
`std::optional` 023, `std::variant` 065) rather than only in advanced, which is a
reasonable curriculum ordering, not a gap.

## 7. Prerequisite integrity

All non-empty C++ prerequisite strings resolve to an earlier real topic in the
track: **0 unresolved prerequisite strings**. Prerequisite chains are sequential
and coherent (e.g. 077 prerequisites `类型特征 type_traits`, 078 depends on
077, 079 on 078, 080 on 079, 081 on 080, …, 091 on 090).

## 8. Paired tutorial ↔ example integrity

For all 100 C++ topics: tutorial `lessons[0].code` == paired example `code` and
tutorial `lessons[0].output` == example `expectedOutput`: **0 mismatches**,
0 missing examples. Id space across the 400 staged rows: 400 ids, **400
unique** (0 collisions).

## 9. C vs C++ distinctness

Compare live core:

- C++ titles identical to any C title: **0 / 100**.
- C++ explains identical to any C explain: **0 / 100**.
- Authored-source shared code / explains / titles between languages: **0 / 0 / 0**
  (from `_review_probe.dart`).

The C and C++ curricula are genuinely distinct; C++ teaches the C++ surface
(`iostream`, references, `auto`, `std::string`/`vector`, range-for, overloads,
classes, RAII, move, templates, concepts, threads) rather than the C subset with
a swapped snippet.

## 10. Corroborating read-only probe

A pre-existing untracked read-only probe `tool/forge_content/_review_probe.dart`
(not authored by this worker; left untouched) reports for the **cpp** track:

```
cpp: 100 topics; levels={beginner: 34, intermediate: 41, advanced: 25};
distinct titles=100, codes=100, outputs=100, concepts=363
C/C++ shared code=0 explains=0 titles=0
Problems: 1
  - c duplicate output c-example-082
```

The single reported problem is `c duplicate output c-example-082`, which is in
the **C track** and therefore outside this C++ review's ownership. It is recorded
here only for the coordinator's attention to hand to the C worker (pi w6:p4),
not as a C++ defect. **C++ reports zero problems.**

## 11. Verdict

**No C++ defects found. No fix required.**

- 100/100 C++ tutorials and 100/100 C++ examples exist, are substantive, and are
  byte-identical between local staging and the live core.
- Zero duplicates of explain/summary/title/code/first-exercise in C++; zero
  placeholder filler; zero single-line/`weighted=`/TODO samples.
- Full required fields present (objective, prerequisites, pitfalls, level,
  concepts, exercises) with 100% exercise answer coverage.
- Levels balanced with 25 advanced topics; all promised advanced features are
  actually exercised by the paired runnable samples.
- C++ prerequisites all resolve; tutorial/example pairs are exactly consistent;
  C and C++ are distinct.
- The only anomaly in the probe output belongs to the C track.

Consequently **no edit to `tool/forge_content/cpp_topics*.dart` (or any other
file) was made**, and no regeneration was requested from this worker. This
matches the instruction not to delete already-substantive data and to only touch
C++ topic sources if a real C++ defect exists.

## 12. Out-of-scope / not performed (explicit)

- **Native compile+run of the 200 C/C++ samples**: owned by pi w6:p4. Not run
  here; the existing `research/cpp-content-verification.json` records
  `passed: 200, failed: 0` (clang 18.1.3 / g++ 13.3.0) but that is not
  independently re-claimed by this review.
- **Staging regeneration**: not performed (read-only staging comparison only).
- **Device / build / signing**: not touched.
- **Commit**: not performed; left for serial standardized commits after root
  verification.
- **C track deep review**: only the counts/duplication/context above; the C
  semantic review and the `c-example-082` duplicate-output finding are the C
  worker's scope.

## 13. Notes left for the coordinator

1. Live core C++ rows are already merged and match staging exactly — no pending
   C++ merge.
2. `tool/forge_content/_review_probe.dart` and `_dup_output.dart` are
   pre-existing untracked read-only review helpers (not this worker's output);
   decide whether to keep or remove them before the final commit.
3. `research/cpp-content-verification.json` has a 1-line working-copy
   modification (uncommitted) predating this review; not modified by this worker.
4. C worker follow-up: `c-example-082` duplicate output string.
