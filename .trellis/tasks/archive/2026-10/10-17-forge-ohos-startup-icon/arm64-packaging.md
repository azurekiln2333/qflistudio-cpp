# Follow-up — ARM64-only packaging

User requested excluding x86_64 from packaging and retaining only ARM64.
Moved the x86_64 pattern from `nativeLib.debugSymbol.exclude` (strip control)
to `nativeLib.filter.excludes` (actual packaging exclusion), also excluding
armeabi-v7a. Retained CMake `abiFilters: ['arm64-v8a']`, Flutter
`--target-platform ohos-arm64`, and the existing libc++ symbol-strip exception.

Rebuilt the signed production HAP successfully. Final archive contains exactly
four native libraries, all under `libs/arm64-v8a/`: libapp.so,
libc++_shared.so, libflutter.so and libqfli_ohos_runner.so. Every ELF header is
64-bit little-endian AArch64 (machine 183). No x86_64 or armeabi-v7a paths exist
anywhere in the HAP. The existing portable package verifier also passed.

Updated artifact: `build/ohos/hap/entry-default-signed.hap`, 151351796 bytes,
SHA256 `42842f1fde02203ce3f90db744cae8c24dc98e60eb31a0067451c446873fbf30`,
bundle `com.azurekiln.qfli.cpp`. This replaces the file at the standard build
path; the earlier delivery hash remains historical. Evidence is in
`native/build/forge-arm64-package-verification-20261017.json`,
`forge-arm64-hap-verification-20261017.json` and
`forge-arm64-production-build-20261017.log`. No device install was needed for
this packaging-only follow-up. Herdr pi agents reviewed the ABI scope, archive
and installed Hvigor schema read-only. No commits or signing changes.
