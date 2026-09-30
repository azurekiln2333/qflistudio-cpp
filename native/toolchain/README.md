# LLVM Toolchain Build

This directory builds upstream LLVM 15.0.7 for ARM64 OHOS devices and x86_64
OHOS emulators. It is
separate from the legacy picoc bridge in `native/src/`.

## Requirements

- Windows with PowerShell, Git, and an MSYS2 MinGW64 GCC installation.
- A DevEco OHOS Native SDK containing Clang, CMake, Ninja, and the OHOS sysroot.
- Two concurrent compiler jobs are the default. Large Clang translation units
  need substantially more memory than the host TableGen build.

The source is pinned to `llvmorg-15.0.7`, commit
`8dfdcc7b7bf66834a761bd8de445840ef68e4d1a`. Existing checkouts must match the
commit and have no source changes. The script never resets an existing checkout.
The default build directory, `native/build/`, is ignored by Git.

## Build

Run from the repository root, replacing the SDK and MSYS2 paths:

```powershell
./native/toolchain/build-llvm.ps1 `
  -NativeSdk 'D:/ProgramFiles/Huawei/DevEco Studio/sdk/default/openharmony/native' `
  -MsysRoot './native/build/msys64'
```

Use `-SourceRepository https://gitee.com/mirrors/llvm-project.git` to retrieve
the same pinned source from the mirror. A pre-existing checkout is reused
without network access.

`-Stage Host` builds `llvm-tblgen.exe` and `clang-tblgen.exe` for Windows.
`-Stage Target` reuses those tools and builds `bin/clang` and `bin/lld` for
OHOS. `-ConfigureOnly` configures the selected stage without compiling it.
For `-Stage All -ConfigureOnly`, the host tools must already have been built.
Use the script for incremental builds as well: it restores the MSYS2 DLL
search path needed by TableGen during target compilation.

`-TargetArchitecture arm64-v8a` is the default. For an x86_64 emulator, use
`-TargetArchitecture x86_64 -Stage Target` with the same host TableGen tools.
Each architecture gets its own build directory (`llvm-ohos-arm64` or
`llvm-ohos-x86_64`) and matching backend and default target triple. The script
rejects a build directory already configured for another architecture.
Run `hdc shell uname -m` to select the architecture of the validation device.
Use `-Jobs 1` when memory is limited; do not run Flutter tests alongside the
LLVM compilation under memory pressure.

The host recipe stages GCC frontends and their DLLs together and uses `-B` to
select that directory. This handles installations where frontends in the GCC
library directory cannot start. GCC 16 also needs an explicit `<cstdint>`
include when building these older LLVM headers. These adjustments leave the
upstream source and the MSYS2 installation unchanged.

The OHOS configuration uses `-Qunused-arguments`: the SDK injects an unused
`--gcc-toolchain` argument, which otherwise makes LLVM's `-Werror` capability
probes fail, including its `-fPIC` probe. The script requires both PIC probes
to pass and checks that the host TableGen tools start and report LLVM 15.0.7.

## Package

After the target build finishes:

```powershell
./native/toolchain/package-llvm.ps1 `
  -NativeSdk 'D:/ProgramFiles/Huawei/DevEco Studio/sdk/default/openharmony/native' `
  -TargetBuildDirectory './native/build/llvm-ohos-arm64'
```

For x86_64, also pass `-TargetArchitecture x86_64` and the corresponding build
directory. The output must be a fresh directory. The script checks LLVM version,
ELF architecture, and dynamic dependencies before copying the compiler/linker.
It includes Clang builtin headers, OHOS C headers and libraries, libc++ headers,
libc++/libunwind, compiler-rt builtins/startup objects, and upstream/SDK notices.
`toolchain.json` records target information, dependencies, and binary hashes.

The generated `bin/ohos.cfg` resolves paths relative to itself with Clang's
`<CFGDIR>` substitution, so the directory can be moved without rewriting it.
It selects the OHOS platform macros, sysroot, libc++, compiler-rt, LLD, and OHOS dynamic loader
explicitly. Use the packaged compiler as follows on a compatible OHOS system:

```sh
export LD_LIBRARY_PATH="/path/to/toolchain/lib/aarch64-unknown-linux-ohos"
chmod 755 /path/to/toolchain/bin/clang /path/to/toolchain/bin/ld.lld
/path/to/toolchain/bin/clang --config ohos.cfg -std=c17 main.c helper.c -Iinclude -o program
/path/to/toolchain/bin/clang --config ohos.cfg --driver-mode=g++ -std=c++20 main.cpp helper.cpp -Iinclude -o program
```

Use `x86_64-unknown-linux-ohos` in `LD_LIBRARY_PATH` for the emulator package.
Only the actual C++ runtime directory belongs in `LD_LIBRARY_PATH`; the
sysroot's shared libraries are link-time SDK stubs and must not be loaded.
The examples above describe toolchain invocation, not an App execution gate.

`sh native/toolchain/verify-toolchain.sh /path/to/toolchain` verifies multi-file
C, project headers, C++20 standard library containers/algorithms/exceptions,
mixed C/C++ linking, exit status, and output. Use `--compile-only` when cross
compiling locally. `CLANG` and `LLD` can select host executables for that check;
this validates the packaged headers/libraries/configuration independently of
running the newly built OHOS compiler. Verification artifacts are retained in
the printed temporary directory.
Use a host Clang 15.0.7 for this check. Newer Clang releases have different OHOS
driver/runtime lookup rules. Clang 15 requires separate `--config` and path
arguments, rather than `--config=path`.

## Validation Boundary

The host TableGen tools have been built and started. Both OHOS architectures
pass the C/C++ PIC probes. Target compiler builds, package inspection, execution,
and App integration are separate acceptance gates.

An ARM64 ELF that runs under `hdc shell` does not establish that an ordinary
phone application can launch it. The SDK's `childProcessManager` API does not
support phones or arbitrary executables. The existing App therefore must not
declare the native compiler available solely because this build succeeds.

Upstream LLVM 15 has no OHOS driver specialization. A device compiler still
needs explicit sysroot, C++ include, runtime library, and linker configuration;
setting its default target triple alone is insufficient. The SDK libc++ headers
also require `__OHOS__` and `__OHOS_FAMILY__`, which the configuration supplies.
