# Cross-platform native C/C++ runtime

## Goal

Complete Forge's C/C++ runtime paths and report verification separately for
each platform. The current acceptance pass covers OHOS app execution and
Android artifact builds in `qfli_c`; other language applications are outside
this workspace's scope. Older iOS/Web work remains recorded separately.

## Background

- Android has a packaged LLVM compiler and isolated native executor from the
  archived `10-01-mobile-llvm-runtime` task.
- Windows, Linux and macOS already invoke installed or bundled Clang/GCC.
  Their source discovery currently omits C++ units when the entry file is C.
- iOS has a default Flutter application delegate and no native runtime channel.
  C currently falls back to the Dart interpreter; C++ reports unavailable.
- Web has a generated platform scaffold, but project storage and process
  execution depend on `dart:io` in both Forge and the sibling shared core.
- The legacy picoc bridge is OHOS-only and its third-party sources are absent.
  It is not an implemented cross-platform native interpreter.

## Requirements

- R1: Audit OHOS, Android, Windows, Linux, macOS, iOS and Web against the actual
  execution paths. Distinguish existing implementation, missing integration,
  platform restrictions and unavailable test environments.
- R2: Complete missing native runtime support within the reviewed platform
  scope; preserve compilation diagnostics, exit status, stdin and cancellation.
- R3: Support C/C++ projects containing multiple translation units, including
  either direction of mixed C/C++ source files and project headers.
- R4: Verify real compilation and execution where the current environment
  permits it. Record why other platform tests are skipped. Build success alone
  must not be reported as runtime verification.
- R5: Under the user's 2026-10-15 instruction, perform actual OHOS app
  verification. Android verification is build-only: do not push, install or
  run on an Android device.

## Acceptance Criteria

- [x] AC1 (R1): A platform matrix identifies each actual backend and test status.
- [ ] AC2 (R2, R3): Implemented native backends execute C, C++ and mixed projects
  according to their documented language capabilities.
- [ ] AC3 (R2): Syntax/link failures do not run stale binaries or silently switch
  interpreters; input, nonzero exits and cancellation remain observable.
- [ ] AC4 (R4): Locally runnable native paths pass focused real execution tests.
  Unavailable platform testing is explicitly recorded as skipped.
- [ ] AC5 (R5): Actual OHOS app compilation/execution and ordinary editor
  Run/Stop pass on the authorized phone.
- [x] AC6 (R5): Android release artifacts are built and inspected without
  Android device actions (ARM64 + x86_64, 2026-10-15).

## Current acceptance scope and authorization (2026-10-15)

The user explicitly requested finishing this runtime work, full OHOS testing,
Android builds without device push, complete Trellis records and conventional
Git commits after verified logical changes. This supersedes the earlier
no-OHOS-device and no-commit constraints. The connected nova 14 Ultra is the
previously authorized phone; keep all repository writes in
`D:/MyNewProjects/qfli_c`. Do not modify sibling workspaces or their curricula.

The user separately added C/C++ tutorial/example auditing, with conditional
replacement only if placeholder data remains. That work continues under
`10-12-c-cpp-substantive-curriculum`. Other language content is out of scope.
Older iOS/Web acceptance evidence remains separate from the current OHOS and
Android acceptance and must not be represented as newly verified.

## Scope and Assumptions

- Keep all writes in `D:/MyNewProjects/qfli_c`. Shared-core live curriculum
  assets may be inspected read-only for the separately authorized audit.
- iOS and Web are included in the platform inventory and remain unfinished
  acceptance items. A native C-only interpreter does not satisfy C++ support.
- Compiler/runtime dependency selection must preserve C++ language behavior;
  do not silently disable exceptions to obtain an easier passing smoke test.

## Implementation Authorization

The user requested implementation of missing runtime support, approved task
creation, and continued the active goal. The confirmed desktop fixes are
reversible work within that request. Continue them without requesting another
process approval; retain the full platform requirements during later iterations.

## Constraints

- Do not change the sibling `qfli_studio_core` without accounting for its
  separate ownership and workspace permission boundary.
- Preserve existing user changes under `ohos/` and unrelated configuration.
- macOS/iOS compilation and device execution require Apple build tools that
  are unavailable on this Windows host.
- The working WSL distribution is `qfli-java-build`, with GCC/G++ 13.3.0 and
  CMake. Ubuntu cannot mount its missing VHDX. There is no Linux Dart/Flutter SDK
  in the working distribution; the PATH entries refer to the Windows SDK.
