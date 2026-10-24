# Offline C/C++ editor analysis

## Scope and public boundary

`ForgeCodeAnalyzer` implements the shared `CodeAnalyzer` contract. It sends exact
unsaved project snapshots to `qfli_forge/native.analyzeStart`; analysis never calls
Run. `qfli_compiler_analyze` in `qfli_code_analysis.h` is a separate, compile-only
C ABI over the existing single-use compiler session and cancellation lock.

The native request contains SDK/project/active paths, C/C++ mode and at most 64
UTF-8 source/header snapshots totaling 16 MiB. Dart/ArkTS additionally limit the
request to 4 Mi UTF-16 code units. Reject malformed UTF-16, embedded NUL, duplicate
physical document paths and snapshots outside the project. Ignore unrelated
non-source editor buffers. Missing bridges/resources and busy tools are unavailable,
not a successful clean check.

## Compiler and location contracts

- Use only Clang `SyntaxOnlyAction` / `ParseSyntaxOnly`, C17/C++20, and the real
  packaged SDK. No code generation, linker, subprocess, user execution, or source
  and output writes. Keep process cwd/stdout/stderr unchanged.
- Overlay snapshots in memory. Canonicalize VFS reads/status before overlay lookup
  so symlink aliases read unsaved text. Permit only the physical project and SDK
  roots; separately resolve SDK WASI and Clang resource roots for SDK symlink
  layouts. The VFS owns its virtual cwd.
- Check every open translation unit. Record preprocessor-entered headers and
  independently check an active header only when no translation unit entered it.
  This checks disconnected headers without inventing errors in contextual headers.
- Canonicalize SourceManager paths for document lookup/coverage, then return the
  caller's original snapshot path. Diagnostics use half-open UTF-8 byte ranges;
  convert only exact Unicode boundaries to UTF-16 in Dart, preserving CRLF and
  surrogate pairs. Never estimate columns from a rendered compiler message.
- Bound diagnostics to 1,000 and messages to 4,096 UTF-8 bytes at a code-point
  boundary. Closed/system-file errors or truncation set `unmappedErrors` so they
  cannot masquerade as clean open buffers.

## Lifecycle and result protocol

NAPI `analyze(handle, project, active, isCpp, documents, cache)` shares the native
worker/events/cleanup path with execution, but skips the interpreter. ArkTS keeps
the shared active slot during SDK preparation, checking and actual cleanup.
Run IDs and the broadcast EventChannel are process-wide across all consumers.

Native stdout contains one JSON object with `diagnostics` and `unmappedErrors`.
Each diagnostic has `filePath`, `startByte`, `endByte`, `severity`, `message`, and
Clang numeric `code`. Status 0/1 means a completed check, 127 unavailable/invalid,
and 130 cancelled. Process stderr stays empty; diagnostics use session pipes.
Timeout requests cancellation and awaits the real terminal cleanup event.

## Required verification

Run Dart Unicode/CRLF/range/lifecycle tests and actual Clang NAPI tests. Cover
dirty nested headers, all open units, new unsaved sources, disconnected/contextual
active headers, symlink aliases, include escapes, closed-file errors, unchanged
source/output bytes, cancellation and successful recovery. Exercise real ArkTS
dispatch with codec Map snapshots and preparation cancellation.

`forge_editor_analysis_test.dart` must also mount the actual shared `EditorPage`
with `ForgeCodeAnalyzer`. A mocked native method/event transport may establish
product-to-editor wiring, but must be labelled separately from actual Clang/NAPI
or device execution. Cover dirty C/C++ source and nested headers together,
UTF-8-to-UTF-16 Problems/wave/gutter/navigation after CRLF and astral text, active
`.h` owner mode, correction while the rendered source shrinks, root isolation,
and unchanged source/output bytes. Unmount and join queued history writes before
removing fixtures. Async completion callbacks collect results; matcher assertions
run after the awaited pump loop has finished.

When staging around unrelated terminal work, compile HEAD plus the selected
analyzer hunks: the analysis include must provide its own frontend dependencies.
Rebuild actual ARM64 adapter archives, verify all reused upstream hashes and
exported ABI symbols, then compile/link the current HAP and inspect its ELF and
resource contents. Host, package, and installed device acceptance are distinct.
Do not carry historical strict-link/app flags forward onto new binary hashes.
