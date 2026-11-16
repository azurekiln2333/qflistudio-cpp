# Design

Retain a single repository and use a test branch `ci/native-artifacts`.
Use `ubuntu-24.04` to avoid moving runner aliases. Split Android ABIs into
independent jobs with fail-fast disabled. Build LLVM 15 host TableGen, then
cross-compile the target compiler/linker with the fixed Android NDK. Reuse the
existing package validator after adding explicit Linux host-tool paths.

The cloud bootstrap lives in a Linux Bash script. Existing Windows builds keep
their current entry points and defaults. Package only jniLibs, assets, validation
reports, licenses/provenance and checksums; omit intermediate object trees.

Build the WASI data ZIP in a separate job using pinned dependency archives and
the existing PowerShell packager and Python validator. It needs no OHOS SDK and
does not include OHOS compiler/runtime libraries or an installable HAP.

Actions artifacts expire, so document retention. The workflow summary names
each payload and links to its run. Do not use a local self-hosted runner: that
would retain the user's disk burden. Do not upload local SDKs or signing files.

The legacy OHOS entry point accepts a custom `package-llvm.ps1` layout backed
by local SDK 26.0.0.105. Add a raw-native-SDK entry point so cloud builds do not
require the obsolete target Clang executable. Pin the chosen public SDK archive
and record the SDK version; do not claim equivalence to the existing local SDK.

Build iOS slices in separate macOS jobs and assemble the verified slices into
an XCFramework. Keep platform archive paths compatible with the current app.
Generate xcconfig locally after download, never ship a runner-absolute path.

Android resource preflight must run before full compiler/linker compilation.
Set the packaged libc++ include and library choice explicitly because Ubuntu
Clang has different defaults from the NDK's Windows Clang.
