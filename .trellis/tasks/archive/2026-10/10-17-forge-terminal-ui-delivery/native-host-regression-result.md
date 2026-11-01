# Native host regression — 2026-10-17

Result: PASS, process exit code 0.

Executed the actual current compiler adapter, WasmEdge runtime adapter and OHOS
portable NAPI bridge through Node NAPI. No production sources were modified by
this verification task.

Environment:

- WSL distribution: `qfli-terminal-test`, Ubuntu 24.04.4 LTS, x86_64.
- Installed only in that task distribution: `clang-18`, `lld-18`, `nodejs`,
  `libnode-dev` using apt. Existing default Ubuntu was not used or changed.
- Reused all existing host static libraries from `native/build/compiler-linux`
  and `native/build/portable-linux-eh` and SDK resources from
  `native/build/portable-deps/wasi-sdk-33.0-x86_64-linux`.

Command:

```sh
cd /mnt/d/MyNewProjects/qfli_c
TMPDIR=/var/tmp QFLI_KEEP_TEST_BUILD=1 python3 native/toolchain/tests/ohos-portable-bridge-regression.py > native/build/forge-terminal-host-regression-boundaries-20261017.log 2>&1
```

Evidence:

- Initial log: `native/build/forge-terminal-host-regression-20261017.log`.
- Final log including extra boundary cases:
  `native/build/forge-terminal-host-regression-boundaries-20261017.log`.
- Retained generated objects, the 114 MB NAPI addon and fixtures:
  `qfli-terminal-test:/var/tmp/qfli-ohos-portable-w6ts9wrx`.
- All previous 31 actual compiler/interpreter runs passed, including mixed C/C++,
  C++ exception handling, SjLj, threads, atomics, memory.grow, UTF-8 stream tails,
  compiler/runtime diagnostics and repeated cancel/destroy/GC recovery.
- New terminal checks passed: Clang version/help; C17 and C++20 compile/run;
  C++ exceptions; object-only compilation and linking; quoted filenames and
  arguments; macros; nested working directories; diagnostics; cancellation and
  recovery; canonical project path confinement.
- Additional persisted boundary cases passed: `clang -E preprocess.c` without
  `-o` returns actual macro-expanded source through stdout; `clang++ -std=c++20`
  compiles a `.c` file containing `std::vector` as C++ and runs it successfully.

This verifies real host execution of the portable native implementation.
Signed ARM64 HAP build, installation and device acceptance remain the parent
task's separate deliverables.
