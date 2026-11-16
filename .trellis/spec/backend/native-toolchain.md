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

## GitHub native artifact builds

- `.github/workflows/native-artifacts.yml` uses hosted Ubuntu 24.04 runners.
- Android ABIs have isolated jobs and build roots. The Linux bootstrap pins
  LLVM 15.0.7 and NDK 27.0.12077973, then reuses the platform-aware packager.
- Preserve Windows package behavior when resolving host NDK tool paths.
- Upload final jniLibs/assets, manifests and validation reports. Never upload
  the full native/build tree or local SDK/signing material.
- `prepare-portable-wasm.ps1 -ArchivesOnly -IncludeCompiler` verifies all
  dependency archives without extraction for the OHOS resource-only job.
- Resource ZIP metadata uses a fixed timestamp. Validate the ZIP through
  `verify-ohos-portable-package.py` before exporting a downloadable artifact.
- A WASI resource ZIP is not an OHOS static library package or installable HAP.
  Full OHOS builds use the pinned public API 18 SDK rather than a local SDK
  upload. Record this SDK independently of existing API 26 local packages.
  Android fixture cross-linking does not establish device execution.
- Native artifacts have 30-day retention; diagnostic logs have 7-day retention.
  Every native artifact includes source commit, run URL, and SHA256 inventory.

## Complete mobile dependency workflow

### Scope and commands

- Android `build-android-llvm-linux.sh --ndk PATH --abi ABI [--preflight-only]`
  builds host TableGen, generates resource headers, then validates resources
  before the expensive target clang/lld build. ARM headers need TableGen.
- OHOS `prepare-ohos-sdk.py --output PATH` checks both official archive hashes.
  `build-ohos-portable.sh --native-sdk PATH/native` builds compiler/runtime
  archives using the SDK's headers and runtime. Legacy `--ohos-resources`
  remains available. The two input modes are mutually exclusive.
- iOS `build-ios-portable.sh --slice SLICE --no-install` builds one Apple slice.
  `package-ios-xcframework.py assemble --slice-dir PATH ... --output PATH`
  merges exactly device ARM64 and simulator ARM64/x86_64.
  `install-ios-package.py --package PATH` generates local Flutter xcconfig.
  Keep the local installer compatible with Python 3.9; hash files in chunks.

### Contracts and failures

- Ubuntu Clang 15 must select libc++ explicitly. Use `-nostdinc++ -isystem`
  for packaged C++ headers and select compiler-rt/libunwind for links.
  Missing C++ headers must fail the early fixture validation, not after LLVM.
- Use versioned Ubuntu linker paths: lld-18 provides `/usr/bin/ld.lld-18`.
- iOS host tools include llvm-min-tblgen. Use Apple's libtool with the static
  archive recipe, not GNU ar flags. Pass `ios-libtool.cmake` through
  CMAKE_USER_MAKE_RULES_OVERRIDE so nested try_compile projects inherit it.
  Run a small C/C++ target archive preflight before downloads or host TableGen.
  Set CMAKE_MACOSX_BUNDLE=OFF for native dependencies. LLVM auxiliary tools
  use RUNTIME install destinations, which reject the iOS bundle default.
  Include an excluded executable with that install rule in the preflight.
  Disable WasmEdge LTO for published archives.
- Build the iOS WasmEdge interpreter before the target LLVM libraries. It has
  no LLVM dependency, so Apple runtime failures can be caught earlier.
- iOS slice identity includes source commit, SDK, dependencies, patches, headers
  and resources. Reject mismatched or duplicate slices before assembly.
- CI exports must match the current adapter interfaces. When using a publishing
  worktree, sync required native sources explicitly; never publish unrelated
  signing configuration or a broad unreviewed commit range.
- Include GPL LICENSE and retain upstream license files in downloadable packages.

### Verification

Run syntax checks and actionlint, validate Android fixtures for both ABIs,
check real OHOS bridge compilation/linking, and verify iOS slice architecture,
native dependency linking and XCFramework metadata. Compare downloaded archive
checksums and internal inventories. App/device execution is a separate gate.

Good: independently verified final packages with recorded SDK/source identity.
Base: scripts pass local checks while cloud builds remain pending.
Bad: call WASI data a complete native package or claim cloud success from lint.

Wrong: rely on distro Clang defaults for Android C++ headers. Correct: select
the packaged libc++ headers/runtime explicitly and validate before full build.
