# Shared Core UI Integration

The shared UI belongs to qflistudio-core, not to the Studio application shell.
Forge imports the shared QfliApp and configures it through StudioProfile.
Do not copy the Studio shell's pages into Forge to synchronize common UI.

Local pubspec.yaml resolves ../qflistudio-core, including that working tree's uncommitted edits. The Git HEAD alone does not describe the UI used locally.
Installer jobs instead check out one explicit CORE_REVISION. Update all seven core checkout refs and tool/ci/prepare_core.py together. Invoke the pinned core prepare_flutter_core.py on hosted runners before dependency resolution. Keep pubspec.lock aligned with the selected core dependencies.

The published core main baseline for this task is 1ae4674a4b153701b0c3b3ff04b1a1b77a318611. Its common UI includes the editor quick bar, editor/agent layout, session sidebar, chat composer and reorganized home scopes. Preview branches remain separate until explicitly selected.

Preserve Forge's offline policy, C/C++ templates, analyzer, runtime, owned content repository and tools builders. A core update must not silently enable the Studio networked product profile.

The standard Flutter CI copy patches only the Huawei platform-view widget. The OHOS job builds the original core source. Never run a compatibility patch against a dirty shared worktree.

Validation: flutter analyze; flutter test; python -m unittest discover -s tool/ci -p test_*.py. The Forge editor integration test mounts the actual shared editor at desktop and phone widths and verifies the new 25-pixel quick bar while exercising unsaved C/C++ diagnostics. Cloud packages still require platform-specific validation.
