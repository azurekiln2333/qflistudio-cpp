# Evidence

## Current repository and inherited UI

- qfli_c/pubspec.yaml:13-14 and qfli_java/pubspec.yaml:13-14 point at ../qfli_studio_core.
- Shared lib/editor/editor_page.dart:717 defines runProject(entryOverride); line 750 selects override before default; line 809 forwards entryFile; line 876 runs the active saved file; line 1063 wires onLongPress.
- Shared lib/editor/terminal_pane.dart:608 attachOutput appends a command, preserves stdout/stderr and emits an exit line only when code != 0 (line 651).
- Shared lib/editor/terminal_pane.dart:879 uses one ListView whose last row is the prompt. Lines 915-969 draw that prompt without a separate input card.
- Shared test/terminal_pane_test.dart and test/editor_run_test.dart already cover inherited behavior and are actively owned by the Java session.

## C-specific gaps

- lib/clang_runner.dart:64 and 383 collect all source units without reference to entryFile.
- lib/clang_runner.dart:320 and 376 render backend labels in user-facing run titles.
- lib/c_runner.dart:69 discovers all C units; its run titles also contain interpreter labels.
- lib/native_clang_runner.dart:107 sends entryFile but no selected list; line 144 renders backendName.
- Android NativeCompilerBridge.kt:148/183 and iOS NativeCompilerBridge.mm:144/183 independently enumerate all sources.
- web/forge-worker.js:32 collects every translation unit from the complete project file set.
- The selected entry must affect compiled input, not only the displayed run title.

## Baseline checks reported by pi

pi's first research round ran c_app_test, native_clang_runner_test and android_clang_runner_test: 41 passed. Desktop/compiler coverage is being inspected separately. Treat this as reported baseline evidence until the final verification is rerun/reviewed.

## Coordination

User explicitly requested Herdr plus pi. Main pane w6:p1; task pi pane w6:p2, name pi-c-terminal. Java/shared core is being handled by an existing independent session; do not overwrite or stage its files.