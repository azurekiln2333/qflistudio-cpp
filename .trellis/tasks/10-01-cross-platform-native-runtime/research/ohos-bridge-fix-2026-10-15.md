# OHOS bridge corrective review, 2026-10-15

Historical checkpoint from before the final installed-executable packaging
and renewed device-testing authorization. The extracted-executable `chmod`
change described below was superseded: production now uses signed installed
native files. Its old device-testing prohibition is also superseded. Current
results and remaining gates are in `../ohos-status.md` and
`acceptance-artifacts-2026-10-15.json`; do not use this checkpoint as the final
layout, artifact size or acceptance claim.

User requested urgent OHOS C++ repair while three Pi sessions are active. This session restricted production edits to `ohos/entry/src/main/cpp/qfli_ohos_runner.cpp` and `ohos/entry/src/main/ets/plugins/QfliCNative.ets`; preserved all baseline dirty files and signing configuration. No commit, device installation or device execution performed.

The earlier `ohos-status.md` conclusion that there were no code defects and only signing blocked completion is disproven by source review and regression execution:

- NAPI create returns a direct external handle; ArkTS dereferenced `.native`, passing undefined to run/cancel/destroy.
- RunState temporaryDirectory was never initialized: mkstemp attempted `/program-XXXXXX` rather than an app-writable cache directory. Added explicit fifth run argument `context.cacheDir`.
- Every translation unit reused `compile.pid`; executor uses O_EXCL, so the second source failed. Each unit now has its own PID file.
- Raw ZIP was treated as a filesystem resourceDir child instead of reading HAP raw resources through resourceManager. Stage raw bytes in cache, decompress, remove archive.
- ZIP executable permissions were not restored. Native create now chmods compiler/linker and fails initialization if that fails.
- RunChild compacted poll descriptors, losing stdout/stderr identity and cancellation polling after one stream closed. Keep three stable slots; EOF sets fd=-1. Handle EINTR and kill on fatal poll failure.
- Fixed output-pipe allocation failure cleanup, added exec error diagnostics, made cancellation pipe nonblocking/CLOEXEC, and synchronized cancel writes with worker descriptor cleanup.
- Preparing runs can now be marked cancelled even before a native handle exists. Null handle initialization reports an error. Destroy cleans up handles whose run was never accepted.

Validation:

- `native/toolchain/tests/ohos-bridge-regression.py`, executed in WSL qfli-java-build: passed actual bridge process-loop tests for stderr identity after stdout EOF and cancellation after stdout EOF. Actual CompileAndRun plus actual executor compiled two C/C++ units, linked, ran vector/exception code, printed 42, and preserved exit 7 using Linux Clang 15. This is host evidence, NOT OHOS app evidence.
- Focused Flutter channel tests: 8 passed.
- Focused Flutter analysis: no issues.
- Final hvigor assembleHap: BUILD SUCCESSFUL, including ArkTS, native build, package and SignHap (18.624 seconds). Existing signing setup now works; did not change it.
- Signed output: `ohos/entry/build/default/outputs/default/entry-default-signed.hap` (~229.7 MB).
- Build log: ignored `native/build/ohos-bridge-fix-build.log`.

Remaining acceptance boundary: no actual phone-app compile/run performed. In particular SELinux executable/data policies, dynamic loading of generated program.so, C++ runtime lookup and end-to-end Flutter events remain unverified. LLVM binary packaging/build is not complete OHOS application portability. Do not claim all C++ support fixed based on these local checks. Prior task explicitly prohibits device debugging; this session did not override that constraint.
