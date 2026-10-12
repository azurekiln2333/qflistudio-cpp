# Approved commit handoff plan

No files have been staged or committed by this task. Implementation and independent verification are complete. The user approved this plan and explicitly chose to preserve the working tree without committing yet.

## Proposed work commit

`fix(forge): honor selected entry and simplify run titles`

Commit only the task delta recorded in [research/task-changes.patch](./research/task-changes.patch), after its runtime baseline is in Git. The patch compares against the saved pre-implementation working tree, not HEAD; its reverse check against the working tree passes.

Code and regression files:

- `android/app/src/main/kotlin/com/example/qflistudio/c/NativeCompilerBridge.kt`
- `ios/Runner/NativeCompilerBridge.mm`
- `lib/c_runner.dart`
- `lib/clang_runner.dart`
- `lib/main.dart`
- `lib/native_clang_runner.dart`
- `lib/web_clang_runner_browser.dart`
- `test/android_clang_runner_test.dart`
- `test/c_app_test.dart`
- `test/clang_runner_test.dart`
- `test/native_clang_runner_test.dart`
- `web/forge-worker.js`
- `lib/source_selection.dart`
- `lib/run_title.dart`
- `test/source_selection_test.dart`
- `test/run_title_test.dart`
- `test/fixtures/desktop_native/multi_main/helper.c`
- `test/fixtures/desktop_native/multi_main/helper.h`
- `test/fixtures/desktop_native/multi_main/main.c`
- `test/fixtures/desktop_native/multi_main/main2.c`

Specification files:

- `.trellis/spec/backend/android-runtime.md`
- `.trellis/spec/backend/desktop-runtime.md`
- `.trellis/spec/backend/index.md`
- `.trellis/spec/backend/portable-runtime.md`
- `.trellis/spec/backend/web-runtime.md`
- `.trellis/spec/backend/source-selection.md`

## Existing runtime prerequisite

The existing `10-01-cross-platform-native-runtime` task remains in progress on main, with uncommitted runtime code. These files existed before this task but are still untracked, so Git cannot commit just this task's small additions to them without also adding their complete pre-existing implementation:

- `ios/Runner/NativeCompilerBridge.mm`
- `lib/native_clang_runner.dart`
- `lib/web_clang_runner_browser.dart`
- `test/native_clang_runner_test.dart`
- `web/forge-worker.js`

The existing native/browser router split, iOS project wiring, compiler resources and verification infrastructure also remain outside this task. Including full untracked files now would silently adopt that other work and can leave an incomplete standalone commit. Only android-runtime.md is already tracked among the specification files; the other existing spec pages were local baseline documents.

## Approved decision for this session

User decision: adopt the plan and do not commit yet. Keep the reviewed implementation in the working tree without committing other runtime work. Have the original runtime task establish its baseline first; then create a task branch and stage this task's verified delta as the work commit above. The saved patch and SHA-256 inventory make that boundary reviewable. Do not push.

If the user chooses manual Git handling, leave all files available for them. Do not run finish-work/archive while this task's product changes remain uncommitted: that skill explicitly returns to Phase 3.4 in this state. No unrelated task is archived.

## Other dirty paths excluded from this plan

These are existing or independently owned changes; no consent to include them is inferred from implementation approval.

- `ios/.gitignore`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Runner-Bridging-Header.h`
- `lib/android_clang_runner.dart`
- `lib/forge_runner.dart`
- `ohos/build-profile.json5`
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets`
- `ohos/entry/src/main/resources/base/profile/main_pages.json`
- `.codex/agents/trellis-check.toml`
- `.codex/agents/trellis-implement.toml`
- `.codex/agents/trellis-research.toml`
- `.codex/config.toml`
- `.codex/hooks.json`
- `.codex/hooks/inject-subagent-context.py`
- `.codex/hooks/inject-workflow-state.py`
- `.codex/hooks/session-start.py`
- `.gitattributes`
- `.trae/agents/trellis-check.md`
- `.trae/agents/trellis-implement.md`
- `.trae/agents/trellis-research.md`
- `.trae/commands/trellis-continue.md`
- `.trae/commands/trellis-finish-work.md`
- `.trae/hooks.json`
- `.trae/hooks/inject-shell-session-context.py`
- `.trae/hooks/inject-workflow-state.py`
- `.trae/hooks/session-start.py`
- `.trae/skills/trellis-before-dev/SKILL.md`
- `.trae/skills/trellis-brainstorm/SKILL.md`
- `.trae/skills/trellis-break-loop/SKILL.md`
- `.trae/skills/trellis-channel/SKILL.md`
- `.trae/skills/trellis-channel/references/command-reference.md`
- `.trae/skills/trellis-channel/references/forum.md`
- `.trae/skills/trellis-channel/references/progress-debugging.md`
- `.trae/skills/trellis-channel/references/workers.md`
- `.trae/skills/trellis-channel/references/workflows.md`
- `.trae/skills/trellis-check/SKILL.md`
- `.trae/skills/trellis-meta/SKILL.md`
- `.trae/skills/trellis-meta/references/customize-local/add-project-local-conventions.md`
- `.trae/skills/trellis-meta/references/customize-local/change-agents.md`
- `.trae/skills/trellis-meta/references/customize-local/change-context-loading.md`
- `.trae/skills/trellis-meta/references/customize-local/change-hooks.md`
- `.trae/skills/trellis-meta/references/customize-local/change-skills-or-commands.md`
- `.trae/skills/trellis-meta/references/customize-local/change-spec-structure.md`
- `.trae/skills/trellis-meta/references/customize-local/change-task-lifecycle.md`
- `.trae/skills/trellis-meta/references/customize-local/change-workflow.md`
- `.trae/skills/trellis-meta/references/customize-local/overview.md`
- `.trae/skills/trellis-meta/references/local-architecture/bundled-skills.md`
- `.trae/skills/trellis-meta/references/local-architecture/context-injection.md`
- `.trae/skills/trellis-meta/references/local-architecture/generated-files.md`
- `.trae/skills/trellis-meta/references/local-architecture/multi-agent-channel.md`
- `.trae/skills/trellis-meta/references/local-architecture/overview.md`
- `.trae/skills/trellis-meta/references/local-architecture/spec-system.md`
- `.trae/skills/trellis-meta/references/local-architecture/task-system.md`
- `.trae/skills/trellis-meta/references/local-architecture/workflow.md`
- `.trae/skills/trellis-meta/references/local-architecture/workspace-memory.md`
- `.trae/skills/trellis-meta/references/platform-files/agents.md`
- `.trae/skills/trellis-meta/references/platform-files/hooks-and-settings.md`
- `.trae/skills/trellis-meta/references/platform-files/overview.md`
- `.trae/skills/trellis-meta/references/platform-files/platform-map.md`
- `.trae/skills/trellis-meta/references/platform-files/skills-and-commands.md`
- `.trae/skills/trellis-session-insight/SKILL.md`
- `.trae/skills/trellis-session-insight/references/cli-quick-reference.md`
- `.trae/skills/trellis-session-insight/references/triggering-patterns.md`
- `.trae/skills/trellis-spec-bootstrap/SKILL.md`
- `.trae/skills/trellis-spec-bootstrap/references/mcp-setup.md`
- `.trae/skills/trellis-spec-bootstrap/references/repository-analysis.md`
- `.trae/skills/trellis-spec-bootstrap/references/spec-task-planning.md`
- `.trae/skills/trellis-spec-bootstrap/references/spec-writing.md`
- `.trae/skills/trellis-update-spec/SKILL.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/check.jsonl`
- `.trellis/tasks/10-01-cross-platform-native-runtime/design.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/implement.jsonl`
- `.trellis/tasks/10-01-cross-platform-native-runtime/implement.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/code_editor_browser_input_test.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_io.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_io_browser.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_io_native.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_path.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_path_browser.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_path_native.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_storage_browser_test.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-platform/platform_storage_native_test.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-vendor/re_editor/lib/src/_code_editable.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-vendor/re_editor/lib/src/_code_field.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-vendor/re_editor/lib/src/_code_input.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-vendor/re_editor/lib/src/_code_shortcuts.dart`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-web.apply-patch`
- `.trellis/tasks/10-01-cross-platform-native-runtime/patches/shared-core-web.patch`
- `.trellis/tasks/10-01-cross-platform-native-runtime/prd.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/browser-editor-input.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/ios-runtime.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/platform-audit.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/platform-status.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/wasm-compatibility.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/web-boundary.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/task.json`
- `AGENTS.md`
- `ios/Runner/NativeCompilerBridge.h`
- `ios/scripts/copy-portable-resources.sh`
- `lib/forge_runner_browser.dart`
- `lib/forge_runner_native.dart`
- `lib/web_clang_runner.dart`
- `lib/web_clang_runner_stub.dart`
- `native/compiler/CMakeLists.txt`
- `native/compiler/compiler.cpp`
- `native/compiler/include/qfli_compiler.h`
- `native/compiler/tests/compiler_probe.cpp`
- `native/include/qfli_wasm_limits.h`
- `native/portable/.gitattributes`
- `native/portable/CMakeLists.txt`
- `native/portable/README.md`
- `native/portable/apply-wasmedge-patch.cmake`
- `native/portable/include/qfli_wasm.h`
- `native/portable/patches/wasmedge-interruptible-poll.patch`
- `native/portable/patches/wasmedge-static-archive.patch`
- `native/portable/tests/runtime_probe.cpp`
- `native/portable/tests/verify-sleep.sh`
- `native/portable/wasm_runtime.cpp`
- `native/toolchain/README.portable.md`
- `native/toolchain/build-ios-portable.sh`
- `native/toolchain/build-web-portable.sh`
- `native/toolchain/portable-dependencies.json`
- `native/toolchain/prepare-portable-wasm.ps1`
- `native/toolchain/verify-linux-desktop.sh`
- `native/toolchain/verify-portable-wasm.sh`
- `native/web/.gitignore`
- `native/web/CMakeLists.txt`
- `native/web/README.md`
- `native/web/check-shared-core-patch.mjs`
- `native/web/compiler_web.cpp`
- `native/web/package-lock.json`
- `native/web/package.json`
- `native/web/prepare-emsdk.ps1`
- `native/web/prepare-runner-browser-tests.mjs`
- `native/web/stage-forge-review.mjs`
- `native/web/stage-shared-core-patch.mjs`
- `native/web/tests/fixtures.mjs`
- `native/web/tests/verify-compiler-browser.mjs`
- `native/web/tests/verify-forge-browser.mjs`
- `native/web/tests/verify-wasi-browser.mjs`
- `native/web/tests/wasi-browser-worker.js`
- `native/web/tests/wasi-node-worker.mjs`
- `native/web/tests/wasi.test.mjs`
- `native/web/tests/web_runner_browser_test.dart`
- `native/web/web-dependencies.json`
- `ohos/entry/src/main/ets/pages/AgreementReader.ets`
- `test/fixtures/desktop_native/cancel/main.c`
- `test/fixtures/desktop_native/io/input.txt`
- `test/fixtures/desktop_native/io/main.c`
- `test/fixtures/desktop_native/link_error/main.c`
- `test/fixtures/desktop_native/math/input.txt`
- `test/fixtures/desktop_native/math/main.c`
- `test/fixtures/desktop_native/mixed_c_main/helper.cpp`
- `test/fixtures/desktop_native/mixed_c_main/include/helper.h`
- `test/fixtures/desktop_native/mixed_c_main/main.c`
- `test/fixtures/desktop_native/nonzero/main.c`
- `test/fixtures/portable_wasm/exceptions/main.cpp`
- `test/fixtures/portable_wasm/files/data/input.txt`
- `test/fixtures/portable_wasm/files/main.c`
- `test/fixtures/portable_wasm/memory/main.c`
- `test/fixtures/portable_wasm/sleep/input.txt`
- `test/fixtures/portable_wasm/sleep/main.c`
- `test/fixtures/portable_wasm/trap/main.c`
- `tool/android_native_audit.dart`
- `web/.gitignore`
- `web/forge-wasi.js`
- `web/toolchain/.gitignore`
