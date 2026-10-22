# Shared-core audit — 2026-10-22

Scope: read-only source/test inspection of `../qfli_studio_core` for R3, R5, R6 and R7. Audited core HEAD: `6441a5a` (`fix(core): release idle code focus and preserve terminal cancellation`). `git status --short` was empty. No Flutter command was run because the root worker owns the active validation process. Test names below describe checked-in coverage, not newly obtained passing results. Only this report was written.

## Requirement findings

| Requirement | Current implementation evidence | Conclusion |
| --- | --- | --- |
| R3 language chips, combined filters, title circles | `lib/pages/local_content_pages.dart`: `LocalTutorialsTab`, `ExampleCodeTab`, `_TutorialList`, `_ExampleCodeList`, `_LessonPage`, `ExampleDetailPage` render plain lazy lists and text titles. There is no search field, language/level chip or language badge in these surfaces. | Missing. |
| R5 actual diagnostics, underlines and Problems | `lib/editor/editor_page.dart:2357` creates `CodeEditor` with line numbers and folding; no analyzer or diagnostics state is supplied. `lib/editor/open_file.dart` stores controller/revision/dirty state only. No Problems panel or breakpoint implementation exists in `lib/`. | Missing. Compilation errors currently appear as terminal stderr only after a run or explicit compiler command. |
| R5 language highlighting | `lib/editor/highlight_themes.dart:27` registers C, C++, Dart, Java, Python, Kotlin, JavaScript, CSS, XML/HTML, JSON, Markdown. Extension map at line 41 omits several shipped standalone languages. | Partial; Rust, Go, Lua, Shell and SQL have no built-in registration. TypeScript/TSX use JavaScript grammar. |
| R6 expansion persistence | `lib/editor/file_explorer.dart:119` initializes root but does not restore expansion; `_restoreExpanded` is called only by `_switchProject`. | A concrete reopening regression is present despite saved history support. |
| R6 multi-root workspace | `FileExplorer` has one `_browsing` project and one `_root`; header dropdown switches roots. No workspace entity, membership persistence, simultaneous roots or root-scoped tree state exists. | Missing; switching projects is not a multi-root workspace. |
| R7 Terminal | `lib/editor/terminal_pane.dart`, `lib/terminal/shell/sandbox_shell_backend.dart` and `StudioProfile.terminalCommandDelegate` implement real local shell/file operations and product toolchain commands. Output, cancellation, cwd and per-session history are present. | Substantive existing implementation; preserve and extend it. |
| R7 Output / Debug Console / Ports | `_BottomPanel` at `editor_page.dart:51` has only `none, terminal, ai`. Web preview `debugStream` is appended to terminal. `LocalWebServer` actually binds loopback and exposes its port; no local services registry/panel exists. | Separate useful panels are missing. There is real preview log/port evidence to surface. |
| R7 breakpoint/step debug | `ProgramRunner` exposes only run and output/cancel. `NativeRuntime` exposes probe/compile/run/cancel/dispose, no debug protocol/session. | No actual backend to connect to controls. Debug UI must wait for a concrete runtime capability. |

## R3: data path and compatibility

- `lib/content/content_repository.dart:43` already supports compound language/type/product filtering through `ContentFilter`; its predicate combines constraints. `ContentEntry` retains `language`, `type`, `level`, title, summary and concepts.
- `lib/content/local_content_adapter.dart` is the common local-page boundary. A standalone profile uses `ContentFilter.forProduct`; Forge therefore deliberately loads C and C++ together. `loadTutorial` maps each entry's `type` to each `TutorialLesson`, and `loadExamples` maps it to each `ExampleCode`.
- The adapter discards `ContentEntry.level`. `TutorialChapter` has no language/type/level fields and each legacy lesson/example has only `type`, so a level filter cannot currently work without propagating metadata or using typed content rows directly.
- `qfli_c/lib/main.dart` configures both `ProjectTemplate.c` and `.cpp`, a product-owned content repository and `showHomeTabs: false`. That flag only hides the existing Home project language chips; it does not implement content filtering.
- `lib/widgets/project_card.dart:165` renders a small rounded language label next to a project title. Extract/reuse a shared language label widget to make list/detail labels consistent, with explicit `C` and `C++` display names, rather than exposing raw `cpp`.
- Preserve lazy row construction and repository sharing. Existing tests `test/local_content_lazy_catalog_test.dart`, `test/asset_content_performance_test.dart`, `test/content_idle_frames_test.dart`, `test/home_content_repository_test.dart` verify important catalog performance behavior. Current lazy-catalog tests assert exact 102/101 delegate lengths, which may need intentional updates when adding filter rows.
- Necessary new behavioral coverage: C/C++ selection changes visible lessons and examples; language + query + level intersect; resetting filters restores all; badges survive opening detail routes; search handles no results; content renders at narrow widths and larger text; saved example code remains editable.

Exact compatible metadata changes for the immediate R3 batch:

- Extend `TutorialLesson` and `ExampleCode` in `lib/models/tutorial.dart` with optional `String level = ''` (and optionally `String language = ''` when distinguishing language from content type), avoiding required-argument breakage in all sibling apps and fixture constructors.
- In `LocalContentAdapter.loadTutorial`, pass parent `TutorialContent.level` / `.language` into each mapped lesson. In `loadExamples`, pass `ExampleContent.level` / `.language` into each mapped `ExampleCode`. Preserve the existing `type` mapping for import/runtime dispatch.
- Preserve metadata through `ExampleCode.copyWith`, `ExampleCodeStore._toJson` / `_fromJson`, `TutorialService._lesson` / `_example`, the service's lesson-to-example fallback, and `_LessonPage`'s construction of a snippet `ExampleCode`. Legacy saved JSON must default missing metadata safely; a saved code override should still get current bundled row metadata by stable ID rather than erase level filtering.
- A minimal shared badge contract can be `LanguageBadge({required String type})` plus a normalized language display-name helper. Render C as `C`, cpp/c++ as `C++`, preserve other supported display names. Existing ProjectCard styling uses `secondaryContainer`, horizontal padding 7, vertical padding 2, radius 20, `labelSmall` size 10, and `onSecondaryContainer`; extracting this exact code avoids divergent badges.

Follow-up observation: root began editing `file_explorer.dart` / `project_history.dart` after this baseline inspection. Findings above intentionally record HEAD behavior and must be checked against root's final diff before using this report as completion evidence.

## R5: practical analyzer integration without executing code

- `lib/services/studio_profile.dart:99` is the existing product adapter contract. Add an optional typed analysis provider beside `runner`, `terminalCommandDelegate` and `editorFileTools`. Product implementations own compiler/interpreter facts; core owns scheduling, Problems, source navigation and decoration.
- Existing `ProgramRunner` / `ProgramRunResult` (`studio_profile.dart:294`) cannot be reused safely for analysis: its purpose is to run code and it has no structured location/range/revision result.
- `lib/runtime/native_runtime.dart` supplies useful compile request concepts (`projectPath`, `entryFile`, `sources`, timeout), but `RuntimeCompileResult` has only a text diagnostics string. It is not connected to `StudioProfile` or the editor. Keep source analysis distinct from compiling/running an executable.
- A suitable request includes canonical owner root, active file/type, bounded snapshots of all relevant dirty buffers and a request generation/revision. Results need path, 1-based line/column or a precisely defined zero-based range, severity, message, source/code, optional related locations and backend availability. Document coordinate conversion and UTF-8 compiler columns versus Dart UTF-16 offsets. Ignore stale results and never persist transient diagnostics into user source files.
- The editor's `OpenFile.revision` and `EditorController.onContentChanged` are already usable invalidation hooks. Respect read-only history snapshots, close/dispose, tab switches and per-root ownership. Debounce content changes; selection-only notifications must not trigger analysis.
- A vendor fork is **not required** for wavy spans: `vendor/re_editor/lib/src/code_line.dart:3` defines `CodeLineSpanBuilder`, with context, line index, `CodeLine`, highlighted `TextSpan` and style; `_code_line.dart:1954` invokes it after highlighting. Construct `CodeLineEditingController(codeLines: CodeLines.fromText(content), spanBuilder: ...)` in `OpenFile` instead of `.fromText`. Split/compose existing highlighted spans at diagnostic ranges while preserving token styles, and apply `TextDecoration.underline` / `TextDecorationStyle.wavy`. Use `forceRepaint()` after diagnostic changes. Verify folded/empty/Unicode/overlapping ranges and syntax colors are preserved.
- `CodeEditor.indicatorBuilder` already receives visible paragraphs and is a later seam for real breakpoint markers when a debugger backend exists. Its availability alone does not constitute a debugger.
- `lib/editor/editor_page_diag.dart` is disabled-by-default temporary focus/tab-bar tracing, not code diagnostics. Do not count it toward R5.
- Forge's current terminal compiler parser in `qfli_c/native/compiler/compiler.cpp` supports compilation/preprocessing/assembly but rejects unrecognized flags. `-fsyntax-only` is not accepted by that parser today. A dedicated analysis path or a carefully bounded syntax-only extension is required; do not just call the run route. The existing in-process compiler emits text diagnostics through a borrowed FD and serializes compilation, which is a useful product-owned backend starting point.
- Necessary new coverage: invalid C/C++ syntax produces precise diagnostics without a source side effect; includes resolve against a snapshot/project root; an infinite-loop source is diagnosed without executing; stale results cannot annotate a newer buffer; failures have actionable availability feedback; Problems click selects the correct owner-root file and range.

## Highlighting gaps and existing verification

`HighlightThemes.themeFor` honors custom TextMate grammar, imported colors and limits (256 KiB / 2048-column lines). Preserve these constraints and HTML's explicitly registered CSS/JS sublanguages.

| Product content / file | Current default |
| --- | --- |
| C `.c`, `.h`; C++ `.cpp`, `.hpp`, `.cc`, `.cxx` | Registered. C++ header aliases `.hh` / `.hxx` and `.inl` are absent; `.h` always selects C. |
| Rust `.rs`, Go `.go`, Lua `.lua`, Shell `.sh`, SQL `.sql` | No default grammar mapping. |
| TypeScript `.ts`, `.tsx` | Routed to JavaScript grammar; not a dedicated TS grammar. |
| JavaScript, Python, Dart, Java, JSON, Markdown, HTML/CSS | Registered; actual all-language token behavior is not covered by current tests. |

`test/highlight_preferences_test.dart` covers settings, TextMate import and actual embedded CSS/JS token colors. `test/highlight_worker_test.dart` covers worker scheduling/cancellation and long-text behavior. Add one parameterized token test for every supported product language and relevant header/extension alias. Inspect the installed `re_highlight` language package before choosing imports; do not invent unsupported grammar API names.

## R6: expansion and ownership defects

1. `FileExplorer.initState` calls `_rebuildRoot()` only. `_rebuildRoot` clears `_expanded` and expands root. `_restoreExpanded()` is only called from `_switchProject`, proving why drawer recreation loses saved expansion.
2. `_restoreExpanded()` loads using `_browsing.path`, then reads mutable `_browsing.path` again after await without a request/root generation. Switching root during restoration can rebase the previous root's saved directories into another root. Child listings have no generation guard either.
3. `_persistExpanded()` filters with `p.isWithin(root, path)`, which excludes root itself. Root collapsed/expanded state cannot round-trip, and `_rebuildRoot` always expands it. An empty persisted list cannot currently distinguish intentionally collapsed root from legacy missing state.
4. `ProjectHistory.saveExpandedDirs()` and `ProjectHistory.save()` perform independent read/modify/write operations against `history.json`. Editor cursor/tab persistence and expansion persistence can overwrite one another when overlapped. Serialize updates per canonical root or consolidate ownership; do not merely add another unawaited write.
5. `_restoreExpanded` accepts old absolute values and uses `Directory.existsSync()` without verifying path confinement; only valid owned descendants should be restored. Missing or malformed history must remain harmless.
6. `_create` chooses `widget.project.language` even while browsing another project. The history context menu also passes `widget.project` name/root instead of `_browsing`. These ownership leaks must be fixed before simultaneous roots multiply the cases.
7. `_delete` correctly backs up using `_browsing.name` and closes paths, but the callback in `EditorPage._buildExplorerCard` assumes the editor's original cloud project. Future root-aware operations must carry the owning root and preserve offline gates.
8. `_create` expands its parent in memory but does not persist that expansion. `_refresh` reloads children while retaining the expanded set, but does not prune deleted descendants.

Existing `test/ai_test.dart` has only basic ProjectHistory cursor/tab round-trip and FileExplorer name search; it does not test saved `expandedDirs`, drawer recreation, raced writes or root switching. Existing editor/retained-editor tests cover session tabs but do not prove expansion/workspace persistence.

## Recommended next coherent implementation batch

Implement **persisted multi-root workspace and tree state** as one single-writer core batch. It resolves the user-visible reopening bug while establishing correct root ownership for subsequent diagnostics/tools.

Exact proposed files:

- New `lib/models/workspace.dart`: versioned workspace identity/name and ordered local project/root membership, with stable IDs and deduplicated canonical paths.
- New `lib/services/workspace_service.dart` (or a store with the same responsibility): app-private persisted workspace selection/membership and per-root expansion state; load legacy browsing selection and expansion without deleting project metadata. Workspace removal removes membership only, never project files.
- `lib/editor/project_history.dart`: serialized per-root updates for existing cursor/tab history and expansion migration; document missing/empty distinction and reject outside-root restoration paths.
- `lib/editor/file_explorer.dart`: render multiple root headers simultaneously, per-root node caches/expanded sets and immutable owner context; restore on first mount; discard stale async work; add/remove existing project roots; root-specific create/import/history/delete/search; retain no-project behavior and narrow drawer layouts.
- `lib/editor/editor_page.dart`: pass root-aware callbacks; choose the active file's root for tools/analysis/terminal actions where appropriate, retaining existing tap-Run project semantics unless an explicit active-root run action is introduced.
- `lib/store/project_store.dart`: expose membership lookup/change hooks only if needed; preserve existing `lastBrowsedProjectId` migration and project IDs/paths.
- New `test/workspace_service_test.dart`, `test/file_explorer_workspace_test.dart`, and focused ProjectHistory tests: two roots remain visible after app reload; reopening drawer retains nested expansion/root collapse; removing membership keeps disk files; same relative filename in roots opens with correct ownership; rapid switching/stale loads cannot cross-contaminate; overlapping history updates retain both tabs and expansion; create/import/history/delete route to owner root; invalid/missing roots and legacy state migrate safely.
- Add a real `.trellis/spec/frontend/workspace.md` contract to core and link it from the frontend index, whose other generic guides are still templates.

After this batch, R3 content chips/badges can be an independent one-writer batch; then analysis provider + true C/C++ syntax backend + underlines/Problems. Full breakpoint debugging remains open until an actual packaged runtime debug interface is implemented and tested.

## R7 feasible follow-on work

- Keep existing Terminal and its real stdout/stderr/cancel flow. Tests already cover actual file commands, delegate status, preparation cancellation, session output isolation, focus and scrolling (`test/sandbox_terminal_test.dart`, `test/terminal_pane_test.dart`, `test/terminal_manager_delegate_test.dart`, `test/editor_run_test.dart`).
- Add a bounded Output model for compiler/task/runtime lifecycle messages with copy/clear/source selection. Separate program output from build messages only where the backend supplies truthful provenance.
- Add Debug Console backed initially by the real local preview `debugStream`; label source and severity, preserve bounded logs, and ensure stopping/replacing preview tears down subscriptions. No expression evaluator or stepping buttons without backend support.
- Add local Ports from an app-owned service registry: `LocalWebServer.start` creates a real loopback listener, exposes `port`, `url`, `rootDir`, and `stop`. Report only app-owned live listeners; do not imply OS-wide port inspection, forwarding or external exposure. Product `WebPreviewSession` currently provides url/debugStream/stop, so an optional typed local-service descriptor is the appropriate shared extension for non-core preview implementations.
- `test/offline_editor_gates_test.dart` and `test/offline_background_and_shortcuts_test.dart` exercise existing offline UI gates. New panels must not import online terminal/auth/network backends into offline actions, and analyzer/debug providers must have no online fallback.

No requirement in this report is marked complete from source inspection alone. Runtime tests, device behavior and cross-app compatibility remain separate acceptance gates.
