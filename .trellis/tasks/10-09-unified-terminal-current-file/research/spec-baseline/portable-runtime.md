# Portable C/C++ Runtime Contract

## 1. Scope / Trigger

Applies to native/compiler/, native/portable/, lib/native_clang_runner.dart,
ios/Runner/NativeCompilerBridge.mm and portable toolchain build/verification.
The compiler emits WASI data; the signed native interpreter executes it. Do not
load generated native machine code or enable JIT on ordinary iOS.

## 2. Signatures

- qfli_compiler_compile(session, sdk_root, project_path, output_directory,
  sources, source_count, diagnostic_fd): absolute paths, borrowed diagnostic FD.
- qfli_wasm_run(session, module_path, project_path, input_fd, output_fd,
  error_fd, cost_limit): borrowed independent descriptors, project preopen.
- Both opaque sessions expose create/cancel/destroy. Each session is used once;
  destroy only after run/compile and concurrent cancellation have returned.
- iOS uses Android's qfli_forge/native start/cancel and native/events protocol;
  start returns available, events include runId, kind and text/exitCode.

```sh
COMPILER_PROBE="$PWD/native/build/compiler-linux/qfli_compiler_probe" \
  bash native/toolchain/verify-portable-wasm.sh
bash native/toolchain/build-ios-portable.sh --jobs 2
```

## 3. Contracts

- Dependencies are pinned in native/toolchain/portable-dependencies.json:
  LLVM 22.1.0, WASI SDK 33 and WasmEdge 845df599. Older WasmEdge 0.16/0.17.1
  failed the real standard-exception destructor fixture.
- Runtime source includes the SHA-checked interruptible-poll and static-archive
  patches under native/portable/patches/. Apply before CMake configuration and
  recording source digests, including explicit FetchContent source overrides.
  Reapplication is idempotent; mismatched source or patch bytes fail. Patchfiles
  require LF checkout bytes. Incremental archive merging first removes its output.
- Use explicit C/C++ driver modes, C17/C++20 and separate translation units.
  SDK 33 EH headers live in include/wasm32-wasip1/eh/c++/v1; add them with
  -nostdinc++/-isystem. Link from lib/wasm32-wasip1/eh with -lunwind and -lm.
  Vanilla LLVM 22's driver does not discover this newer SDK layout itself.
- Restore LLVM backend options before EVERY frontend execution:
  ResetAllOptionOccurrences, then wasm-enable-eh and wasm-use-legacy-eh=false.
  LLD resets these globals after linking. Initializing them once breaks the
  second C++ compile in an application process. Serialize compiler/LLD state.
- Link to program.pending.wasm and publish program.wasm only after success
  and cancellation checks. Remove pending/final output on accepted failure or
  cancellation; do not run stale modules.
- Native linear-memory pages and compiler module maximum share
  native/include/qfli_wasm_limits.h (256 MB). WasmEdge forces interpreter mode;
  optional cost_limit bounds bytecode instruction cost.
- Preserve borrowed stdio and app cwd. Suppress engine process-global logging;
  return engine diagnostics through the session error API.
- WASI poll/sleep checks the invoking executor stop token every 10 ms on
  Linux/Apple, retains timer deadlines, and releases its poller on interruption.
  Inputs are finite files; output pipes must be drained concurrently.
- Compiler cancellation checks preprocessing tokens and LLVM yield points.
  Synchronous LLD cancellation is observed when its current link call returns.
  iOS Dart cancellation waits for the actual exit/cleanup event. Android retains
  its existing five-second exit timeout via its wrapper.
- iOS permits one active run and requires a listener. Exit follows native
  session destruction, pipe drain and temporary-file removal. Missing bundle
  resources report unavailable; the iOS runner does not silently fall back.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| SDK/source/patch mismatch | Fail with diagnostics; preserve unrelated edits |
| Compile/link failure | Nonzero status, no published program, no fallback |
| Normal program exit | Preserve program stdout/stderr and actual status |
| Wasm trap or cost limit | Status 125 with separate diagnostics |
| Accepted cancellation | Status 130 after cleanup; next run remains usable |
| Missing iOS bundle or disabled package | available:false, explicit unavailable result |
| Another iOS run active | runner_busy without replacing its sessions |
| Unsupported Apple test host | Record skipped build/runtime; no availability claim |

## 5. Good / Base / Bad Cases

- Good: actual in-process compile and native interpretation, C++ exceptions,
  errors/cancellation followed by successful compilation in the same process.
- Base: Linux common adapters pass, iOS channels/package source is implemented;
  Apple compilation and app execution remain explicitly unverified.
- Bad: disable exceptions or infer iOS app verification from a Linux probe.

## 6. Tests Required

- Nineteen common execution gates: mixed C/C++, uppercase suffixes, runtime
  math/input, stderr, exit 7, repeat runs, rethrow/destructors/stdlib exception,
  files, memory bound, traps/cost, CPU/sleep cancellation and normal deadlines.
- Compiler lifecycle gates: repeat, link/syntax error recovery, pre-start and
  active cancellation cleanup/recovery in ONE process, no pending/stale module.
- A resources-only SDK without bin must compile mixed and exception fixtures.
- Channel tests preserve early events, blank lines, run filtering, failures,
  cancellation, and iOS cleanup waits longer than the Android timeout.
- Bash/PowerShell syntax, patch clean/repeated application and drift rejection.
  Xcode compilation, signing and actual iOS channel runs remain separate gates.

## 7. Wrong vs Correct

Wrong: initialize LLVM exception options only at process startup. Correct:
restore them before each frontend, including after an LLD error or cancellation.

Wrong: complete iOS cancellation from a timer while the compiler still owns
resources. Correct: wait for native cleanup and the drained terminal event.
