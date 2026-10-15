# C/C++ selected-entry execution

## 1. Scope / Trigger

Applies to source_selection.dart, run_title.dart, the C/Clang/native/browser runners and native source-list consumers. This connects the shared editor gesture to actual compilation inputs.

## 2. Signatures

```dart
List<String> selectRunSources({
  required String entryFile,
  required List<String> allSources,
  required String? Function(String path) readSource,
});
bool definesUnambiguousMain(String? source);
String runTitle({required String projectPath, required String entryFile});
```

NativeClangRunner.run accepts optional List<String>? sources. The native start payload carries optional sources: String[] of absolute paths. The browser worker carries optional sources: String[] of project-relative paths alongside the complete files snapshot.

## 3. Contracts

- Shared editor click uses the configured/default project entry. Long press passes the active saved file as entryFile without rewriting project configuration.
- Keep the selected translation unit and ordinary C/C++ helpers. Exclude other files only when their own global main definition is unambiguous.
- Comments, ordinary/character/raw strings, prototypes, internal-linkage static functions and class/namespace/member functions named main do not identify a program entry.
- Apply C backslash-newline splicing for LF and CRLF before recognizing comments or preprocessing directives. A continued line comment or macro example is not executable source. Treat comments as whitespace when interpreting directive names and macro targets.
- Conditional ambiguity applies to both the function signature and its body. A top-level declaration followed by a conditionally compiled body is not an unambiguous entry definition.
- Conditional compilation and macro ambiguity are retained for compiler diagnostics. This is not a C preprocessor or full C++ parser; do not silently discard uncertain helpers.
- Callers validate the selected file. Native filesystem runners check existing readable source files and project containment using normalized absolute and resolved real paths, including symlink targets, before selection or execution. Browser callers validate canonical project-local snapshot paths. Headers remain available to compilation but are not runnable entries. Never substitute another main for an invalid selected file.
- Desktop, interpreter and browser share one Dart selector. Native consumers validate and use an explicit list; they do not rediscover the project when a list is supplied. Only an absent sources key preserves legacy discovery. Present-null, an empty list, a non-list value or a malformed item is an error; never coerce it into absence by filtering or takeIf.
- Native lists contain existing project-local .c/.cpp/.cc/.cxx files and include the selected entry. Browser entries must also occur in the uploaded source set.
- Selection changes compilation inputs, not the include-file map or project snapshot. The C interpreter must retain every header, even when a header defines main and is included by the selected source. Preserve input.txt, assets, browser preopens and conflict-safe writeback.
- Preserve per-unit language modes, mixed linking, diagnostics, stdout/stderr, exit codes and cancellation cleanup.
- Run labels use run plus the project-relative entry with forward slashes and no backend branding. Never filter program output to remove phrases resembling old UI text.
- The shared terminal renders the prompt and suppresses app-generated exit-0 footers.
- OHOS registers the Clang channel through EntryAbility and QfliCNative. Explicit lists reach the native validator; only an absent key enables legacy discovery. Its ordinary Dart route disables C fallback. Follow [ohos-runtime.md](./ohos-runtime.md) for the signed LLVM/WASI interpreter, resource layout and app verification; channel registration alone does not establish runtime availability.

## 4. Validation and Error Matrix

| Condition | Required behavior |
| --- | --- |
| main and main2 both define entry programs | Run the selected program plus normal helpers |
| Helper mentions main in comments, literals or declarations | Keep the helper |
| Ownership depends on preprocessing | Keep the ambiguous unit and preserve compiler diagnostics |
| Entry missing, unreadable, outside project (including a symlink escape) or a header | Fail explicitly with not-run status; do not execute it or default main |
| Explicit list empty, invalid or omitting entry | Error/not-run result; no rediscovery |
| Older caller omits list | Preserve legacy discovery |
| Compile/link/run failure or accepted stop | Preserve existing diagnostics and failure/cancel status |
| Success | Restore prompt without a synthetic completion paragraph |

## 5. Good / Base / Bad Cases

- Good: main2.c runs with helper.cpp while the independent main.c is excluded.
- Base: channel tests prove source transport; actual device execution needs a separate app check.
- Bad: change only the title, filter by filename, duplicate lexical detectors across bridges, or discard a helper containing a namespace main.

## 6. Tests Required

- Real desktop compilation proves distinct default/alternate outputs and preserves mixed helpers.
- Real C interpreter runs honor the same selection and retain a header-defined entry included by the selected .c file. Desktop and interpreter tests reject an external entry with no program output.
- Selector tests cover literals/raw strings, comments, prototypes, nested scopes, static helper main, conditional function bodies, LF/CRLF continuations, comments inside macro directives, ambiguity and invalid entries. Pair lexical counterexamples with real helper-linking tests when available.
- Channel tests assert sources transport and preserve output/error/cancel behavior.
- Browser checks verify authoritative lists separately from the complete project snapshot.
- iOS remains compilable with portable runtime enabled or disabled; Windows tests cannot establish Xcode/device execution.
- Shared UI regressions prove continuous scrollback, silent success and tap/long-press/tap routing.
- Record existing shared Web adapter blockers separately from this task's regressions.

## 7. Wrong vs Correct

Wrong: compile every main and merely display the active filename.
Correct: route entryFile into the compilation set before backend execution.

Wrong: use a raw main( substring or discard conditional helpers for convenience.
Correct: identify an unambiguous global definition and preserve uncertain code.

Wrong: read sources then ignore it in native collection.
Correct: consume explicit lists and rediscover only when the field is absent.
