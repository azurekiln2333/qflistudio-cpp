# Validation and cloud evidence

## Selected sources

- Application base: github/main 1969ef40d69134e45eaab6b558d71b96cf9be68a.
- Core: published main cbaa4a4166461baafff7c1a343bd3ca1865fcc4f.
- Native input: successful main run 44001588302, all four mobile native packages unexpired.
- Preview core 72c0b09 is not included.
- Isolated application: D:/MyNewProjects/_wt/qfli-c-ui-sync/qfli_c.
- Isolated core: D:/MyNewProjects/_wt/qfli-c-ui-sync/qfli_studio_core.
- Original app/core dirty worktrees remain intact.

## Local validation

- flutter pub get: success; lock adds crypto, web_socket and web_socket_channel.
- flutter analyze against original selected core: no issues.
- flutter test --concurrency=2: 217 tests passed.
- Updated real-editor regression: desktop C and phone C++ tests pass with the new 25-pixel quick bar and unsaved diagnostics.
- Python CI helpers: 89 tests passed.
- Actual selected-core stock compatibility patch --check and application: passed.
- Workflow YAML: six jobs present, Android ABI matrix produces seven packages.

Installed local SDK is the existing OHOS Flutter build with Dart 3.11.5. The workflow's pinned official Flutter and macOS/Linux/iOS builds require cloud execution. No device UI or runtime acceptance is implied.

## Cloud run

Pending publication and dispatch.
