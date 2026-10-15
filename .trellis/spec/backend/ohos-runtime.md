# OHOS LLVM / WASI Runtime Contract

## 1. Scope / Trigger

Applies to `package-ohos-portable.ps1`, `build-ohos-portable.sh`,
`qfli_ohos_portable.cpp`, `QfliCNative.ets`, the native module declarations,
`EntryAbility` registration and the OHOS Dart native route. Shared compiler
and interpreter contracts live in [portable-runtime.md](./portable-runtime.md).

The current app route compiles C/C++ with signed in-process LLVM 22 and LLD,
then interprets WASI Wasm data with signed WasmEdge. It does not execute fresh
OHOS machine code. OHOS SDK APIs and the native OHOS ABI are not WASI APIs.

## 2. Signatures

```powershell
./native/toolchain/package-ohos-portable.ps1 `
  [-DependencyDirectory <verified-archive-directory>] [-ProjectRoot <repo>] `
  [-OutputArchive <resource-zip>] [-Python <python-3.11-or-newer>]
```

The module remains `libqfli_ohos_runner.so`:

```typescript
create({toolchainRoot: string, onEvent: (event: RunnerEvent) => void}): RunnerHandle | null;
run(handle, projectPath, entryFile, sources: string[], cacheDirectory): boolean;
cancel(handle): void;
destroy(handle): void;
```

`RunnerHandle` is the returned opaque external itself; never access `.native`.
Legacy executor/compiler/linker/runtime path options are optional declarations
for source compatibility and are unused by this backend. The type package is
`cpp/types/libqfli_ohos_runner/`, registered by `entry/oh-package.json5`.

MethodChannel `qfli_forge/native` retains `start({runId,type,projectPath,entryFile,
sources?}) -> {available:boolean}` and `cancel({runId})`. EventChannel
`qfli_forge/native/events` retains independent stdout/stderr line events and
one terminal `{runId,kind:'exit',exitCode}`. Dart subscribes before starting.

## 3. Contracts

- Pin LLVM 22.1.0, WASI SDK 33.0 and WasmEdge commits from
  `native/toolchain/portable-dependencies.json`. Apply and record all checked
  runtime patches, including OHOS musl and interruptible polling fixes.
- Package data directly from SHA256-checked source archives. Include dependency
  license notices. Reject path traversal, duplicate entries and special files.
  Exclude host `bin/`, alternate no-EH and LTO trees. ZIP names use `/`.
- Resource asset is `qfli_toolchain/ohos-wasi.zip` plus an ASCII `.sha256`
  sidecar. SDK paths remain `share/wasi-sysroot/` and `lib/clang/22/`.
  Include common C headers/libraries, EH libc++/libc++abi/libunwind, startup
  objects, SjLj/process-clock archives and compiler builtins for both
  `wasm32-wasip1` and `wasm32-wasip1-threads` layouts.
- Manifest format is `formatVersion:2`, `llvmVersion:'22.1.0'`,
  `wasiSdkVersion:'33.0'`, exact compiler/runtime commits,
  `targetTriple:'wasm32-unknown-wasip1'`,
  `supportedTargets:['wasm32-unknown-wasip1','wasm32-unknown-wasip1-threads']`,
  `runtime:'wasmedge-interpreter'`, `execution:'interpreter'`, `jit:false`,
  `threading:'wasi-threads'`, `maxWorkerThreads:32`. It records runtime patch
  hashes, the resource inventory digest and key-file path/size/SHA256 entries.
- Stream raw ZIP bytes using the HAP descriptor's exact offset and length.
  Bound buffers, handle short reads/writes and close both descriptors. Verify
  the copied ZIP against the signed HAP sidecar before decompression. Remove
  the temporary ZIP on success and failure.
- Use `filesDir/forge-toolchain/ohos-wasi/<versionCode>-<updateTime>-wasi33-layout2`.
  Validate manifest/version/targets/interpreter/thread settings and required
  file sizes. Verify key-file hashes after extraction and on the first cached
  use of each app session. Re-extract a corrupt cache. Write `.ready` last.
- ArkTS emits `QFLI_OHOS_TOOLCHAIN_PREPARE_FAILED` on unavailable resources and
  `QFLI_OHOS_TOOLCHAIN_CACHE_INVALID` when repairing failed cached hashes.
  Native `create` throws `QFLI_NATIVE_INIT` on invalid resource paths or NAPI
  failures; preserve its exact message in MethodChannel `QFLI_NATIVE_FAILED`.
- Source lists follow [source-selection.md](./source-selection.md): explicit
  lists are authoritative; only absence enables discovery. Native validates
  absolute canonical readable project-local files, extensions, uniqueness and
  selected-entry membership, including symlink destinations.
- OHOS opts into `qfli_compiler_set_threads(session,true)` before compiling.
  Other callers retain the default single-thread target. Compile C17/C++20
  units separately, link with the EH/SjLj/process-clock libraries and publish
  `program.wasm` only after successful completion and cancellation checks.
- Each run uses `mkdtemp` under a validated writable cache. Open finite
  `input.txt` or `/dev/null`; preserve borrowed stdout/stderr descriptors and
  process cwd. Drain the two pipes concurrently while compilation/execution
  runs. Never redirect the app's process-wide standard streams.
- One external handle accepts one successful run. Its worker owns shared state
  separately. Cancel/destroy/GC request cancellation; session mutexes exclude
  cancellation from compiler/runtime destruction. Repeated cancel/destroy is
  safe. Exit follows session destruction, stream drain and private-tree cleanup
  without following symlinks. Buffer incomplete UTF-8 per stream before NAPI.
- Shared-memory modules receive one shared `env.memory`, one WASI descriptor
  table, and `wasi.thread-spawn(i32)->i32`. Each guest thread gets a separate
  VM invoking `wasi_thread_start(tid,arg)`. Limit concurrent workers to 32,
  reclaim completed slots and keep positive thread IDs unique within the run.
- A thread-group mutex protects startup, slots and process-exit state. Override
  WASI `proc_exit` before its module is finalized; a child's process exit stops
  the group and preserves the first exit code. Child traps stop the group with
  runtime failure. Repeatedly cancel every active VM through startup until all
  async executions join. Keep the AST, shared memory and WASI imports alive
  until then. Main exit also stops detached workers. Never join under the
  callback mutex.
- The shared-memory-growth patch serializes the returned old page count and
  growth commit. Interpreter size/bounds read an atomic count; imported worker
  VMs snapshot live memory limits under the growth lock. Preserve stable memory
  addresses while other workers access existing pages. Collect ready workers
  again before main-exit cleanup so completed detached traps retain status 125.
- Keep the active ArkTS slot during asynchronous preparation. Cancel or listener
  disconnect during preparation remains accepted cancellation, terminal 130
  after preparation cleanup. Preserve diagnostics, nonzero statuses and empty
  output lines. Missing resources report unavailable without a C-only fallback.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Dependency archive SHA mismatch, unsafe/special SDK entry or missing required resource | Fail packaging without replacing the previous ZIP |
| ZIP/key-file SHA mismatch | Reject or repair cache; never create a runner from unchecked resources |
| LLVM/WASI/target/JIT/thread manifest mismatch | Rebuild extraction; report unavailable if the packaged data remains invalid |
| Missing listener, malformed run fields, another active run | `missing_listener`, `invalid_run`, `runner_busy` respectively |
| Outside-project/duplicate/unreadable source or missing selected entry | Reject run; stderr and exactly one exit 127 |
| Native initialization throws | Forward exact message as `QFLI_NATIVE_FAILED`; release the active slot |
| Compile/link failure | Actual nonzero status and diagnostics; no stale module execution |
| Input resource or interpreter setup fails | Diagnostic and nonzero status |
| Wasm trap / child-thread trap / cost limit | Runtime status 125; app and subsequent runs remain usable |
| Program/child process exit | Preserve actual process status; stop remaining guest workers |
| More than 32 concurrent guest workers | WASI thread-spawn returns negative error; no resource leak |
| Accepted stop, including atomic wait or child sleep | Cancel every VM and join, then exactly one exit 130 |

## 5. Good / Base / Bad Cases

- Good: actual app compiles original C/C++ sources, standard-library exceptions,
  thread/join, mutex/condition-variable and atomics examples, preserves statuses
  and accepts a fresh run after errors and cancellation.
- Base: actual host compiler/interpreter/NAPI tests pass and the signed HAP
  builds; phone execution remains a separate acceptance gate.
- Bad: describe WASI as the native OHOS ABI, enable JIT, silently replace the
  threading lessons, or infer ordinary-app execution from `hdc shell` results.

## 6. Tests Required

- Run the actual package script and negative dependency-hash, missing-resource,
  traversal and special-file cases. Verify the resulting ZIP CRC, SHA256,
  manifest, both target layouts, notices and absence of host executables.
- `ohos-arkts-native-path-regression.cjs <typescript.js>` retains its historical
  filename but now tests production WASI preparation/start: realistic raw-FD
  slices/short I/O, archive and key-file hash failures, cache repair, incompatible
  manifest/JIT/thread settings, prepare cancellation, init-error propagation,
  blank/split lines and actual exit status. Native-library metadata is unused.
- Run the common portable compiler/runtime gates and actual OHOS NAPI bridge
  tests. Cover both default nonthread and opted-in thread targets, EH/SjLj,
  process clocks, large independent streams, destruction/GC and fresh recovery.
- Thread gates include original cpp090–093 unchanged, 32-worker rejection,
  more than 32 sequential creations, detached cleanup, child exit/trap,
  atomic-wait/CPU/sleep cancellation and subsequent successful runs.
- Run `ohpm install` and hvigor for ArkTS/SDK checking. Host binaries must be
  rebuilt after runtime changes; an older probe without the Threads proposal
  rejects these modules as `malformed limits flags`.
- Phone gate: require `QFLI_C_OHOS_AUDIT` with `ok:true` from the actual owning
  app, inspect every case, and exercise ordinary editor Run/Stop. Record exact
  HAP/device/ABI/results; host and build checks do not establish phone success.

## 7. Wrong vs Correct

Wrong: keep retrying `execve` against installed Clang after release-app EACCES.
Correct: use the signed in-process compiler and interpreter for the ordinary
phone route and report the real native-code restriction separately.

Wrong: interpret native-child API error 16010004 as device error 801.
Correct: 16010004 is `NCP_ERR_MULTI_PROCESS_DISABLED`; the 2026-10-16 phone
probe found the API but multi-process mode was disabled. The SDK documents
device restrictions separately. Do not change system security parameters to
claim a normal-app pass.

Wrong: cancel only the main VM or destroy its imports while guest workers run.
Correct: repeatedly cancel every VM, join all workers and release shared
memory/WASI/AST afterward, then emit the terminal event.
