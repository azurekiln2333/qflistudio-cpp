# Integration Review — C/C++ Substantive Curriculum

Reviewer: C-side worker (trellis-check) for the C++ track and the integration.
Date: 2026-10-12. Scope: read-only review of peer-owned files; the model,
aggregator, generator, C track, spec, patch builder and integration test are
edited by this worker.

## Canonical validation (reproducible)

```sh
cd qfli_c
dart run tool/verify_forge_content.dart          # authoritative: 200/200 + probes
dart run tool/forge_content/negative_probe.dart  # 10/10 failure + isolation probes
dart run tool/generate_forge_content.dart        # regenerate staged rows
flutter test                                     # 174/174
```

- `tool/verify_forge_content.dart`: **200 passed, 0 failed of 200** (100 C +
  100 C++), via WSL `qfli-java-build` clang++ 18.1.3 / g++ 13.3.0. It now asserts
  compile success AND exit code AND byte-exact stdout AND empty stderr AND
  non-timeout, enforces the standard ceiling (C <= c17, C++ <= c++20), and
  distinguishes `timeout` from `compiler_unavailable`.
- `tool/forge_content/negative_probe.dart`: **10/10** including a relative-file
  write isolation probe (program succeeds but writes nothing into the repo cwd).
- `flutter test`: **174 passed** (12 integration + 20 pipeline + existing).
- Targeted `dart analyze` of all canonical task tools + tests: **No issues**.

## Live shared-core equality (post apply)

The coordinator applied the scoped merge. Verified against
`../qfli_studio_core/assets/content/{tutorials,examples}.json`:

- Live C/C++ rows: **100 C + 100 C++ tutorials** and **100 C + 100 C++ examples**
  (200 each). Row ids equal the staged source; **0 rows differ in content**
  across all 400 rows (byte-identical per-row JSON).
- No placeholder: **0** C/C++ rows contain the old `weighted=` signature;
  **100** distinct `explain` per language.
- Foreign rows preserved: 14 foreign languages / 1420 rows present in each file.
  (Live foreign count grew from the pre-merge index because other language
  writers also landed rows concurrently; this task's merge replaced only its own
  rows.)
- Live `updatedAt` reflects the merge cycle; the merge script preserves metadata
  by policy and its dry run / pipeline test assert no clobber.

## C++ content quality (advanced spot-check)

- `std::thread`: threads write distinct indices, `join` before summing →
  race-free, deterministic.
- `std::atomic`: `relaxed` used correctly for independent increments; lesson
  warns relaxed is not synchronization.
- Data race lesson: establishes happens-before via `join`; correctly labeled.
- Exception safety: copy-and-swap strong guarantee; correct.
- Coverage present: type_traits, variadic/fold, concepts, requires, perfect
  forwarding, value categories, SFINAE, CRTP, policy, type erasure, allocators,
  span, ranges, `<=>`, threads, mutex/condvar, atomics/memory model, exception
  safety, noexcept, benchmarking, constexpr, capstone.

## Findings (all resolved and verified)

- F1 merge in-place ordering — RESOLVED.
- F2 strict language-only ownership — RESOLVED.
- F3 public CLI path (`tool/verify_forge_content.dart`, `tool/merge_forge_content.dart`,
  `tool/generate_forge_content.dart`) — RESOLVED.
- F4 extension selection (`type` -> `main.cpp`) — confirmed.
- Isolation: the earlier repo-root strays (`demo.txt`, `data.bin`, `sample.txt`)
  were produced by a scratch checker running samples in the repo cwd. Verified
  content + path, removed only those three. The official verifier runs each
  sample in a WSL `mktemp -d` with `cd "$work"` and a cleanup trap, and leaves no
  repo-root files; a formal isolation probe now guards this.

## Verdict

**Ready-to-merge gate: PASS.** Content is native-verified, the live core equals
the authored source for C/C++, foreign rows are preserved, and the pipeline is
guarded by failure/isolation probes. No commit/archive performed (main owns
finish). Baseline `web_clang_runner_browser.dart` analyzer issues remain
separate and unrelated.
