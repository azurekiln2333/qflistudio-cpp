# Native artifacts on GitHub Actions

## User authorization

On 2026-11-17 the user asked to implement a GitHub workflow and try a real
cloud build. This authorizes implementation, publishing a test branch, and
running Actions. Preserve the existing eight local commits without rewriting
history. Do not delete local packages or publish local SDK/signing material.

## Requirements

- Explain current Android, OHOS, Web, iOS and desktop native package availability.
- Explain that OHOS App packaging imports existing compiler/runtime archives
  while still compiling and linking its native bridge.
- Build Android ARM64 and x86_64 native packages on GitHub-hosted runners from
  pinned upstream sources and NDK 27.0.12077973.
- Produce the existing checksum-verified OHOS WASI resource ZIP independently.
- Keep platform artifacts separate and provide checksums, source revision,
  validation evidence, and exact download instructions.
- Do not imply that the resource ZIP is the full OHOS native library package.
- Build full OHOS ARM64 compiler/runtime archives from a pinned public native
  SDK, recording its version independently of the existing local SDK.
- Build iOS device ARM64 and simulator ARM64/x86_64 archives on macOS, then
  assemble an XCFramework with WASI resources and a local installation helper.
- Preserve native package consumption paths. Web binaries and signed app
  installers remain outside the native dependency workflow.

## Acceptance

- Relevant local syntax and regression checks pass.
- A real workflow run is observed and its outcome recorded.
- Successful artifacts are inspected and their contents documented.
- Failures are diagnosed and corrected where possible; incomplete builds are
  reported honestly, separately from existing local packages.

## Clarification on 2026-11-17

The user explicitly rejected the initial partial scope and requested complete
OHOS, iOS and Android native builds. Correct the Linux Android C++ standard
library configuration and run resource preflight before full LLVM compilation.
Do not delete local directories: provide a measured cleanup list and retain
the currently consumed Android/OHOS packages until replacements are verified.
