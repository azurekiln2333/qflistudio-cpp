# Verification plan — C/C++ substantive curriculum (200 pairs: 100 C + 100 C++)

Historical verification strategy, captured 2026-10-12 before implementation.
Current results are in `../implement.md` and the 2026-10-15 review reports.

---

## 0. TL;DR for the verifier

- The examples must be validated by **real native compilation and execution**, not by
  the in-app Dart interpreter. The app's own desktop path (`ClangProgramRunner`) already
  does exactly that and is reachable on this machine through a real compiler.
- **Primary modern toolchain (verified compile+run): WSL `qfli-java-build`** — host
  `clang++ 18.1.3` and `g++ 13.3.0`. C++20/C++23 examples were compiled and run (exit 0),
  including from a source on `/mnt/d/MyNewProjects/qfli_c`. This covers the advanced scope;
  see §2.7.
- **Secondary toolchain on the Windows host**: TDM-GCC 4.9.2 at
  `D:\ProgramFiles\Dev-Cpp\MinGW64\bin\{gcc,g++.exe}` (`x86_64-w64-mingw32`) — used by the
  app's own `ClangProgramRunner` for the in-app integration check. It caps at **C ≤ C11 /
  C++ ≤ C++14**, so it alone cannot represent modern scope (§2.3, §2.8).
- Android NDK clang 18/19 and the in-repo WASI clang 22 are **cross** compilers; they do
  not produce host-runnable executables and are not the native validation route (§2.7.2/3).
- Do **not** downgrade C++ or "advanced" material to the interpreter subset to make it
  pass. Advanced material is validated natively on WSL; a feature only becomes
  `standard_unavailable` when **no available toolchain** compiles it — never "device-only",
  never silently rewritten to interpreter-safe code.

---

## 1. Where the content lives and what "done" must prove

The learning content is **not** in this repo. It ships from the sibling shared package
`../qfli_studio_core` (read-only for this task):

- `assets/content/tutorials.json` (3.5 MB) — aggregate, all languages, 100 entries/type.
- `assets/content/examples.json` (1.6 MB) — aggregate, 100 entries/type.
- `assets/tutorials/c.json`, `assets/tutorials/cpp.json` — legacy per-language bundles.
- Model/parse/validate: `lib/models/tutorial.dart`,
  `lib/content/content_repository.dart`, `lib/content/content_validator.dart`.

Current state (measured): the 100 C rows in `examples.json` are **placeholder padding** —
every one matches the `weighted=%d` signature the Python generator explicitly forbids,
all 100 C bodies are 3 lines / ~161 chars, and 24 titles repeat ~4×. So the deliverable is
a *content replacement* plus a *verification harness*, and the existing count of 100 is
misleading.

The proven precedent to mirror is the Python pipeline in the same package:
`tool/python_content/python_topic.dart` (+ `python_topics*.dart`) as the single source of
truth → `tool/generate_python_content.dart` (replaces only `language=="python"` rows,
preserves other workers' rows, writes a fingerprint manifest) → `tool/verify_python_content.dart`
(cross-checks emitted rows and **actually executes** every sample, diffing stdout).
Java has the same pair (`generate_java_content.dart` / `verify_java_content.dart`).
**There is no C/C++ generator or verifier yet** — that is the gap this plan verifies.

Proving "200 substantive tutorials + paired verified examples" therefore means proving
four things, each independently:

1. **Content shape**: 200 C/C++ tutorial entries + 200 paired examples exist (100 C + 100 C++, see §0 count note / content audit), ids stable,
   fields populated, no placeholder signature, no duplicate titles/bodies, levels span
   beginner→advanced, split between C and C++ is deliberate.
2. **Cross-record identity**: tutorial lesson code/output, example code/expectedOutput and
   the legacy bundle agree byte-for-byte (the Python verifier's `_crossCheck`).
3. **Executability**: every example **compiles and runs natively** and its actual stdout
   equals `expectedOutput`, exit code as declared, stderr clean (unless the example is a
   deliberate diagnostics demo).
4. **App integration**: the same examples run through the app's real entry point
   (`RunnerService.runProject` / the active profile runner) and the tutorial/example
   records load through the real content repository + validator.

---

## 2. Genuine compiler discovery — verified evidence

**RESOLVED (2026-10-12): a modern toolchain exists and was verified compile+run.** The
earlier "only GCC 4.9.2" conclusion was incomplete — it did not probe the existing WSL
distros or the Android NDK. The compiler blocker is removed; see §2.7.

### 2.1 What was searched (all read-only)

| Probe | Result |
| --- | --- |
| `where.exe clang clang++ gcc g++ cl clang-cl cc tcc zig` | **all absent** on PATH |
| `C:\Program Files\Microsoft Visual Studio` / `(x86)` | absent |
| `C:\Program Files (x86)\Windows Kits\10\bin` | absent |
| `C:\Program Files\LLVM`, `D:\ProgramFiles\LLVM` | absent |
| `C:\msys64`, `C:\MinGW`, `C:\mingw64`, `C:\Dev-Cpp` | absent |
| WSL distros (`wsl -l -v`) | `Ubuntu`, `qfli-terminal-*`, `qfli-java-build` — all **Stopped** |
| `wsl -d Ubuntu` boot | **fails**: `WSL2 … CreateInstance/MountDisk/HCS/ERROR_FILE_NOT_FOUND` (Ubuntu 22.04 `ext4.vhdx` missing) → **WSL unusable** |
| Filesystem sweep for `clang*.exe`/`gcc.exe`/`g++.exe`/`cl.exe`/`tcc.exe`/`zig.exe` | only the Dev-Cpp pair below |

### 2.2 The one real toolchain

```
D:\ProgramFiles\Dev-Cpp\MinGW64\bin\gcc.exe   -> TDM-GCC 4.9.2 (tdm64-1), target x86_64-w64-mingw32
D:\ProgramFiles\Dev-Cpp\MinGW64\bin\g++.exe   -> TDM-GCC 4.9.2 (tdm64-1), target x86_64-w64-mingw32
```

Discovered by the app's own `ClangProgramRunner._findCompiler` because Windows discovery
includes `<rootPrefix>/ProgramFiles/Dev-Cpp/MinGW64` for the drive of the resolved
executable / project root. No env var (`QFLI_CLANG`, `QFLI_CC`, `QFLI_TOOLCHAIN_HOME`) and
no bundled `<flutter>/bin/toolchain` is present, so discovery relies on that path rule.

### 2.3 Standards actually accepted (measured by compiling a trivial TU)

| C standard | OK? | C++ standard | OK? |
| --- | --- | --- | --- |
| `c89`, `c90`, `c99`, `c11`, `gnu11` | yes | `c++98`, `c++03`, `c++11`, `c++14` | yes |
| `c17`, `c2x`, `gnu17` | **no** | `c++17`, `c++20` | **no** |

Consequence for the runner: its probe list is C `['c17','c11']` → `c17` fails, `c11`
succeeds; C++ `['c++20','c++17','c++14','c++11']` → first three fail, `c++14` succeeds.
Both fall through cleanly, so **the native desktop path is fully operational on this box**.

### 2.4 Exact verified commands

Direct CLI (proves the toolchain itself):

```powershell
# C  (runner-equivalent: -x c -std=c11 -I <project> [-I <project>/include] -c <unit> -o <obj>, then link)
& 'D:\ProgramFiles\Dev-Cpp\MinGW64\bin\gcc.exe'   -std=c11  main.c   -o program.exe ; .\program.exe
# C++ (runner-equivalent: -x c++ -std=c++14 ...)
& 'D:\ProgramFiles\Dev-Cpp\MinGW64\bin\g++.exe'   -std=c++14 main.cpp -o program.exe ; .\program.exe
```

App-level (the authoritative path; no env vars needed):

```dart
await ClangProgramRunner().run(
  projectPath: <abs project dir>,
  entryFile: path.join(<abs project dir>, 'main.c' /* or main.cpp */),
);
```

**Both were executed and observed exit 0 with correct stdout:**
- C: `runner C ok forge 42` (uses `<string.h>`), stderr empty.
- C++: `cpp ok 17 1` (`<iostream>`, `<vector>`, `<string>`, `<algorithm>`, a function
  template, `std::sort`), stderr empty.

### 2.6 WSL distro re-probe (correcting the earlier over-generalization)

The earlier note that "WSL is unusable" was inferred from `Ubuntu` failing to boot. That
inference was **wrong** for the other distros. Probed individually (read-only):

| Distro | Backing path | Boots? | Host C/C++ |
| --- | --- | --- | --- |
| `Ubuntu` | `D:\WindowsExt\Subsystem\Ubuntu\Ubuntu_2204.1.7.0_x64` | **no** — `CreateInstance/MountDisk/HCS/ERROR_FILE_NOT_FOUND` (ext4.vhdx missing) | n/a |
| `qfli-terminal-test` | `...\qflistudio\.artifacts\terminal-runtime-test\ubuntu` | boots, no user session for `root` | `command -v` found **nothing** (`clang++`/`g++`/`gcc` absent) |
| `qfli-terminal-al3-clean` | `...\terminal-runtime-test\al3-clean` | **fails** — `Failed to start the systemd user session for 'root'` | nothing returned |
| `qfli-terminal-al3-test` | `...\terminal-runtime-test\al3` | boots, no output | nothing returned |
| `qfli-java-build` | `D:\MyNewProjects\qfli_java\build\wsl\qfli-java-build` | **boots** | **clang++ 18.1.3, g++ 13.3.0** — usable (see §2.7) |

So the only usable modern WSL toolchain is `qfli-java-build`; `Ubuntu`'s failure is specific
to its missing VHD and must not be generalized again.

### 2.5 Risks about the toolchain (must be stated, not hidden)

- **R1 — Incidental, unmanaged toolchain.** Dev-Cpp exists only because it is installed on
  *this* machine. It is not pinned, not bundled, and not declared by the project. A clean
  CI/other-dev box will find **no compiler**, so every native check must **fail loudly and
  report "compiler unavailable"**, never silently pass or fall back to the interpreter.
  (Mitigated by the WSL route in §2.7, which supplies a modern toolchain already present.)
- **R2 — Dev-Cpp standards ceiling (superseded by §2.7).** The Dev-Cpp 4.9.2 toolchain alone
  caps at C11/C++14, so C17/C++17/C++20 examples cannot compile *on it*. This is no longer
  a scope limit: the WSL `qfli-java-build` clang 18 verifies C++20/C++23 by real compile+run.
  Record the Dev-Cpp limitation per-example; do **not** shrink advanced scope to fit it.
- **R3 — Windows-only discovery.** macOS/iOS/Linux use different paths
  (`verify-linux-desktop.sh`, bundled toolchain). This plan's compiler evidence is
  Windows-only; do not generalize it to other hosts.
- **R4 — Runtime DLLs.** MinGW links against its own runtime DLLs
  (`libstdc++-6.dll`, `libgcc_s_*.dll`, `libwinpthread-1.dll`). A produced `.exe` must be
  run with the linker's bin directory reachable or be statically linked; otherwise a
  "compile passed but program won't start" failure will look like a content failure. The
  runner launches the built exe from `.qfli/build/forge/`; verify the runtime-DLL path
  policy during the app-integration check.
- **R5 — `<math.h>` on Windows.** `clang_runner.dart` only appends `-lm` on Linux. On this
  Windows toolchain, libm is part of the base CRT, so math examples should link; verify
  each math example rather than assuming.

---

## 2.7 Modern toolchain — VERIFIED (compiler blocker removed)

All findings below were verified by **compiling and running real programs**, not by reading
`--version`. Scope note: each entry distinguishes a **host** compiler (produces an
 executable that runs on this machine) from a **cross** compiler (produces a target object
that cannot run on the host).

### 2.7.1 WSL `qfli-java-build` — usable modern HOST toolchain (primary recommendation)

| Fact | Value |
| --- | --- |
| Distro | `qfli-java-build` (WSL2), registered, bootable |
| BasePath | `D:\MyNewProjects\qfli_java\build\wsl\qfli-java-build` |
| Kernel | `6.6.114.1-microsoft-standard-WSL2`, 24 CPUs |
| Host clang++ | `/usr/bin/clang++` → **Ubuntu clang 18.1.3 (1ubuntu1)** |
| Host g++ | `/usr/bin/g++` → **(Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0** |
| Interop | `/mnt/d/...` readable+writable; `cmd.exe`, `powershell.exe` available |

Feature probes actually **executed** (compiled to a binary and ran, exit 0):

```
clang++ -std=c++23  -> "cpp23 ok 7 view 1"  exit 0
 g++    -std=c++23  -> "cpp23 ok 7 view 1"  exit 0
 g++    -std=c++20  -> "cpp23 ok 7 view 1"  exit 0
```
The probe uses `<optional>`, `<string_view>`, `<vector>`, `std::ranges::sort`. A second probe
compiled a C++23 source living on `/mnt/d/MyNewProjects/qfli_c` and ran it
(`wsl cpp23 from /mnt/d ok ...`, exit 0), and built+ran a C file (`mnt-d build ok`) — the
project tree under `/mnt/d` is directly compilable from inside this distro.

Standard ceilings (measured; FAIL = `unrecognized command line option` or parse error):

| Compiler | C++20 | C++23 | C++2b | C++26 |
| --- | --- | --- | --- | --- |
| `g++` 13.3 | OK | OK | OK | FAIL |
| `clang++` 18.1.3 | OK | OK | OK | OK |
| `gcc` 13.3 (C) | C11 OK, C17 OK | C23 FAIL, C2x OK | | |

### 2.7.2 Android NDK clang — modern CROSS compiler, NOT a host executor

- `D:\ProgramData\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\clang++.exe`
  → **clang 19.0.1**, `Target: x86_64-w64-windows-gnu`.
- `...\ndk\27.0.12077973\...\clang++.exe` → clang 18.0.1 (same layout).
- **Host-execution caveat (measured):** run as a *Windows host* compiler it fails at once —
  `fatal error: 'iostream' file not found` / `'stdio.h' file not found`. It ships no host
  sysroot/libc++; it is built to **cross-compile into Android**. Cross use requires
  `--target=aarch64-linux-android<api>` plus the NDK sysroot/libc++ under
  `.../prebuilt/windows-x86_64/sysroot`, and yields a **target object**, not a runnable
  desktop program.
- **Verdict:** NDK clang is **not** a validator for host example execution. Relevant only
  if a future check wants to prove Android cross-compilation of a subset — out of scope for
  "compile/run/assert stdout".

### 2.7.3 In-repo WASI/clang-22 path — modern CROSS-to-WASM compiler

- `native/compiler/compiler.cpp` drives a bundled `wasi-sdk-33.0` clang (LLVM 22) targeting
  `wasm32-unknown-wasip1` with `-std=c++20` / `-std=c17` (see §2.8). Modern front-end, but
  it emits **WASM modules executed by the bundled interpreter**, not native host
  executables. Valid *in-app* runtime, not the native validation route.

### 2.7.4 Recommendation

Use **WSL `qfli-java-build` (clang++ 18 / g++ 13)** as the native verification toolchain.
Already present (no install), modern (C++23 verified running), reads/writes the project tree
under `/mnt/d`. Raises the verifiable ceiling from "C11 / C++14" to **C17-C2x / C++20-C++23**,
covering the advanced curriculum. Dev-Cpp GCC 4.9.2 stays a *secondary* fallback only where
it compiles — never the criterion.

Concrete per-example invocation:

```
wsl -d qfli-java-build -- bash -lc \
  'cd /tmp/<work> && clang++ -std=c++23 -I <proj> <unit.cpp> -o prog && ./prog < input.txt'
```
Keep stdin/`input.txt`, stdout capture, exit code, and per-standard recording identical to
§3.2. Record the WSL distro+version behind each result.

### 2.7.5 Residual risks specific to the WSL route

- **R11 — Distro owned by another repo.** `qfli-java-build` lives under
  `D:\MyNewProjects\qfli_java\build\wsl`. Do not delete/reconfigure it; if it disappears,
  the run must hard-fail (`compiler_unavailable`), not fall back.
- **R12 — Not a host of the app.** WSL compiles+runs *examples*; it does **not** run the
  Flutter app. The in-app integration check (§4) still runs on Windows via the app's own
  `ClangProgramRunner`. The layers are complementary: WSL proves language scope; the
  Windows app path proves product wiring.
- **R13 — Path translation.** Sources compiled from `/mnt/d/...`; Windows absolute paths
  must be converted with `wslpath`. Verify the harness normalizes paths so a path bug is not
  misread as a content failure.

---

## 2.8 Runner `-std` flags vs curriculum feature requirements

Exact flags in the code today:

| Site | Flags | Target / role |
| --- | --- | --- |
| `lib/clang_runner.dart:232-234` | probe C `['c17','c11']`; C++ `['c++20','c++17','c++14','c++11']` | desktop host compiler; first that compiles wins |
| `lib/clang_runner.dart:321` | `-std=${driver.standard}` | uses the probed standard |
| `native/compiler/compiler.cpp:234` | `-std=c++20` / `-std=c17` | in-process WASI clang (LLVM 22), `wasm32-unknown-wasip1` |

The desktop **probe list already spans** C17/C11 and C++20/17/14/11. On Dev-Cpp 4.9.2 it
degrades to C11/C++14 (measured §2.3); on WSL clang 18 it resolves to **C17/C++20**
(measured §2.7.1) — no code change needed to reach C++20.

Gap analysis vs curriculum feature requirements:

| Curriculum feature | Needs | Dev-Cpp 4.9.2 | WSL clang 18 | In-app WASI clang 22 |
| --- | --- | --- | --- | --- |
| C11 basics, pointers, structs, malloc | C11 | OK | OK | OK |
| C17 basics / `_Static_assert`, `stdalign` | C17 | **no** | OK | OK (`-std=c17`) |
| C++11/14 (auto, move, lambdas, `constexpr` v1) | C++14 | OK | OK | OK |
| C++17 (`optional`, `string_view`, `if constexpr`, structured bindings) | C++17 | **no** | OK | OK (`-std=c++20`) |
| C++20 (concepts, ranges, `<=>`) | C++20 | **no** | OK | OK (`-std=c++20`) |
| C++23 (`std::ranges`, `expected`, deducing this) | C++23 | **no** | OK | partial (clang 22) |

**Conclusion:** with the WSL clang 18 route, every modern C++ feature the curriculum needs
is verifiable by actual compile+run. The Dev-Cpp path alone would force C++17/20 into
`standard_unavailable`; WSL eliminates that for those features. Do **not** reduce C++ scope
to fit GCC 4.9.2 — verify on WSL and record the Dev-Cpp limitation separately.

---

## 3. 200-example compile / run / assert strategy

> Count note (audit-driven): the release validator `ContentCatalogValidator` counts by
> `type` with `releaseMinimumPerType = 100`, so C and C++ must **each** keep ≥100 tutorial
> rows and ≥100 example rows → **100 C + 100 C++ = 200 pairs**. Where this plan says "120"
> it is superseded by 200; the run/assert procedure is per-example and count-independent.

### 3.1 Harness shape (mirror the Python precedent, keep it self-contained)

Add a generator+verifier pair for C/C++ analogous to
`generate_python_content.dart` / `verify_python_content.dart`:

- Source of truth: `tool/c_content/c_topic.dart` + authored topic lists
  (`c_topics_basics.dart`, `c_topics_core.dart`, `c_topics_advanced.dart`, plus a C++
  list or a `language` discriminator). Data-only, no `dart:io`.
- `generate_c_content.dart`: reads the **live** aggregate JSON, replaces only
  `language in {c,cpp}` rows (or `type in {c,cpp}`), preserves all other languages
  byte-for-byte, writes the legacy `assets/tutorials/{c,cpp}.json`, and records a
  non-C/C++ fingerprint manifest so the verifier can prove other workers' rows survived.
- `verify_c_content.dart`: (a) structural invariants, (b) per-row cross-check
  tutorial↔example↔legacy, (c) **native compile+run+assert per example**, (d) machine-
  readable report JSON.

Location rule: these tools belong to whichever owned repo the content split assigns;
they must **not** edit the sibling shared package unless that repo is the assigned owner.
Independent verification reads the emitted JSON and the report regardless of where tools
live, and re-runs execution for a non-overlapping sample.

### 3.2 Per-example assert loop

For each example row:

1. Create a fresh temp project dir.
2. Write the example's code as `main.c` or `main.cpp` per its language.
3. Write `input.txt` from the fixture when present.
4. Compile **natively** with the runner-equivalent flags:
   `-x c|c++ -std=<chosen> -I <proj> [-I <proj>/include]`, then link; capture
   compiler stderr separately.
5. If the example is not a deliberate diagnostics demo: require compile exit 0.
6. Run the produced program with `input.txt` on stdin and a wall-clock timeout
   (default 10 s, matching production), capture stdout/stderr/exit code.
7. **Assert**: normalized stdout == `expectedOutput`, exit code == declared/0,
   stderr empty (except designated diagnostics examples).
8. Record id, standard used, result, and any mismatch diff in the report.

Normalization (must match the Python verifier): `\r\n → \n`, `trimRight` on both sides;
decide once whether a trailing newline is significant and apply it uniformly.

Determinism requirements for authored examples (these are *content* constraints the
verifier enforces, not optional style):

- No `rand()`/time/PID/pointer-address/env-dependent output unless `srand` is fixed AND
  the value is not printed; forbid printing raw `rand()` without a fixed seed.
- No printing of `sizeof`-of-unknown or addresses; no uninitialized reads.
- `<math.h>` outputs printed with fixed precision (e.g. `%.4f`) so FP formatting is stable.
- `<float.h>`-dependent formatting must be deterministic across the toolchain.
- File I/O examples read/write only `input.txt` or files they create; no absolute paths,
  no network, no `system()`, no `exit` without deterministic code.
- Timeout-sensitive loops stay small (the interpreter's 10 s wall clock is the production
  limit; keep native examples comfortably within it).

### 3.3 Standards policy (do not shrink scope)

- **C** examples: target **C11** (compiles on this toolchain). Author to C11 + a note;
  do not author C17-only features into runnable C examples.
- **C++** examples: target **C++14** (compiles here). A `-std=c++11`-only example is fine
  too. **C++17/C++20 features are allowed as curriculum topics** but the runnable paired
  example must either (a) use a form the verifier can compile, or (b) be explicitly listed
  in the report as a **`standard_unavailable`** result with the feature named — never
  reclassified as interpreter-only or device-only.
- Record, per example, the `-std` that was used to verify it, so the ceiling is auditable.
- Advanced material (pointers/recursion/dynamic memory/structs/unions/bitops/preprocessor/
  function pointers/file I/O/C++ RAII/templates/STL/operators/exceptions) is verified
  natively. Only features the toolchain cannot compile become `standard_unavailable`.

### 3.4 Fixtures

- **stdin**: reuse the production convention — a project-root `input.txt` fed to the
  program (this is what both `clang_runner.dart` and `c_runner.dart` do). The example row's
  `inputFixtures` (`{'stdin': '...'}`) is the single source the verifier writes to
  `input.txt`. `inputFixtures` with a `stdin` value is required whenever the example reads
  input, and `expectedOutput` must match exactly.
- **multi-file**: when an example teaches multi-TU, the row needs a file map; if the current
  example schema cannot express extra files, verify whether the generator must extend the
  schema or whether multi-file teaching is demonstrated via `#include "helper.h"` within a
  single row. Decide this before authoring; the verifier must handle whichever is chosen.
- **headers**: `#include "utils.h"` resolves project-locally in both backends; the native
  path adds `-I <project>` and `-I <project>/include`. Verify at least one header-including
  example end-to-end natively.

### 3.5 Acceptance for the execution gate

- 200/200 examples (100 C + 100 C++) have a recorded result; zero `mismatch` (stdout/exit/stderr) outcomes.
- `standard_unavailable` (if any) is an explicit, enumerated, named list — an accepted
  exception only if the PRD allows it, and never counted as a pass.
- `compiler_unavailable` is a hard failure of the check environment, not a content verdict.
- The report is machine-readable and diffable (like `python-content-verification.json`).

---

## 4. App integration acceptance (separate from content correctness)

Content can be "correct JSON" and still not run in the product. Prove all of:

1. **Repository load**: the real `AssetContentRepository`/`ContentCatalog.fromJson` parses
   the replaced aggregates without throwing; `ContentFilter.forProduct('forge')` (types
   `{c,cpp}`) returns the 200 tutorials + 200 examples (100 C + 100 C++).
2. **Release validator**: `ContentCatalogValidator.validateForRelease(catalog)` is clean
   for `c` and `cpp` (the `releaseMinimumPerType = 100` gate is already satisfied at 100,
   but the substantive replacement must not regress required fields: id/language/type/
   locale/level/title/summary/source/license/updatedAt/concepts non-empty; unique ids;
   non-empty lessons with id/title/summary/explain/code/output/concepts).
3. **Real runner path**: for a representative, non-overlapping sample (the independent
   check's own sample, distinct from the author's), create a project from the example and
   call `RunnerService.runProject(projectPath, entryFile)` with the active profile
   (`forgeProfile` / `cProfile`), i.e. `ForgeProgramRunner` → `ClangProgramRunner` first.
   Assert stdout matches and stderr is empty — proving the *app's* path, not just a CLI.
4. **Legacy + tutorial UI data**: `assets/tutorials/c.json` parses via `Tutorial` model
   (`runtime`, `chapters`, `lessons`), `lessonCount` matches, and at least one lesson's
   `code` equals its example's `code`.
5. **Header/entry guards unaffected**: a header entry still fails with not-run status;
   an out-of-project entry still fails (these are existing contracts in
   `source-selection.md` / `desktop-runtime.md` and must not regress).
6. **No routing change**: `forgeProfile.runtimeStatus` and the existing fallback policy
   are untouched by content work.

### 4.1 Current app-integration baseline (measured, pre-change)

| Suite | Tests | Result |
| --- | --- | --- |
| `test/android_clang_runner_test.dart` | 15 | pass |
| `test/android_startup_test.dart` | 4 | pass |
| `test/c_app_test.dart` | 29 | pass |
| `test/clang_runner_test.dart` (real desktop compile/run) | 18 | pass |
| `test/forge_tools_test.dart` | 9 | pass |
| `test/native_clang_runner_test.dart` | 6 | pass |
| `test/run_title_test.dart` | 8 | pass |
| `test/source_selection_test.dart` | 52 | pass |
| **`flutter test` total** | **141** | **all pass** |
| `flutter test packages/qfli_c_runtime/test/c_runtime_test.dart` | 73 | pass (interpreter; informational) |

`flutter analyze lib test` → **21 pre-existing issues**, all in the browser/web port
(`lib/web_clang_runner_browser.dart`, `native/web/tests/web_runner_browser_test.dart`,
undefined `studioFile`/`studioDirectory`/`File`/`Directory` under stub conditional
imports). Full `flutter analyze` → 4127 issues (includes generated/vendor). **These are
pre-existing and out of scope**; the verifier must not attribute them to this task, but
must confirm the content work introduces **no new** analyze errors.

Acceptance for integration: 141/141 still pass, no new analyze errors in `lib/ test/`,
and the representative native `RunnerService` sample passes.

---

## 5. Independent-check protocol (non-overlapping)

Per the workflow, the implementer authors content and the generator/verifier; the
independent check must not merely re-run the author's harness.

- **Sample non-overlap**: pick an independent sample (e.g. every Nth example, or a level/
  category stratum) chosen before seeing results, and run it through the *app* runner and
  a *direct* CLI compile separately. Compare to the author's report.
- **Re-derive the compiler fact**: re-run `where.exe` + the standards matrix + the
  app-level `ClangProgramRunner` probe; require the compile evidence to reproduce
  (guards against a machine where no compiler exists — R1).
- **Adversarial content checks**: scan for the exact placeholder signatures the old rows
  used (`weighted=`, one-line bodies, repeated titles), for non-determinism sources
  (`rand` without seed, addresses, unbounded loops), and for `expectedOutput` that was
  copied from actual output rather than the other way around (spot-check by perturbing).
- **Boundary checks**: an example with stdin, one with `#include "…h"`, one multi-TU (if
  supported), one C++ STL example, one deliberate-compile-error example, and one that
  should land in `standard_unavailable`.
- **Report**: record the independent sample, commands, observed vs expected, and any
  discrepancy with the author's report. Discrepancy → back to planning/implement, not a
  silent fix.

---

## 6. Open questions to settle before implementation (hand to planning owner)

1. Language split: confirmed by audit as **100 C + 100 C++ (200 total)**; remaining question is how many per level within each language.
2. Multi-file example support: does the example schema carry extra files, or is multi-TU
   taught via `#include` in a single row? (Affects fixtures + verifier.)
3. Where the generator/verifier tools live: this repo's `tool/`, or the sibling shared
   package (which is out of scope for writes here)? Independent verification needs the
   answer to locate the report.
4. Is `standard_unavailable` an acceptable accepted-exception class in the PRD, and what
   is the maximum allowed count?
5. Chinese vs English authoring for `explain`/`objective`/`pitfalls` (current assets are
   `zh-CN`; Python curriculum is Chinese).
6. Legacy bundle treatment: keep `assets/tutorials/c.json`/`cpp.json` in sync, or migrate
   to aggregate-only? (The Python pipeline keeps both.)

---

## 7. Risk register (verification-relevant)

| ID | Risk | Impact | Mitigation in checks |
| --- | --- | --- | --- |
| R1 | No compiler on the checking machine | False "unverified", or worse, silent interpreter fallback | Hard-fail with "compiler unavailable"; re-derive §2 evidence (WSL `qfli-java-build` preferred) |
| R2 | Dev-Cpp alone caps at C11 / C++14 (superseded by §2.7) | Advanced lesson examples can't compile **there** | Verify modern scope on WSL clang 18; enumerate `standard_unavailable` only for features no available toolchain compiles; never shrink scope |
| R3 | Windows-only compiler evidence | Over-claims cross-platform | Scope claims to Windows host; note Linux/macOS separate paths |
| R4 | MinGW runtime DLLs at run time | Compile-pass/run-fail misread as content bug | Verify DLL path / static link in the sample |
| R5 | `-lm` not added on Windows | Math examples fail to link | Explicitly compile+run the math examples |
| R6 | Aggregate JSON shared with other workers | Generator clobbers other languages | Fingerprint manifest + byte-diff of non-C/C++ rows |
| R7 | Placeholder rows re-introduced | "100" count masks fake content | Forbid `weighted=` signature, duplicate bodies/titles, one-line bodies |
| R8 | `expectedOutput` copied from run output | Assertions become tautological | Independent re-run on a perturbed/again-compiled sample |
| R9 | Pre-existing analyzer errors blamed on task | Noise, wrong verdict | Record the 21 baseline issues; require no *new* errors |
| R10 | 10 s time / output cap in production | Long examples pass natively but not in-app | Keep examples light; test through the app runner too |

---

## 8. Cross-reference: one contradiction to resolve with the planning owner

`design.md` §2 (verifier contract, item 2) currently says:

> Compile+run every sample with the available real desktop compiler … **or the in-app
> interpreter for C when no compiler is present**, and diff stdout against `expectedOutput`.

That fallback is **rejected by this plan** and re-asserts the stale claim already
corrected in this task's audit. Reasons:

- The interpreter is a *different language subset* than the native compiler. A C example
  that only passes on the interpreter proves nothing about whether it compiles as C, and
  a C++ example cannot be interpreter-checked at all. Falling back silently would turn a
  missing toolchain into a false pass — exactly risk **R1**.
- "No compiler present" is not a content verdict. Per §3.5, it must be a **hard failure of
  the check environment** (`compiler_unavailable`), surfaced loudly, never downgraded.
- The interpreter may still be exercised *in addition* as the in-app runtime smoke test
  (§4.3), but it must never be the criterion that makes an example count as verified.

Recommend the planning owner either delete that clause or restate it as: "if the native
compiler is unavailable, the verification run fails with `compiler_unavailable`; the
interpreter is used only for the separate in-app runtime smoke check."

Also update the planning artifacts for the toolchain decision (§2.7): the native verifier
should target **WSL `qfli-java-build` clang 18 / g++ 13** for advanced scope (C++20/23
verified), with the Windows Dev-Cpp path used only for the in-app `ClangProgramRunner`
integration check. No code change is required to reach C++20 on the desktop probe list.

---
