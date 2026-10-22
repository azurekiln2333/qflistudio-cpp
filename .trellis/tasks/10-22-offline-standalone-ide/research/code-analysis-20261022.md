# C/C++ unsaved analysis integration — October 22

## Delivered behavior

The product registers `ForgeCodeAnalyzer` against the existing shared analyzer
contract. A dedicated Clang syntax/type-check action overlays exact unsaved source
and header snapshots without running user code or writing project/output files.
The native result carries original snapshot paths and UTF-8 byte ranges; Dart
validates and converts exact boundaries to UTF-16, retaining CRLF and astral text.
Unavailable, busy, cancelled, malformed and incomplete checks never report clean.

Independent review found and the final tests cover three repaired defects:

1. The isolated analyzer include depended on an unrelated terminal include. It
   now includes its own concrete Clang frontend actions.
2. An active disconnected header was skipped when other translation units were
   open. Preprocessor coverage now distinguishes entered contextual headers from
   disconnected headers requiring a separate check.
3. Canonical-only snapshot storage could miss a symlink alias and the real VFS
   allowed include escape. VFS reads resolve physical identity before overlay
   lookup and stay within project/SDK resource roots. SourceManager paths are also
   canonicalized before mapping back to the original snapshot path.

## Exact verification scope

| Evidence | Result |
| --- | --- |
| `native/build/code-analysis-current-app-tests.log` | Current worktree full Flutter suite: **222 passed**. |
| `native/build/code-analysis-dart-analysis.log` | Product/provider/profile and adapter tests: no issues. |
| `native/build/code-analysis-isolated-native.log` | Selected analyzer-only source snapshot: all **31** existing actual Clang/WasmEdge runs plus the complete new real analysis suite pass; process stderr empty. |
| `native/build/code-analysis-isolated-arkts.log` | Selected ArkTS source dispatch, codec Maps, bounded inputs, busy/preparation cancellation and existing lifecycle/resource regressions pass. |
| `native/build/code-analysis-isolated-app-tests.log` | Selected Dart snapshot: **19 passed** (13 analyzer plus 6 shared runner tests). |
| `native/build/code-analysis-isolated-dart-analysis.log` | Selected provider/main/shared runner snapshot: no issues. |
| `native/build/code-analysis-ohos-package.log` | Rebuilt current ARM64 compiler/runtime adapters; every reused upstream archive/object hash verified, 2,242/108 AArch64 objects and required analysis ABI verified. |
| `native/build/code-analysis-ohos-hap.log` | Current ordinary signed ARM64 release HAP build succeeds, including real ArkTS/native compile and strict native link. |
| `native/build/code-analysis-signature.log` | SDK `verify-app`: digest, permission signature and app signature pass. |
| `code-analysis-package-evidence.json` | Exact HAP/resource/native/static library hashes, source hashes, native analysis symbol, ARM64/16 KiB/no-WX/DT_NEEDED checks. Device execution remains **false**. |

The selected snapshot was constructed from HEAD plus only analyzer-owned hunks.
Its native compiler has none of the old terminal implementation. An initial real
alias test exposed SourceManager retaining the lexical filename; the final run
includes the canonical lookup fix. No dummy parser/compiler was used.

The ordinary signed HAP includes the preserved earlier startup/terminal worktree
changes. Its artifact evidence therefore describes that exact worktree package,
not a hypothetical clean checkout. Existing binary package manifests were stale
after the earlier terminal adapter replacement. The rebuild excludes those old
adapter bytes, verifies all reused upstream inputs, records current hashes, and
replaces historical strict-link claims with checks against the current HAP runner.

## Remaining gates

The selected current target is an x86_64 OpenHarmony emulator; this C package is
ARM64-only. No C install, launch, target change or daemon action occurred. Current
owning-app device diagnostics, user headers and complete 200-example execution
remain open, as do the later 160 new C/C++ pairs and unified all-product acceptance.

Related common-core follow-ups were pushed separately: Go source-aware test
import names at `e13d50d`, and optional typed debugger contract at `f8edb04`.
The debugger contract does not itself deliver editor controls or product/device
debugger integration. Lua/Go/Python/Java adapters remain product-owned.
