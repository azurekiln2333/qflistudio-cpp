# Design: C/C++ substantive curriculum

## 1. Architecture and boundaries

Mirror the core's proven Java/Python pipeline, but keep the authored source,
generator, and verifier under `D:/MyNewProjects/qfli_c`. The generator emits
C/C++ rows, and (only after external-write approval) performs a scoped merge of
those two row sets into the shared core's aggregate assets.

```
qfli_c/tool/forge_content/
  forge_topic.dart              # topic + exercise model (data only, no dart:io)
  c_topics_beginner.dart        # ~34 authored C topics
  c_topics_intermediate.dart    # ~41
  c_topics_advanced.dart        # ~25
  cpp_topics_beginner.dart      # ~34 C++ topics
  cpp_topics_intermediate.dart  # ~41
  cpp_topics_advanced.dart      # ~25
  forge_topics.dart             # aggregates the six lists (100 + 100)
qfli_c/tool/generate_forge_content.dart  # emits + stages C/C++ rows, scoped merge
qfli_c/tool/verify_forge_content.dart    # cross-check + native-compiler execution
qfli_c/assets/content/forge_tutorials.json   # staged C/C++ tutorial rows
qfli_c/assets/content/forge_examples.json    # staged C/C++ example rows
qfli_c/assets/content/.last_run.json         # foreign-language fingerprints
```

The topic model is a direct analogue of `tool/python_content/python_topic.dart`
and `tool/java_content/java_topic.dart`: `id`, `level`, `title`, `summary`,
`concepts`, `objective`, `explain`, `code`, `output`, `pitfalls`,
`prerequisites`, `input`, `tasks`, `standard` (the per-sample standard actually
used to compile the paired example, e.g. `c11` / `c++14` on the current
toolchain), and `runtime` (`native`). No `dart:io` in the model or topic files.

## 2. Data flow

Author (topic .dart) -> generator -> staged C/C++ rows -> verifier (native
compiler execution) -> coordinated scoped merge into core aggregate `entries` ->
app repository -> Tutorial/Examples tabs -> lesson/example detail -> run path ->
compare stdout to `expectedOutput`.

### Generator contract (from `generate_java_content.dart` / `generate_python_content.dart`)

1. **Read the live core aggregate files each run** — never restore from backup.
2. Record a fingerprint of every non-C/C++ tutorial and example row exactly as
   observed (guards against clobbering parallel language writers).
3. Replace only `language in {c, cpp}` (and matching `type`) rows with the
   generated rows; preserve all other rows, ordering, and top-level metadata.
4. Update `updatedAt` and the C/C++ rows only.
5. When merging to the shared core: the shared aggregate files are written by
   other agents, so atomic rename + a precheck alone is **not** sufficient.
   Require a **coordinated/serialized** merge window (or an exclusive lock
   agreed with the coordinator) plus a **freshness check** immediately before
   the write: re-read the current file, verify the foreign-language fingerprints
   recorded at read time are unchanged, and **back up only the owned C/C++ rows**
   (the previous C/C++ block) for rollback. If foreign fingerprints moved, abort
   and re-run the read-check-merge cycle. Never restore from a whole-file backup,
   which would clobber concurrent writers.
6. Write `.last_run.json` recording observed foreign fingerprints and the
   C/C++ row digests so the verifier can prove isolation and rollback can restore
   only the owned rows.

### Verifier contract (native-first)

1. Cross-check every authored topic against its emitted tutorial and example
   rows (and staged artifacts); fail on any mismatch.
2. **Compile and run every sample with the real native desktop compiler** using
   the same toolchain discovery as `lib/clang_runner.dart` /
   `test/clang_runner_test.dart` (clang/gcc), diff stdout against
   `expectedOutput`, and diff stdin-driven samples using the topic `input`
   fixtures. This is the primary and only criterion that makes an example count
   as verified.
3. **If the native compiler is unavailable the run must fail with
   `compiler_unavailable`** — a hard failure of the check environment, never a
   silent pass and never a downgrade to the interpreter. The in-app
   `CProgramRunner` interpreter is exercised only as a separate in-app runtime
   smoke check; it never makes an example count as verified.
4. The **standard used to compile each sample is chosen per sample** to match
   the runner actually used, and the exact `-std` is recorded per example so the
   ceiling is auditable. The confirmed native verification toolchain is the
   **`qfli-java-build` WSL2 distro** (host `clang++` 18.1.3 / `g++` 13.3.0;
   compile+run verified through C++23 and C17/C2x), reading the project tree via
   `/mnt/d`. The Windows TDM-GCC 4.9.2 (C11 / C++14) is a secondary fallback only.
   Android NDK clang and the in-repo WASI clang 22 are **cross** compilers and are
   not host-example validators. Advanced C++ (C++17/20/23) is verified by real
   WSL clang compile+run, never degraded to the interpreter subset. Only a feature
   that **no available toolchain can compile** is recorded as an explicit
   `standard_unavailable` result with the feature named — never reclassified as
   interpreter-only or device-only.
5. Assert >= 100 C and >= 100 C++ tutorial rows (and the same for examples),
   balanced levels, zero duplicate
   `explain`/`summary`/first-exercise strings per language, and distinct
   C vs C++ concept coverage.
6. Re-confirm foreign fingerprints are unchanged.
7. Report explicit pass/fail counts and any unavailable execution environments
   (`compiler_unavailable`, `standard_unavailable`) rather than claiming success.
   `standard_unavailable` is an explicit enumerated exception, never counted as a
   pass. The verifier records the WSL distro + compiler version behind each result.

Residual risks (from the reviewer's evidence): the `qfli-java-build` distro is
`qfli_java`-owned — never delete/reconfigure it, and hard-fail
(`compiler_unavailable`) if it disappears; Windows absolute paths must be
converted with `wslpath` so a path bug is not misread as a content failure. The
in-app integration check still runs on Windows via the app's own
`ClangProgramRunner` (WSL does not run the Flutter app): WSL proves language scope,
the Windows app path proves product wiring.

## 3. Integration (approach A, no new core hook)

- Authored topics, generator, and verifier stay in `qfli_c`.
- The generator stages the C/C++ replacement rows locally.
- The **only** shared-core change is replacing the C/C++ rows in
  `qfli_studio_core/assets/content/tutorials.json` and
  `qfli_studio_core/assets/content/examples.json`.
- That merge is coordinated/serialized, read-current, scoped with a freshness
  check, and guarded by foreign-language fingerprints; rollback restores only the
  owned C/C++ rows. It happens only as the known coordinator `exec_command
  require_escalated` external-write step, not as a product decision.
- No `StudioProfile` hook, no repository change, no navigation change, no other
  core file touched.

Trade-off: the merge must be coordinated with the other agents writing those two
files. The serialized window + freshness check + own-row backup is the mitigation;
never a whole-file restore.

## 4. 200-topic curriculum outline (balanced C/C++)

100 C + 100 C++ = 200 pairs. Levels per language: 34 beginner + 41 intermediate
+ 25 advanced (the generator can rebalance as long as each level is non-trivial
and each language reaches 100). Each bullet below expands to one topic = one
tutorial row + one example row + >= 1 exercise. Titles must be specific and
non-templated; `explain` must be unique prose per topic.

### C (100)

- Beginner (34): hello/printf; variables & types; format specifiers; arithmetic
  & integer division; modulo; operator precedence; type conversions; char;
  booleans via int; if/else; else-if chains; switch; for; while; do-while;
  break/continue; nested loops; pattern printing; functions & prototypes;
  parameters/return; scope & lifetime; arrays; array traversal; min/max/avg;
  strings (char[]); string.h basics; scanf/input.txt; getchar/putchar;
  const & #define; comments & style; printf debugging; compiling & linking;
  headers & multi-file basics; mini-capstone.
- Intermediate (41): pointers basics; & and *; pointer arithmetic; arrays vs
  pointers; passing pointers; swap by pointer; string.h (strlen/strcpy/strcmp/
  strcat/strtok); structs; struct arrays; nested structs; typedef; enum; unions;
  bitfields; function pointers; callbacks; malloc/free; calloc/realloc;
  dynamic arrays; memory hygiene; 2D arrays; dynamic 2D arrays; recursion;
  factorial/fibonacci; tail recursion; bubble/insertion sort; selection sort;
  merge sort; quicksort (qsort); binary search; linked list; doubly linked list;
  stack (array); stack (linked); queue (array); circular queue; hash table
  basics; file I/O (text); file I/O (binary); errno & error handling; mini-capstone.
- Advanced (25): opaque pointers/handles; callback APIs & vtable structs; arena
  allocators; alignment & padding; flexible array members; varargs;
  setjmp/longjmp; signal handling; time & clock; select/poll readiness;
  pthreads basics; mutexes & condition variables; atomics & memory orders;
  lock-free counter; generic containers with void*; intrusive lists; ring
  buffer; string interning; hashing (FNV/djb2); tokenizer; CSV parser; INI/JSON
  mini-parser; big-integer arithmetic; benchmark harness; capstone project.

### C++ (100)

- Beginner (34): iostream hello; variables & references vs values; auto;
  type deduction & literals; std::string; string operations; std::vector;
  vector algorithms; range-for; functions & overloads; default arguments;
  namespaces; const & constexpr; const-correctness intro; if/switch/loops;
  structured bindings; std::array; std::pair; std::tuple; enum class;
  exceptions intro; try/catch; compiling & linking; headers & inline;
  ODR basics; clang-format style; I/O with cin; file streams intro;
  std::optional intro; std::string_view intro; algorithms intro (sort/find);
  lambdas intro; ranges intro; mini-capstone.
- Intermediate (41): classes & encapsulation; constructors; member-init lists;
  destructors & RAII; copy semantics; move semantics; rule of three/five/zero;
  operator overloading; operator<< / >>; inheritance; virtual dispatch;
  abstract classes/interfaces; virtual destructors; smart pointers (unique);
  smart pointers (shared/weak); STL algorithms (transform/reduce); predicates &
  functors; lambdas & captures; std::function; templates basics; function
  templates; class templates; template specialization; iterators; iterator
  categories; std::map; std::unordered_map; std::set/unordered_set; std::deque;
  std::list; std::stack/queue; std::optional/variant; stringstream &
  formatting; error handling with std::error_code; const-correctness;
  static_cast/dynamic_cast; const_cast/reinterpret_cast; friend; unit-testing
  with asserts; mini-capstone.
- Advanced (25): template metaprogramming basics; type traits; variadic
  templates & fold expressions; concepts (C++20); requires-clauses; perfect
  forwarding; value categories; SFINAE vs concepts; CRTP; policy-based design;
  type erasure; custom allocators; allocator-aware containers; std::span &
  contiguous ranges; ranges pipelines (C++20); coroutines intro; std::thread;
  std::mutex/condition_variable; std::atomic & ordering; memory model; exception
  safety guarantees; noexcept & move traits; compile-time computation; profiling
  & benchmarking; capstone project.

## 5. Compatibility and migration

- Keep the exact aggregate `entries` schema so no core parser change is needed.
- Do not touch Java/Python/other rows or top-level metadata; prove via the
  fingerprint manifest and the coordinated freshness re-check.
- Keep each language at >= 100 tutorial rows and >= 100 example rows to satisfy
  `ContentCatalogValidator.releaseMinimumPerType`.

## 6. Operational / rollback

- All generated JSON is reproducible from the authored `tool/forge_content/`
  sources; rollback after a live merge restores **only the owned C/C++ rows** from
  the pre-merge backup of those rows, after a live-merge review. Never restore the
  whole asset file from a backup, which would clobber concurrent writers.
- Verifier is the gate: the scoped merge is not requested until the verifier
  passes with native-compiler execution.
- Before any shared-core write, re-read the current file and abort on any
  foreign-fingerprint change (parallel-writer safety).
