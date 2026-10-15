# OHOS portable native review, 2026-10-16

Review scope: the production in-process compiler/interpreter path in
`D:/MyNewProjects/qfli_c`, including thread startup, cancellation, stream delivery
and cleanup. This final pass was read-only, apart from this review record. It
did not rebuild libraries, rerun the passed test matrix, operate a device, stage,
commit, push, fetch or change Git configuration. The owning agent handles the
signed-app acceptance and final integration separately.

## Findings

No additional concrete, reproducible production defect was identified in this
pass. The production sources and regression script were unchanged after runtime
commit `245a99fbd013e02d35a59e7db26f6e03a79c3173` when reviewed.

- The NAPI worker retains shared run state after handle destroy/GC. Session
  registration and destruction exclude concurrent cancel calls using the
  session mutex; compilation, interpretation and reader joins run outside it.
- Cancellation is cooperative and atomic. The runtime repeatedly interrupts
  all active VMs through startup, joins outside the thread-group callback
  mutex, and keeps shared memory, the AST and WASI modules alive until joining.
- Worker slots are reclaimed, process exit is synchronized, and ready worker
  failures are collected again before main-exit cleanup. Detached worker traps
  therefore retain runtime failure instead of being hidden by cleanup stops.
- Concurrent memory growth serializes the returned old page count and commit.
  Interpreter bounds use an atomic page count. Imports snapshot live limits
  under the growth lock, and stable allocation avoids rewriting the shared
  memory pointer. Both inspected host and OHOS configurations define HAVE_MMAP.
- Compiler cancellation destroys retained frontend/backend objects before
  their LLVMContext. Serialized LLVM/LLD access, per-frontend EH/SjLj option
  restoration and borrowed diagnostic streams remain intact.
- Separate output readers drain both pipes before terminal delivery. Session
  destruction, descriptor closure, joins and private-directory removal precede
  the exit event and TSFN release. Incomplete UTF-8 is retained per stream.

The first cancellation audit timeout was a fixture compilation failure:
strict C17 hid `nanosleep` without `_POSIX_C_SOURCE`. The audit waited for a
runtime stdout marker after compilation had already failed. The owning agent
is correcting the audit fixture and diagnostics; this was not evidence of a
native cancellation deadlock. Final device conclusions belong to the owning
agent's acceptance record.

## Test evidence and limits

The preceding session executed the real production NAPI source as a Node addon,
freshly compiled the common compiler/runtime adapters, and linked real LLVM 22
and the final patched WasmEdge archives. Its actual tool output reported
**31 successful in-process compiler/interpreter runs**. Coverage includes
C17/C++20, standard exceptions/destructors, mixed sources, stdin/math, process
clocks, SjLj, threads/atomics/condition variables, CPU/sleep cancellation of all
threads, growth result uniqueness, detached traps, compile/link/trap recovery,
source selection, independent large streams, UTF-8 splits, compile cancellation,
pre-cancel, destroy/GC and a subsequent successful run. Each terminal callback
checks the private cache is empty and process cwd is preserved; the Python
runner also rejects process stderr escaping the event pipes.

This **31/31 result is existing session/tool evidence**, not a new execution in
this read-only pass. No independently saved final 31-run log was found. The
temporary successful addon build `/tmp/qfli-ohos-portable-m_son5im` was removed
by the test harness. The tracked script below contains the final two added
growth and detached-trap cases. This record must not be represented as a fresh
31-run log or as phone acceptance. The original 19 default portable gates and
compiler lifecycle/recovery checks also passed earlier with the final core.

## SHA256 correspondence

Hashes below were computed directly during this review.

| Source or patch | SHA256 |
| --- | --- |
| `native/compiler/compiler.cpp` | `5a56e6393f9983b81bf2a35eda9d0fc2fdd879e05f4416862cf957aa30a10d5d` |
| `native/portable/wasm_runtime.cpp` | `e94f1ba4c6e1e90a095dbfc1d25ee4316bfa9fe40a9b0e65eb6e3838f0c40140` |
| `ohos/entry/src/main/cpp/qfli_ohos_portable.cpp` | `4f06a5bc4de7242352d5886c63d70f4b52513f75364696a767a6589d4c1f4872` |
| `native/toolchain/tests/ohos-portable-bridge-regression.py` | `ce0a245eb00f354e1f084aaedb560e9f025584ab73b16dbebbdab08b3285bafa` |
| `wasmedge-interruptible-poll.patch` | `751c8581be13c260c83b6a7bc212352ba953b480a2ab18659d302aea93e01c4e` |
| `wasmedge-ohos-musl.patch` | `df211977a22e3060890b3c8fddd60b497dde3cf1625054d842941afd0ba34f5e` |
| `wasmedge-shared-memory-growth.patch` | `e593f66d367fd9efd54bb27446f81f0a70d1093df8bf899e3f2c5910b988c9b9` |
| `wasmedge-static-archive.patch` | `2df4a65505f1b1b58a66a3b361bedbeb375434045b59edadfdfa5a9f42a8c294` |
| `native/build/ohos-portable-probe/runtime-artifact-evidence.json` | `fed6f393ca5ebd19249d9680bbe32672ffd9bf1602193b305ad5f3aac42a2a53` |

Patch filenames in the table are under `native/portable/patches/`.

The inspected ARM64 artifact evidence records the same adapter source and all
four patch hashes. It records `libqfli_wasm.a` as
`3a2fcf971b6d2ca810f8d1d7cf2cd595d19c465a229b7810f3bb8347b2a82116`,
the adapter object as
`e7a24e943d207bb68c837903cc070bd1499b1111678fff4063fb23ea862f1d14`,
and the probe as
`662ce0778d65b960050b609405951a05f2de73b7363d1c0646fe35e5db411ef6`.
These three binary hashes are quoted from that existing evidence file, not
independently recomputed in this pass. The record specifies WasmEdge source
`845df599e7b71c98b0c77990c3aa3a10022bbaae`, interpreter-only execution,
108 ARM64 objects, strict whole-archive shared linking and 16 KiB minimum load
alignment. Its `appExecutionVerified:false` remains an artifact-check boundary;
it does not replace the later signed-app device gate.

## Read-only remote snapshot

At approximately 2026-10-16 04:17 +08:00, `git ls-remote --exit-code <remote>
refs/heads/main` succeeded for all five configured remotes:

| Remote | `refs/heads/main` |
| --- | --- |
| cnb | `54099bf134ea08a196dc29d71b9dcbc8f0690c40` |
| gitcode | `54099bf134ea08a196dc29d71b9dcbc8f0690c40` |
| gitee | `54099bf134ea08a196dc29d71b9dcbc8f0690c40` |
| github | `54099bf134ea08a196dc29d71b9dcbc8f0690c40` |
| gitlab | `54099bf134ea08a196dc29d71b9dcbc8f0690c40` |

GitLab's configured fetch transport is HTTPS and push transport is SSH. Removing
transport syntax and the optional `.git` suffix resolves both to
`gitlab.com/azurekiln-team/qflistudio-cpp`. An additional read-only `ls-remote`
against the configured push URL returned the same main SHA. No credentials or
raw authenticated URLs were printed. This is a point-in-time remote snapshot;
the owning agent performs any authorized pushes and post-push verification.
