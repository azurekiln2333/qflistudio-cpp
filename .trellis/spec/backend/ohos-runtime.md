# OHOS LLVM Runtime Contract

## 1. Scope / Trigger

Applies to `native/toolchain/package-ohos.ps1`, `ohos-executor.c`,
`ohos/entry/src/main/cpp/qfli_ohos_runner.cpp`, `QfliCNative.ets`, their NAPI
declarations, `EntryAbility` registration and the OHOS Dart native route.
The compiler build itself follows [native-toolchain.md](./native-toolchain.md).

## 2. Signatures

```powershell
./native/toolchain/package-ohos.ps1 [-ToolchainDirectory <package-llvm-output>] `
  [-ProjectRoot <repo>] [-NativeSdk <sdk-native>] [-ExecutorSource <c-file>] `
  [-TargetArchitecture arm64-v8a|x86_64]
```

MethodChannel `qfli_forge/native` exposes:

- `start({runId: String, type: 'c'|'cpp', projectPath: String, entryFile: String, sources?: String[]})`
  returns `{available: bool}`. The ordinary Dart caller supplies selected sources.
- `cancel({runId: String})` cancels the matching current run.

EventChannel `qfli_forge/native/events` emits independent line events followed
by one terminal event:

```json
{"runId":"ohos-1","kind":"stdout","text":"42"}
{"runId":"ohos-1","kind":"stderr","text":"main.c:2: error: ..."}
{"runId":"ohos-1","kind":"exit","exitCode":7}
```

The `libqfli_ohos_runner.so` NAPI module exposes:

```typescript
create({toolchainRoot, executorPath, compilerPath?, linkerPath?,
  runtimeDirectory?, onEvent}): RunnerHandle | null;
run(handle, projectPath, entryFile, sources: string[], cacheDirectory): boolean;
cancel(handle): void;
destroy(handle): void;
```

`RunnerHandle` is the returned opaque external itself. Never access `.native`.
`create` throws an `Error` with code `QFLI_NATIVE_INIT` on invalid initialization
arguments, filesystem validation or NAPI/resource creation failures. Its message
identifies the operation and affected argument/path, plus errno or NAPI status
when applicable; preserve an already pending JS exception. ArkTS forwards the
message unchanged in MethodChannel error `QFLI_NATIVE_FAILED` and releases the
active slot. Do not replace a thrown error with the generic null-handle message.
The declarations live in `cpp/types/libqfli_ohos_runner/`, registered through
`entry/oh-package.json5`; run `ohpm install` before checking ArkTS after changing
that dependency.

## 3. Contracts

- Pin LLVM 15.0.7, commit `8dfdcc7b7bf66834a761bd8de445840ef68e4d1a`.
  Packaging validates the input manifest, ELF64 little-endian ET_DYN machine,
  musl interpreter and SHA256 values. Allowed dynamic dependencies are `libc.so`
  and the packaged `libc++_shared.so`.
- Package `libqfli_clang.so`, `libqfli-ld.lld-.so`, `libqfli_executor.so` and
  `libc++_shared.so` under `entry/libs/<abi>/`. The first three are PIE
  executables installed with the app. Keep the `ld.lld` basename component:
  upstream LLD uses it to select its ELF driver.
- Preserve those four files through HAP native stripping with precise
  `nativeLib.debugSymbol.exclude` entries in `entry/build-profile.json5`.
  Verify their final HAP SHA256 values against the package manifest; AGP/hvigor
  stripping must not be worked around by disabling executable hash checks.
- `context.applicationInfo.nativeLibraryPath` can be relative: the actual phone
  returns `libs/arm64`. Resolve relative metadata against `context.bundleCodeDir`
  before checking files or calling NAPI, e.g. `/data/storage/el1/bundle` plus
  `libs/arm64` becomes `/data/storage/el1/bundle/libs/arm64`. Preserve an already
  absolute path; normalize trailing separators and leading `./`. Relative
  `accessSync` may succeed through the process cwd, while native canonical-path
  validation still rejects the same string. Do not rely on cwd for resolution.
- Production `create` receives compiler/linker/executor absolute paths under
  that resolved native directory, with `runtimeDirectory` equal to it. Reject
  missing/invalid directory metadata. Do not chmod or execute extracted compiler
  binaries in `filesDir`. Optional native path defaults exist for host checks.
- Native initialization validates absolute NUL-free canonical paths, expected
  directory/file types and required access. Filesystem errors include the
  affected field/path and errno; denied-access diagnostics also include file
  mode, readability and process/file ownership. NAPI creation errors identify
  the operation and status. Keep these diagnostics through the ArkTS/Dart
  boundary so an actual release permission failure can be distinguished from
  missing resources. A valid path and successful initialization do not prove
  the platform permits subsequent execution or generated-code loading.
- Raw asset `qfli_toolchain/ohos-<abi>.zip` contains `toolchain.json`,
  `bin/ohos.cfg`, `sysroot/`, `include/c++/v1/`, `lib/clang/15.0.7/` and link-time
  libraries under `lib/<full-target-triple>/`. It excludes `bin/clang` and
  `bin/ld.lld`. The installed manifest sets `installedNativeExecutables:true`
  and records native filenames and executor metadata. Packaging writes a ZIP
  `.sha256` sidecar and checks every entry uses `/`, including on PowerShell 5.
- Current ArkTS chooses `ohos-arm64-v8a.zip`, LLVM 15.0.7 and
  `aarch64-unknown-linux-ohos`. Script support for x86_64 does not establish an
  x86_64 app route; add ABI selection and independently verify it before use.
- Copy the stored ZIP through `resourceManager.getRawFd`: respect its HAP
  `offset` and `length`, use bounded buffers, handle short reads/writes and close
  both descriptors. Keep the ZIP asset uncompressed in the outer HAP so raw-FD
  access works. Decompress asynchronously and remove the cache archive.
- Extraction roots include bundle `versionCode`, `updateTime` and layout
  revision, so reinstalling a changed HAP with the same version invalidates
  old resources. Write `.ready` only after checking the manifest and required
  files. C++ headers are at `include/c++/v1/vector`, not under `sysroot/`.
  Repair an incomplete cached root by extracting again.
- Use Clang 15 `--config <path>` and explicit installed `--ld-path=<path>` at
  link time. The config supplies OHOS/musl macros and full target-triple runtime
  paths. SDK shared-library stubs are link-time inputs and must never enter
  runtime `LD_LIBRARY_PATH`.
- Compile each `.c` unit as C17 and `.cpp`/`.cc`/`.cxx` as C++20, case
  insensitively, with explicit `-x c`/`-x c++` and PIC. Include the project root
  and its `include/` directory. Any C++ unit selects the C++ link driver, even
  with C main. Link `-lm`; OHOS atomic builtins come from compiler-rt and its
  SDK has no standalone `libatomic`. Do not copy Android's `-latomic` option.
- Follow [source-selection.md](./source-selection.md). ArkTS rejects malformed
  explicit lists and discovers legacy project sources only when the key is
  absent. Native validates canonical readable project-local regular sources,
  including symlink destinations; reject duplicates and lists omitting entry.
- `run` requires an app-writable cache directory as its fifth argument. Use
  atomic `mkdtemp` beneath it for each accepted run and a unique PID file per
  compile unit, link and execution. `O_EXCL` forbids reusing `compile.pid` for
  multiple units. Remove temporary trees without following user symlinks.
- Link fresh `program.so` with `-shared`, `-Wl,-z,defs` and 16 KiB maximum/common
  page sizes. Mark it read-only before loading. A separate installed executor
  uses `dlopen`/`dlsym` to call exported `main`; user code never runs inside the
  Flutter process. Compile/link failure must not run a stale previous output.
- Working directory is the project. Supply regular `input.txt` as stdin when
  present, otherwise `/dev/null`; preserve stdout, stderr and child status.
  User-generated code loading still requires actual app code-policy checks.
- Perform only async-signal-safe operations between multithreaded app `fork`
  and `execve`; prepare argument/environment storage beforehand. Poll stable
  stdout/stderr/cancel slots together and keep checking child exit after either
  or both streams close. Kill remaining group descendants after leader exit.
- A handle accepts one successful run. The worker owns shared state separately
  from its external wrapper. `destroy`/GC requests cancellation and drops that
  ownership; repeated destroy/cancel must be safe. Cancellation uses a
  nonblocking CLOEXEC pipe synchronized with worker descriptor closure, kills
  the process group and ends with 130 after output drain/cleanup.
- Buffer incomplete UTF-8 bytes separately for stdout/stderr before NAPI string
  conversion. ArkTS joins partial lines independently, preserves blank lines,
  removes CR from CRLF lines and flushes final tails before exactly one exit.
  Dart subscribes before start and filters by `runId`.
- Allow one active run, including asynchronous toolchain preparation. Cancel or
  EventChannel disconnect during preparation marks it cancelled; preparation
  failure must then resolve as accepted cancellation with exit 130. Native
  events still release the handle after the output sink disconnects.
- Missing resources/native executables return `available:false`. The current
  OHOS Dart route disables C interpreter fallback; accepted compile/link/runtime
  errors always preserve their diagnostics/status. Keep implementation,
  HAP-build evidence and actual app execution evidence distinct.
- ArkTS logs preparation failures as `QFLI_OHOS_TOOLCHAIN_PREPARE_FAILED`, invalid
  installed-directory metadata as `QFLI_OHOS_NATIVE_DIRECTORY_FAILED`, and the
  exact absent native file as `QFLI_OHOS_NATIVE_FILE_MISSING`. Keep those distinct
  from a native `QFLI_NATIVE_INIT` exception after the files have been found.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Manifest version/ABI/hash, ELF machine or musl loader mismatch | Packaging fails before publishing final output |
| Missing archive, incomplete extraction or missing installed native files | Report unavailable; do not launch a partial toolchain |
| Missing/invalid run fields, malformed explicit sources | `invalid_run` |
| No EventChannel listener | `missing_listener` |
| Another run preparing/active | `runner_busy`; preserve its ownership |
| Outside-project source, unreadable source, duplicate or missing entry | Native run rejected; stderr and one exit 127, no program execution |
| Relative native-library metadata | Resolve against `bundleCodeDir`; pass absolute paths to native |
| Invalid native-directory metadata or missing installed file | Report unavailable and log the specific metadata/file failure |
| Native create validation/resource operation fails | Throw native `QFLI_NATIVE_INIT`; ArkTS reports `QFLI_NATIVE_FAILED` with the original detailed message and releases active slot |
| Compiler/linker fails | Forward diagnostics and actual nonzero status, no stale launch |
| Executor spawn/load/input fails | Report diagnostics and exit 125 |
| Program returns nonzero or crashes | Preserve return code or `128 + signal`; app remains alive |
| Cancel before native acceptance or during native work | One exit 130 and cleanup; no interpreter switch |
| One/both output streams close while child runs | Keep cancellation and child-exit observation live |

## 5. Good / Base / Bad Cases

- Good: installed native executables plus validated resource ZIP; actual app
  compiles C/C++, mixed units and headers, preserves errors/status and cancels
  descendant processes before a fresh run.
- Base: host orchestration/NAPI regressions pass and signed HAP builds; app
  compiler execution and generated-code loading still need independent tests.
- Bad: assuming a successful build or `hdc shell` compiler launch proves app
  runtime support, executing extracted clang, checking the wrong libc++ include
  path, or calling `run(handle.native, ...)`.

## 6. Tests Required

- PowerShell parser and package checks: pinned manifest/ELF metadata/hashes,
  installed four native files, resource-only ZIP, forward-slash entries and
  required C/C++ headers/compiler-rt/CRT/link-time runtime files.
- `native/toolchain/tests/ohos-bridge-regression.py` runs the actual bridge core
  and executor on Linux with Clang 15. Assert large independent streams,
  cancellation after stream EOF, descendants, mixed language modes, headers,
  math/input/status, syntax/link failure, symlink containment and cleanup.
  Its optional actual Node NAPI addon checks UTF-8 byte splits, failed-validation
  retry, one-use acceptance and repeated cancel/destroy/GC. A reported skip is
  not a pass for that addon gate.
- Check ArkTS actual-source protocol behavior: split lines/UTF-8, blank lines,
  CRLF/tails, terminal once, rejected-run release, explicit-list validation,
  absent-list discovery, preparation cancellation, short raw-FD reads/writes and
  actual package readiness. Run `ohpm install` and hvigor to type-check ArkTS
  and compile native code against the target SDK.
- `native/toolchain/tests/ohos-arkts-native-path-regression.cjs <typescript.js>`
  transpiles the production ArkTS source with the supplied SDK TypeScript
  compiler. Assert that relative `libs/arm64` resolves against `bundleCodeDir`,
  absolute metadata is preserved, and every native option uses the resulting
  directory. Model relative access succeeding through cwd while native requires
  absolute paths. Assert unavailable diagnostics for missing files/invalid
  metadata, and exact MethodChannel propagation of a thrown native init error.
- Run focused Flutter native channel and OHOS routing tests and Dart analysis.
- Device gate: execute `tool/ohos_native_audit.dart` through the actual app,
  require `QFLI_C_OHOS_AUDIT` with `ok:true`, and inspect every case. Include C,
  C++ standard library/exceptions, mixed units/headers, math/stdin/both streams,
  nonzero exit, compiler/link diagnostics, crash isolation, child cancellation,
  recovery, selected entry and long UTF-8 lines. Also test ordinary editor
  Run/Stop through the final owning application.
- Record exact artifact, app/device/ABI and results before declaring device
  verification. At creation of this spec on 2026-10-15, final app/device gates
  are pending; host and build checks alone do not satisfy them.

## 7. Wrong vs Correct

Wrong: validate readiness using `sysroot/usr/include/c++/v1/vector`, then treat
`available:false` as evidence the compiler has not been ported. Correct: validate
the package's actual `include/c++/v1/vector` and separately exercise the installed
compiler, linker and generated-program executor through the app channel.

Wrong: turn every pipe read into a Dart output line or reuse one PID file for
all translation units. Correct: preserve UTF-8 and line boundaries per stream,
and give each executor invocation its own exclusive PID file.

Wrong: pass `applicationInfo.nativeLibraryPath` straight to `create` because
`accessSync` found the files, or replace an initialization exception with a
generic unavailable message. Correct: resolve relative metadata against
`bundleCodeDir` and preserve the native operation/path/errno diagnostics.

Wrong: replace remaining app verification with successful host Clang tests.
Correct: use host regressions to check orchestration and require the actual
OHOS app gates before changing runtime capability claims.
