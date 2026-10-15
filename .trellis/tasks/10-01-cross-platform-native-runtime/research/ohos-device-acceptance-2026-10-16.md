# OHOS actual application acceptance, 2026-10-16

Workspace: `D:/MyNewProjects/qfli_c`. Device: previously authorized nova 14 Ultra
(`MRT-AL10`), HDC `192.168.68.207:46551`. Android remains build-only; no sibling
workspace writes. User signing configuration remains outside these commits.

## Current result

The phone is now unlocked and application launch succeeds. This replaces the
2026-10-15 lock-screen blocker. Actual release application execution reproduced
an initialization failure before even the first C case; C++ acceptance is still
pending. Build/host checks did not establish application usability.

## Concrete failures and fixes

1. Installed original diagnostic HAP without deleting app data. Normal start
   succeeded, but `real-C-source` returned 127 with the generic native
   initialization failure; `passed:[]`.
2. `bm dump` reports `nativeLibraryPath: libs/arm64`, which is relative. The
   previous ArkTS code passed it directly to native `ResolvePath`, which rejects
   relative paths. Resolve it against `context.bundleCodeDir`, preserving
   absolute metadata. The new actual-source ArkTS regression covers both forms,
   missing files, malformed metadata and native error propagation; it passes.
3. Rebuilt and installed the release diagnostic HAP. Exact native errors now
   reveal `access(X_OK)` rejection for the absolute installed executor path.
4. A further diagnostic build confirms:

   ```text
   executorPath=/data/storage/el1/bundle/libs/arm64/libqfli_executor.so
   Permission denied (errno 13; st_mode=0100644; R_OK=yes; read_errno=0;
   owner_uid=3060; owner_gid=3060; uid=20020362; euid=20020362)
   ```

   The application process is `normal_hap`; its bundle mount has no `noexec`.
   The system `/lib/ld-musl-aarch64.so.1` is executable (0755). Investigating its
   documented program-loading interface for readable installed signed PIE
   files was tested without chmod, policy changes or debug-mode substitution.
5. Implemented the complete system-loader chain for the three readable installed
   PIEs, integrated Clang cc1, and strictly decoded Clang's unique linker plan
   without a shell. All 15 actual bridge/executor/NAPI host regression groups
   and strict OHOS SDK checks pass. The release HAP builds and package hashes
   validate, but its actual application still fails before compilation.
6. Added the precise executable path and errno to the async-signal-safe spawn
   diagnostic. On device PID 2382, the first C case reports:

   ```text
   Forge: cannot execute compiler or program
   '/system/lib/ld-musl-aarch64.so.1': permission denied (errno 13)
   ```

   Thus a readable signed tool and executable system loader do not establish
   app permission to launch them. The direct fork/exec architecture remains
   unusable on this release phone. Investigating official native-child APIs
   and cross-building the existing LLVM/WASI/interpreter adapters; neither
   alternative is currently declared supported by this application.
7. Packaged a separate signed native-child capability probe and called the
   public API 13 `OH_Ability_StartNativeChildProcess` with a named writable FD.
   Actual release phone PID 6064 reports `apiAvailable=1`, `errorCode=16010004`,
   `pid=-1`, `openErrno=0`. SDK names this `NCP_ERR_MULTI_PROCESS_DISABLED`;
   it is not the distinct 801 unsupported-device result. No child callback ran.
   Removed the temporary HAP wiring after collecting the result. Do not change
   device system parameters to substitute for ordinary application support.

## Evidence and next gates

- `native/build/ohos-device-baseline-full-20261016.log`: original app failure.
- `native/build/ohos-device-resolved-path-20261016.log`: absolute-path error.
- `native/build/ohos-device-mode-20261016.log`: installed file mode and access.
- `native/build/ohos-device-loader-20261016.log`: loader-chain app failure.
- `native/build/ohos-device-exec-detail-20261016.log`: exact loader execve denial.
- `native/build/ohos-device-child-probe-20261016.log`: public native-child API
  refuses startup because multi-process mode is disabled on this phone.
- Diagnostic release builds/signing and exact HAP verification pass. New native
  initialization errors and permissions regressions pass all 15 host groups;
  strict OHOS SDK C++ syntax checks pass. These remain host/build evidence.
- No actual compiler/program case has passed yet. Continue through installed
  compiler, linker and generated-program loading; then require all 210 app cases
  and ordinary production editor/tutorial/example UI acceptance.
- Restore a production `lib/main.dart` HAP without deleting user data after the
  diagnostics. Do not deliver the diagnostic entry as the normal application.

Log collection on this phone uses `hilog -x`. Its `-d` option selects a
dictionary, and `-T` selects tags; neither means a dump or a tail count. Earlier
`hilog -d -x` / `-T 2000` commands were invalid evidence collection. New results
above use the actual app PID and the valid query syntax.
