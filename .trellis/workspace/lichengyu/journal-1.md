# Journal - lichengyu (Part 1)

> AI development session journal
> Started: 2026-09-30

---



## Session 1: Forge tools and OHOS LLVM package
<!-- trellis-session: v=2 fp=a74c24c8afb30a17 -->

**Date**: 2026-09-30
**Task**: Forge tools and OHOS LLVM package
**Branch**: `main`

### Summary

Completed Forge tools, replaced the legacy C++ placeholder, built ARM64 Clang/LLD, and verified the portable OHOS headers/runtime package. User requested no further device debugging.

### Main Changes

- Integer conversion, fixed-width bit operations, and searchable ASCII tools use existing navigation.
- LLVM build supports arm64-v8a and x86_64; packaging validates ELF architecture, dependencies, version, and hashes.

### Git Commits

| Hash | Message |
|------|---------|
| `59aeb05` | feat(forge): add integer conversion bit operations and ASCII tools |
| `12d7ea7` | fix(forge): replace legacy C++ placeholder with native compiler runner |
| `e724903` | build(toolchain): package OHOS LLVM with headers runtimes and verification |

### Testing

- [OK] 40 Flutter tests passed; Flutter analyze reported no issues.
- [OK] ARM64 Clang and LLD built successfully; x86_64 configuration and architecture rejection passed.
- [OK] Clang 15.0.7 host cross compilation passed C headers, C++20 standard library, exceptions, and mixed C/C++ linking with the packaged configuration.

### Status

[OK] **Completed**

### Next Steps

- Integrate the toolchain into the actual HarmonyOS App runtime. App execution, output streaming, and cancellation remain unverified; retain the existing C fallback until the replacement is proven.
- Device debugging was stopped at user request. ARM64 archive: native/build/qfli-forge-llvm-15.0.7-ohos-arm64.tar.gz (63511308 bytes); SHA256 2854cf2a57c59439b1fa26ead01a113550ecb6db0b85e1aa87d7e44b0d4540e4.


## Session 2: Android LLVM runtime and native startup progress
<!-- trellis-session: v=2 fp=83dad13f33c60e29 -->

**Date**: 2026-10-01
**Task**: Android LLVM runtime and native startup progress
**Branch**: `main`

### Summary

Completed Android LLVM C/C++ integration, dual-ABI packaging and native startup progress based on qflistudio. Local validation only; device debugging and HarmonyOS execution were not performed.

### Main Changes

- Packaged actual LLVM 15.0.7 ARM64/x86_64 compilers, LLD, resources and isolated executor.
- Added asynchronous Android compilation/output/cancel bridge and streaming Dart client.
- Normalized resource ZIP entry paths for Windows PowerShell 5 and added an APK rejection gate.
- Added native startup icon/progress with matching light/dark backgrounds; defer Flutter until bootstrap and home layout finish.

### Git Commits

| Hash | Message |
|------|---------|
| `a3c1d4b` | build(android): package LLVM toolchains and verify APK artifacts |
| `2a16d36` | feat(android): run C and C++ with packaged LLVM |
| `398b093` | fix(android): normalize LLVM resource archive paths |
| `4f86187` | fix(android): keep native startup progress until Flutter renders |

### Testing

- [OK] All 56 Flutter tests and Flutter analyze passed.
- [OK] Final Android assembleDebug and lint passed, with zero lint errors and one existing resource-directory warning.
- [OK] Each ABI passed eight cross-linked fixtures, four exported main checks and two compiler/linker error gates.
- [OK] Windows PowerShell 5 verifier passed final APK ELF architecture, dependencies, loader, hashes, resources and 16 KB alignment.

### Status

[OK] **Completed**

### Next Steps

- Device execution, SELinux, actual page-size behavior and startup visuals remain unverified under the user's no-debugging instruction.
- APK: build/app/outputs/flutter-apk/app-debug.apk (189218686 bytes), SHA256 883c7ee2c18690535dce71fa8c80e67cdfcf5941bc4ce3373c8b57d8ae1f76c3.
