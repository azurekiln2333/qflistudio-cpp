# Unified QFLI terminal and current-file run

## Goal

Make QFLIForge inherit the continuous terminal experience and execute the intended C/C++ file. The user explicitly requires pi to work in the right Herdr pane under Codex coordination.

## Confirmed facts

- C and Java editions both depend on ../qfli_studio_core (their pubspec.yaml files).
- The shared core already contains the terminal and long-press changes. See research/findings.md for exact anchors.
- Both the C runtime and shared core have substantial pre-existing uncommitted work; the Java session currently owns the shared terminal changes.
- pi-c-terminal is running in the right sibling Herdr pane w6:p2 with qfli_c as its cwd.
- C runner titles still expose Chinese run descriptions and backend labels. Its source discovery can combine independent main programs into one compile.

## Requirements

- R1: Identify the actual shared-core changes and verify that the C edition inherits them.
- R2: Commands, program output, and the next prompt form one top-aligned scrolling transcript.
- R3: App-generated run text is concise: no successful exit-code-zero footer and no backend labels such as JDK, Clang or interpreter descriptions. Preserve program stdout/stderr verbatim and retain real error status.
- R4: Click Run to execute the configured project entry; long-press the same button to save and run the currently open runnable file. Do not change the configured entry or silently fall back to it.
- R5: A project containing main.c and main2.c (or equivalent C++ programs) runs the requested program while retaining ordinary helper translation units.
- R6: Apply the selected-entry behavior consistently through existing C/C++ runtime routes. Retain language modes, cancellation, error propagation, and platform routing.
- R7: pi implements in the requested right pane; Codex reviews and owns task/spec updates.

## Acceptance criteria

- AC1 (R1): Report shared terminal/editor files and distinguish inherited work from changes in this task.
- AC2 (R2, R3): Shared terminal tests verify a single transcript, the prompt immediately after output, no success footer, and unchanged program text.
- AC3 (R4, R5): Default main and alternate main2 produce distinct expected outputs; helper source files still link. Current-file runs do not overwrite project configuration.
- AC4 (R5, R6): Selection tests cover real function definitions versus comments, strings, declarations and member functions. Ambiguous preprocessing must not silently discard helper source.
- AC5 (R3, R6): Focused runner/channel tests, relevant static analysis and available native checks pass. Unavailable device/Apple checks are stated accurately.
- AC6 (R7): Preserve pre-existing runtime changes and other sessions' shared-core work.

## Scope boundaries

- Product edits are confined to qfli_c source selection, runtime run labels, necessary bridge consumption of selected files, and regression tests.
- Shared core and Java code are inspected and tested but remain owned by the active Java session.
- No unrelated navigation changes, compiler upgrades, emulator data removal, or other language-edition rewrites.