# OHOS native startup and icon

The OHOS application must launch through a native ArkUI splash matching JVMX, using the current C mascot and real initialization progress. Keep the native view until the saved theme and home page are laid out. The delivered launcher, native splash and About icon must all use the current artwork.

Acceptance: signed production HAP builds; Dart startup and ArkTS checks pass; HAP bundle remains `com.azurekiln.qfli.cpp`; install with replacement on the authorized nova 14 Ultra without uninstalling; capture native startup and verify usable home/About after startup. Preserve compiler, terminal, Android behavior, signing and unrelated edits. Use three Herdr pi agents for implementation/review. No commits or pushes.
