# Compiler, Sysroot and Wasm Runtime Compatibility

## Observed Evidence, 2026-10-01

- Huawei's local Windows Clang does not list WebAssembly targets. Reusing that
  existing executable does not provide a Wasm compiler.
- WSL qfli-java-build has Clang 15 and 18. `clang-15 --print-targets` includes
  wasm32/wasm64, so a portable common fixture path is available after a compatible
  sysroot is obtained.
- WASI SDK 18's immutable README explicitly requires `-fno-exceptions` for C++
  and does not support setjmp/longjmp, thread creation, dynamic libraries, or
  networking. SDK 24 and 27 retain the C++ exceptions limitation.
- Current upstream CppExceptions.md says WASI SDK 33 adds exception-enabled
  sysroots, requires LLVM 22+, `-fwasm-exceptions`,
  `-mllvm -wasm-use-legacy-eh=false`, and `-lunwind`. Current main documentation
  does not itself identify a downloaded, verified immutable release artifact.
- WAMR 2.4.1 supports legacy exceptions behind WAMR_BUILD_EXCE_HANDLING. Its
  classic interpreter handles try/catch/throw/rethrow. Its configuration lists
  standard exception handling among unsupported proposals. Therefore this
  runtime cannot simply be paired with the SDK 33 standard-EH output.
- WAMR 2.4.1 exposes wasm_runtime_set_wasi_args_ex with explicit stdin, stdout,
  stderr handles and mapped/preopened directories. wasm_runtime_get_wasi_exit_code
  retrieves the program exit status.
- WAMR 2.4.1 exposes wasm_runtime_terminate for asynchronous termination by an
  embedding thread. The classic interpreter checks suspend flags on branch
  operations when WASM_ENABLE_THREAD_MGR is enabled. This gives an existing
  termination mechanism to test rather than inventing an interpreter loop.

## Consequences

A C++ Hello World with exceptions forcibly disabled would not prove the required
language behavior. Select compatible compiler, standard-library, unwinder, and
interpreter artifacts and run a real throw/catch fixture before declaring the
portable C++ backend usable. Native OS process/network/dynamic-library APIs also
need explicit platform capability reporting.

Possible runtime directions are a newer proven native engine that supports
standard exceptions, or a verified compatible legacy-EH library toolchain.
System WebKit's Wasm engine is another iOS-native execution option with existing
iOS C/C++ prior art, but its worker/I/O/termination integration needs separate
research before selection. No candidate is claimed implemented by this document.

## Sources Read

- https://raw.githubusercontent.com/WebAssembly/wasi-sdk/wasi-sdk-18/README.md
- https://raw.githubusercontent.com/WebAssembly/wasi-sdk/wasi-sdk-24/README.md
- https://raw.githubusercontent.com/WebAssembly/wasi-sdk/wasi-sdk-27/README.md
- https://raw.githubusercontent.com/WebAssembly/wasi-sdk/main/CppExceptions.md
- https://raw.githubusercontent.com/bytecodealliance/wasm-micro-runtime/WAMR-2.4.1/core/iwasm/include/wasm_export.h
- https://raw.githubusercontent.com/bytecodealliance/wasm-micro-runtime/WAMR-2.4.1/build-scripts/config_common.cmake
- https://raw.githubusercontent.com/bytecodealliance/wasm-micro-runtime/WAMR-2.4.1/core/iwasm/interpreter/wasm_interp_classic.c

Raw source reads succeeded. Git ls-remote to the WAMR repository timed out after
300 seconds and ended unsuccessfully; no dependency was downloaded or built.
All observation sessions from this research have completed.

## Follow-up Evidence, 2026-10-02

The immutable WASI SDK 33 release exists (published 2026-04-30). GitHub's release
API reports the Linux x86_64 archive:

- Name: wasi-sdk-33.0-x86_64-linux.tar.gz
- Size: 193563606 bytes
- SHA-256: 0ba8b5bfaeb2adf3f29bab5841d76cf5318ab8e1642ea195f88baba1abd47bce
- URL: https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-x86_64-linux.tar.gz

Immutable wasi-sdk-33/cmake/wasi-sdk-sysroot.cmake hardcodes
`-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` for exception-enabled
libc++/libc++abi/libunwind. A caller CXX_FLAGS override precedes those flags and
does not provide a supported legacy-EH sysroot switch. Rebuilding a compatible
legacy-EH runtime would need an explicit standalone runtime build or a recorded
source patch; merely changing application compile flags is insufficient.

LLVM llvmorg-22.1.0/libunwind/src/Unwind-wasm.c uses
`__builtin_wasm_throw(0, exception_object)` and compiler-generated landing-pad
personality calls. This establishes a potential compiler-mode boundary to
investigate, not verified WAMR compatibility.

Next technical step: obtain the pinned SDK/compiler and select an interpreter
supporting its actual exception bytecode, then execute C++ throw/catch fixtures.
Binaryen's interpreter and system WebKit are additional candidates to inspect;
no dependency is selected or declared functional from documentation alone.

## Confirmed Interpreter Pair, 2026-10-02

Selected compiler resources are the verified SDK 33 archive above, matching
LLVM 22.1.0 commit `4434dabb69916856b824f68a64b029c67175e532`. Clang emits
standard exceptions using `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false`
and the exception-enabled libc++/libc++abi/libunwind sysroot, linked with
`-lunwind`. Exceptions are enabled rather than omitted from acceptance.

WasmEdge 0.16.0 and 0.17.1 both executed initial C/mixed/stdio checks but failed
the exception fixture during a destructor: out-of-bounds stack access at
`0xa71`, address `0x6962fffc`. The same bytecode passed Node 24.15.0 WASI.
The upstream `throw_ref` payload fix alone (present in 0.17.1) was insufficient.
A speculative local engine patch also failed and was removed.

The selected unmodified WasmEdge source is commit
`845df599e7b71c98b0c77990c3aa3a10022bbaae`, which fixes stale `try_table`
handlers after branching. Archive SHA-256 is
`70c117f3c9bc22d6e3f83077167154336fd66f7f12c6373979de12d79386a197`.
Its static interpreter build disables LLVM/JIT, AOT tooling and plugins.
Dependency URLs/hashes are recorded in `native/toolchain/portable-dependencies.json`.

`native/toolchain/verify-portable-wasm.sh` passed all 15 execution checks in
WSL `qfli-java-build` using this SDK and native `qfli_wasm_probe`:

- C main/C++ stdlib helper, explicit uppercase C/CPP language modes, libm.
- input.txt, separate stderr, nonzero exits and repeated runs.
- Throw/rethrow payload, both destructors, stdlib out_of_range, repeated exceptions.
- Project preopen reads/writes, 256 MB memory limit.
- Running/pre-start cancellation, traps and instruction cost limit.
- Link diagnostics without an executable module.

Engine logging initially polluted stdout on memory growth failure. Rebuilding
the adapter with one-time `WasmEdge_LogOff` resolved this; diagnostics now use
the session error API. Caller-owned stdio descriptors remain open after teardown.

This establishes interpreter compatibility on Linux. The in-process compiler
adapter and iOS/browser integrations require separate checks; it does not
establish Apple app or browser workflow verification.

## In-Process Compiler and Lifecycle Verification

The static LLVM/Clang/LLD adapter now builds and executes the same fixture matrix
through qfli_compiler_compile, followed by the native interpreter. All 19 common
checks and four compiler lifecycle gates passed. The latter cover repeat
compilation, syntax/link error recovery, active/pre-start cancellation, output
cleanup and successful compilation within the same process after cancellation.

Two integration defects were found by real compilation:

- SDK 33's compiler has WASI-driver changes beyond the vanilla LLVM 22 source
  archive. Explicit C/C++ driver modes alone do not find its EH headers/libraries.
  Use -nostdinc++/-isystem for include/wasm32-wasip1/eh/c++/v1 and -L for the
  matching lib/wasm32-wasip1/eh directory when linking. Compile-only commands
  should not receive the unused linker search flag.
- LLD resets LLVM global command-line options after each link. One-time
  wasm-enable-eh/wasm-use-legacy-eh setup caused the second C++ compilation to
  exit with LLVM ERROR. Restore these options for every frontend execution.

The compiler links a pending file and publishes only successful noncancelled
output. Compiler and interpreter share a 256 MB module-memory limit.
Synchronous LLD cancellation is checked when linking returns; iOS Dart waits
for the actual native cleanup event rather than completing from a timeout.

Unmodified upstream polling also prevented cancellation inside nanosleep(30s).
The bounded reproduction timed out at three seconds. A tracked, SHA-checked
Linux/Apple poll patch now checks the executor stop token every 10 ms while
preserving normal deadlines. A second patch removes the static archive before
incremental merge, fixing duplicate object definitions. Hashes/application rules
are in native/portable/README.md. Both patches passed pristine-archive,
idempotence and source-drift checks. The selected engine is now upstream plus
these two explicit patches; the exception-handler fix remains upstream.

The resources-only SDK probe (share/wasi-sysroot and lib/clang/22, no bin) also
compiled mixed C/C++ and exception fixtures, matching iOS package contents.
Apple builds/channel execution remain skipped, not inferred from these probes.
