# OHOS in-process compiler and interpreter acceptance, 2026-10-16

## Architecture and scope

The actual release phone rejected the original compiler/executor process chain
with EACCES, and the official native-child probe returned 16010004
(`NCP_ERR_MULTI_PROCESS_DISABLED`). See the separate device failure record.
The replacement embeds signed ARM64 LLVM/Clang/LLD 22.1.0 and WasmEdge in the
application, compiles project C17/C++20 to WASI bytecode, and forces interpreter
execution. This is WASI compatibility, not generated native OHOS ABI execution.
No JIT, generated native mapping or device policy changes are used.

Pins and archive hashes live in `native/toolchain/portable-dependencies.json`.
The build is `native/toolchain/build-ohos-portable.sh`; resources are generated
by `package-ohos-portable.ps1` directly from verified dependency archives.
`verify-ohos-portable-package.py` checks resources and the exact signed HAP,
including ABI, dynamic dependencies, alignment and absence of old PIE tools.
Its artifact result deliberately keeps `appExecutionVerified:false`.

The resource ZIP contains 4114 SDK/license files (15.9 MiB); SHA256:
`a29e74b526e4689289d590ab35d1dee6209d9b0ccb7538554284000ef4cc5d27`.
Both WASI targets and the 32-worker thread limit are explicit manifest fields.
ArkTS checks the signed sidecar before extraction, then manifest/key digests.
Missing required files, modified patch hashes and disabled threads are rejected.

## Verified host and source gates

- True in-process compiler plus OHOS NAPI adapter: 31/31 actual runs, including
  C/C++ mixing, EH, SjLj, process-clock emulation, stdin, independent output
  drains, UTF-8 boundaries, errors/trap recovery, cancellation and destroy/GC.
- The original 19 common portable gates and compiler lifecycle/recovery gates
  also pass with threading disabled by default. OHOS opts into WASI threads.
- Original C++ curriculum 090–093 runs verbatim: outputs `sum=30`, `total=15`,
  `counter=4000` and `data=42`, respectively; all exit zero.
- Runtime probes cover mutex/condition_variable, atomic waits, exceptions in
  workers, 32-worker exhaustion, 100 sequential joins, detached worker cleanup,
  worker proc_exit/trap and cancellation of every VM before resource release.
- Concurrent memory growth adds exactly 256 pages with 256 unique previous-page
  results; the serialized control and ten concurrent repetitions pass. The
  final main-exit poll also preserves a detached worker's completed trap as 125;
  ten repetitions pass. Patch SHA256:
  `e593f66d367fd9efd54bb27446f81f0a70d1093df8bf899e3f2c5910b988c9b9`.
- OHOS SDK ARM64 bridge syntax passes `-Wall -Wextra -Werror`.
- Updated curriculum native compilation/execution: 200/200; no placeholders,
  no shape or staged-source mismatches. Each language retains 100 pairs.
- The final threads-enabled WASI host curriculum matrix also passed 200/200
  using the corrected memory-growth core and reviewed runtime. Its durable
  report is the curriculum task's `research/portable-curriculum-2026-10-16.json`;
  runtime binary SHA256 is
  `149bcd647cffc34c3088f9ff2a88283cfd5e018d403f6b52e01a84041fb00da2`.
  The report records both bundled asset hashes and each original source/output/input
  hash; it is explicitly host-only and separate from the phone result below.
- Full application Flutter VM suite: 178/178. Full static analysis: zero issues.

The main compiler cancellation fix orders CompilerInstance/module destruction
before LLVMContext destruction; actual active compilation previously crashed.
Clocks use SDK33 elapsed wall-time emulation. `setjmp` links SDK33's library and
resets LLVM's SjLj option for each frontend invocation while retaining EH.

## Signed-phone acceptance

The nova 14 Ultra ARM64 phone completed **212/212 unique cases**: 12 compiler,
runtime, error, cancellation, shared-memory-growth, selected-entry and output
checks plus all original 100 C and 100 C++ curriculum programs. Every curriculum
case exited zero with matching output and empty stderr. The original C++
thread/mutex/atomic/condition-variable sources remain intact.

Persistent evidence is
`research/ohos-portable-device-2026-10-16.json` (all 212 cases, source/HAP/log
hashes). Its audit source SHA256 is
`c7de41a78441ce3c2fc03e0ce1404a78dacfbb035c36eadf9da4e72a4678c6c2`;
the signed audit HAP SHA256 is
`e85120111893d9a319eb1160440037f26e2cd13e14b154fbf186e91087c7c1d2`.
The earlier audit's missing C17 feature-test declaration and deprecated C++
volatile increment were corrected in the audit fixtures before this complete
run; their failures were never counted as runtime passes.

This audit proves actual application compilation and execution. Static package
verifier reports intentionally retain `appExecutionVerified:false`; the device
report supplies execution evidence.

## Ordinary production UI acceptance

The coordinator strictly verified the production `lib/main.dart` HAP and
installed it with `install -r`, preserving existing `sss` and `tt` user data.
In a new scratch C++ project, ordinary Run printed `Hello, QFLIStudio+!`, Stop
interrupted compilation with terminal status 130, and a fresh Run succeeded. The Tutorial list and
lesson detail opened with objective, source, output and exercises. The Examples
list explicitly showed 200 entries; example detail displayed source/output.

`research/ohos-production-ui-2026-10-16.json` records the production HAP/hash and
UI evidence. Production HAP SHA256 is
`f7472a09e0bd8773cfd971908653a41a1f96df754ea7ca78e8b10d26f1000e69`.
Screenshots are
`native/build/qfli-production-{run,stop,tutorials,lesson,examples}-20261016.jpeg`.
These product checks and the separate 212-case signed audit complete the OHOS
acceptance gates. The independent substantive-curriculum task is complete; the
cross-platform runtime task remains open for its other platform/finalization
gates.

## Build and artifact acceptance

The ARM64 LLVM22 compiler and final patched runtime archives are complete and
linked into the signed audit and production HAPs. Bootstrap build provenance is
retained with the packaged archives. The consolidated
`build-ohos-portable.sh` passed real `--configure-only` and isolated source-tree,
patch-application, idempotence and drift-rejection tests. A fresh full clean
build using that consolidated script has not been run.

Android release rebuilding and artifact inspection passed: both packaged ABIs,
ELF dependencies, owned curriculum/resources and hashes, and APK v2 signing.
`native/build/android-release-artifact-20261016.json` records APK SHA256
`ec79aa536f49494acea16723ac20e5f52377415bce626352d276f3ca09301715`.
No Android device operation was performed.

## Workspace isolation

All writes and Git commits stay under `D:/MyNewProjects/qfli_c`. The sibling
shared core was concurrently receiving incomplete backup-service edits, which
broke an initial test compilation. The test process also hit Windows commit
memory exhaustion. Neither is treated as a successful test run.

For reproducible acceptance, root used read-only `git archive` of shared-core
commit `7768b91a3ea3591fc9d0b333cb177d08025277e7` into the ignored local
`native/build/shared-core-7768b91a3ea3` directory and redirected only this app's
generated `.dart_tool/package_config.json` entries for qfli_studio_core and its
vendored re_editor. No sibling files changed. The final 178-test and analysis
results above use this committed snapshot. Its provenance is recorded in
`native/build/shared-core-snapshot.json`.

The app now bundles its own curriculum through ForgeContentRepository; no
shared-core aggregate content write is needed. Native expected output remains
unchanged; OHOS selects explicit WASI output for errno and target macros.

## Remaining acceptance gates

- Record final device/artifact results, conventional commits and five remote
  heads. Keep independent iOS/Web task gates open.
