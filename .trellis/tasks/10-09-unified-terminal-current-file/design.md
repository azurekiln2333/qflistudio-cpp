# Design

## Existing behavior and ownership

The shared core already implements the continuous transcript and editor gesture. This task integrates with those mechanisms; it does not create a second terminal implementation. pi-c-terminal owns C-edition implementation and tests. Codex owns planning, review, specs and narrow final staging. Do not edit ../qfli_studio_core or ../qfli_java.

## Change boundary

The remaining user-visible gaps are C runner title text and entry selection. The UI passes entryFile correctly, but the C runtime discovers every translation unit and may combine multiple independent main programs. Preserve all ordinary support units and select the requested program.

## Data flow

Editor click/long press -> existing RunnerService entryFile -> Forge runner -> selected translation units -> existing desktop/native/browser execution -> unchanged stdout/stderr/exit -> shared TerminalPane.

Introduce one reusable C-edition source-selection mechanism, independent of the native C interpreter import graph so browser builds remain valid. It keeps the explicit entry, retains helper units, and excludes other unambiguous top-level main definitions. Detection must skip comments, strings, character/raw literals, declarations and member/namespace functions; do not infer entry ownership from a filename. Preserve ambiguous preprocessing cases for compiler diagnostics instead of silently deleting code.

Prefer forwarding an explicit selected-source list through the existing native start/run and browser worker payloads over duplicating a lexical detector in Kotlin, Objective-C++ and JavaScript. Native consumers validate project-local readable sources and never silently re-enumerate an explicit list. Legacy callers can retain current discovery when no list is supplied. Project files/headers and browser file writeback remain complete; selecting compilation inputs is not removing files.

## User-facing run text

Use a short command-style title such as run src/main2.c, derived from the selected project-relative path. Apply it to desktop, native, interpreter and browser run results. Keep compiler labels available internally only if used for actual diagnostics. Do not sanitize or translate user stdout/stderr.

## Compatibility

- Keep C and C++ language modes, mixed-language helpers, input.txt, compiler diagnostics, failure codes and cancel behavior.
- Keep the selected entry stable across asynchronous save/run.
- Missing or invalid entries must fail explicitly and must not execute a different program.
- Do not alter native compiler APIs or rebuild toolchains unless existing bridge consumption cannot carry selected sources.
- No claim of full C preprocessing/AST analysis: unsupported ambiguous entry patterns retain compiler diagnostics.

## Verification and rollback

Use real desktop compiler fixtures for alternate main programs and helper linking, pure selection tests for lexical edge cases, bridge tests for source-list transport, and existing shared UI regressions. Validate available native builds and browser worker syntax/integration. Record unavailable Apple/device execution separately.

Keep a pre-implementation snapshot of the touched C files. Review only task-owned deltas against that snapshot; never reset whole files or commit unrelated pre-existing work.