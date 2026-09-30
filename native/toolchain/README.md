# LLVM Toolchain Build

This directory builds upstream LLVM 15.0.7 for an AArch64 OHOS device. It is
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

The host recipe stages GCC frontends and their DLLs together and uses `-B` to
select that directory. This handles installations where frontends in the GCC
library directory cannot start. GCC 16 also needs an explicit `<cstdint>`
include when building these older LLVM headers. These adjustments leave the
upstream source and the MSYS2 installation unchanged.

The OHOS configuration uses `-Qunused-arguments`: the SDK injects an unused
`--gcc-toolchain` argument, which otherwise makes LLVM's `-Werror` capability
probes fail, including its `-fPIC` probe. The script requires both PIC probes
to pass and checks that the host TableGen tools start and report LLVM 15.0.7.

## Validation Boundary

The host TableGen tools have been built and started. The OHOS configuration
passes the C/C++ PIC probes. The target compiler build, device execution,
sysroot packaging, and App integration are separate acceptance gates.

An ARM64 ELF that runs under `hdc shell` does not establish that an ordinary
phone application can launch it. The SDK's `childProcessManager` API does not
support phones or arbitrary executables. The existing App therefore must not
declare the native compiler available solely because this build succeeds.

Upstream LLVM 15 has no OHOS driver specialization. A device compiler still
needs explicit sysroot, C++ include, runtime library, and linker configuration;
setting its default target triple alone is insufficient.
