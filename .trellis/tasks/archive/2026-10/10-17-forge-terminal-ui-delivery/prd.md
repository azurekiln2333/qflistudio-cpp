# Forge OHOS terminal and shared UI delivery

User authorized implementation, collaboration through several pi workers, build and device delivery. Target is OHOS nova 14 Ultra, HDC [LAN endpoint omitted]:46551. Do not build or install Android.

Requirements: make clang/clang++ terminal commands call the actual bundled compiler; support version/help, explicit C/C++ source arguments, compile output and subsequent ./program execution; preserve diagnostics, statuses and cancellation. Preserve existing editor Run behavior. Include current shared-core About, main tab title colors and My page. Preserve user data and unrelated work.

Acceptance: focused command and bridge tests, static analysis, signed production lib/main.dart HAP, artifact verification, install -r on the named phone and actual terminal/UI smoke checks. Record exact scope and limitations. No Git commits or pushes are requested.
