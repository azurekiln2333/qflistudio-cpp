# Native Toolchain Build Contract

## 1. Scope / Trigger

Applies to `native/toolchain/build-llvm.ps1` and OHOS compiler packaging. This
is a native build boundary, independent of the legacy picoc/Dart interpreter.

## 2. Signatures

```powershell
./native/toolchain/build-llvm.ps1 -NativeSdk <native-sdk> -MsysRoot <msys2-root> `
  [-Stage All|Host|Target] [-TargetArchitecture arm64-v8a|x86_64] [-Jobs 2] [-ConfigureOnly] `
  [-BuildRoot <path>] [-SourceDirectory <path>] `
  [-HostBuildDirectory <path>] [-TargetBuildDirectory <path>] `
  [-SourceRepository <git-url>]
```

`package-llvm.ps1 -NativeSdk <path> -TargetBuildDirectory <path>` accepts the
same `TargetArchitecture`, plus optional `OutputDirectory` and `SourceDirectory`.

## 3. Contracts

- LLVM tag: `llvmorg-15.0.7`; commit: `8dfdcc7b7bf66834a761bd8de445840ef68e4d1a`.
- Existing source must match the commit and have no tracked content changes.
- Builds live under ignored `native/build/` by default.
- Host output: `bin/llvm-tblgen.exe`, `bin/clang-tblgen.exe`.
- Target output: ARM64 or x86_64 OHOS `bin/clang`, `bin/lld`, selected with
  `TargetArchitecture`. Separate target build directories prevent ABI mixing.
- Reject an existing target cache whose `OHOS_ARCH` differs from the request.
- Packaging requires LLVM 15.0.7, matching ELF machine IDs, and dynamic
  dependencies limited to `libc.so` and packaged `libc++_shared.so`.
- `toolchain.json` records relative paths and SHA-256 hashes. `bin/ohos.cfg`
  uses `<CFGDIR>` paths; runtime and startup files use upstream LLVM's full
  target-triple directory layout, adapted from the SDK layout.
- Configuration defines `__OHOS__`, `__OHOS_FAMILY__`, and `__MUSL__` for SDK
  headers. Without `__OHOS_FAMILY__`, libc++ locale headers have no rune table.
- Do not place SDK shared-library stubs in the runtime `LD_LIBRARY_PATH`.
- Clang 15 accepts `--config <path>`, not `--config=<path>`. Verify the layout
  with Clang 15.0.7; newer OHOS drivers use different runtime lookup rules.
- Package into a fresh directory; do not merge old SDK files into new packages.
- Host compiler frontends and DLLs are staged together. GCC `-B` selects them.
- Incremental target builds must preserve the staged DLL search path as the
  script does; a raw `cmake --build` can fail TableGen with `0xc000007b`.
- GCC 16 builds LLVM 15 with `-include cstdint`; do not patch the source for this.
- OHOS compile probes use `-Qunused-arguments` because the SDK injects an unused
  `--gcc-toolchain` option.
- Build success does not change `forgeProfile.runtimeStatus` or remove the
  existing fallback. App availability requires validation in the phone App.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Required SDK/compiler file missing | Stop with the exact missing path |
| Existing source at another commit | Stop; do not reset it |
| Existing source content modified | Stop; do not overwrite it |
| CMake/build executable returns nonzero | Throw; do not report a successful build |
| Target stage lacks host TableGen | Stop with the missing host executable |
| Target cache has another architecture | Stop before CMake; select a separate directory |
| `-fPIC` probe fails | Inspect the probe log before starting the full build |
| `hdc shell` can launch the ELF | Treat as device-shell validation only |
| Phone `childProcessManager` unavailable | Do not use it as an arbitrary executable launcher |

## 5. Good / Base / Bad Cases

- Good: pinned clean source, working host tools, PIC probes true, target ELF
  checked, then independent C/C++ multi-file and App tests.
- Base: host tools built and cross configuration passed; native availability
  remains unverified.
- Bad: copying Windows SDK executables to a phone, or declaring App support
  from a successful `hdc shell` run.

## 6. Tests Required

- PowerShell parser reports no syntax errors.
- Host compiler identification and C/C++ ABI probes pass with staged tools.
- Both host TableGen binaries start and report LLVM 15.0.7.
- Target C/C++ PIC probes are true; projects are exactly `clang;lld`.
- Target ELF architecture and `DT_NEEDED` are checked before packaging.
- Verify portable configuration by compiling/linking C and C++ header fixtures;
  successful cross linking is independent of execution validation.
- Device/App tests cover multi-file C, C++ standard library, project `include/`
  headers, mixed C/C++, compile/link errors, and cancellation before removing
  the existing runtime path.

## 7. Wrong vs Correct

Wrong: ignore failed compiler capability probes and continue with cached false
results. Correct: inspect `CMakeConfigureLog.yaml`, fix the actual cause, and
configure a fresh build directory.

Wrong: equate a runnable ARM64 compiler with an integrated phone backend.
Correct: validate compiler invocation and generated-program execution from the
actual application process before changing the capability declaration.
