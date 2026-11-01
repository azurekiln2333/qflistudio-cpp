# Execution

- [x] pi Dart/ArkTS: wire profile delegate, native event reuse, command parsing, routing and focused regression tests.
- [x] pi native: implement actual compiler command API, NAPI terminal, persistent Wasm output and interpreter execution; incremental archive rebuild.
- [x] pi core: verify About, header colors and My page against current core, add meaningful regression checks and report minimal needed fixes.
- [x] Root: refresh local path resolution, inspect all changes and integrate workers.
- [x] Run focused/full appropriate checks; build signed OHOS production HAP and verify packaged artifacts.
- [x] Install preserving data on 192.168.68.207:46551; verify terminal commands and UI, record delivery.

Herdr coordination: forge-native (w6:p4), forge-terminal (w6:p5), forge-core
(w6:p7). See delivery.json and delivery.md for exact build/device evidence.
