# Acceptance ledger — 2026-10-22

The umbrella remains in progress. Current host, shared UI, package and device gates
are recorded separately. C is the sole shared-core integrator; language coordinators
own their runtime/content/provider implementation. Existing startup/signing changes
remain preserved outside the new integration commits.

| Requirement | Evidence | Status / next gate |
| --- | --- | --- |
| R1 current OHOS all examples | `native/build/native-curriculum-20261022.json`: 200/200 native; `portable-curriculum-20261022-relative.json`: 200/200 current rebuilt LLVM/WASI interpreter, exact hashes/source/output, hostOnly=true; `ohos-portable-bridge-20261022.log`: 31 actual bridge checks; `ohos-arkts-20261022.log` passed | Open: current packaged C phone acceptance and complete sibling inventory. October 16 phone reports remain historical. |
| R2 >100 additional examples | Existing C/C++ baseline = 200 pairs. Planned +160 (80 each); no new C examples authored yet | Open: substantive additions, validator inventory expansion and per-case native/portable/device execution. |
| R3 chips/circles | Core intersecting query/language/level filters and shared circles implemented. Metadata/saved overrides and concept-only search preserved. HTML executable type/CSS-JS subject bug fixed and list/detail regression passed | Host core UI implemented; current per-product assets/UI and device review remain open. |
| R4 direct language tools | C `ForgeToolsBody` embedded via profile; strict C/UTF-8 strings and ABI layout calculator. C343b637 pushed/remote verified; full app209 tests and scoped analysis clean. Core public `ToolsGridSliver(tools:)` reused by Web | Host C tools delivered; all-product/device acceptance remains open. |
| R5 diagnostics/highlighting | Frozen CodeAnalyzer API, single-lane unsaved scheduler, UTF-16/CRLF waves/gutter, real Problems and navigation. Missing grammars and JS/TS embedded dependencies added. Core mounted-line-shrink regression plus Web actual QuickJS EditorPage 2/2 passed at desktop/mobile widths | Open: C compile-only analyzer backend and all product providers/device checks. No analyzer means unavailable, never fake clean. |
| R6 workspace/tree state | Core daddce27 pushed/remote verified. Queued physical-root writes preserve independent tree/membership/document fields. True cross-root tab order/active/source-line cursors and owner type restore in actual EditorPage. Independent review's folded cursor, create expansion, deletion disposal and physical alias findings repaired. `../qfli_studio_core/build/workspace-reviewed-integration.log`:712 pass/2 skip; focused27 pass incl real directory link; analysis clean | Host implementation/review delivered; actual device UI acceptance remains open. |
| R7 offline debug/log panels | Existing real terminal cancellation preserved; actual Problems panel added. Shared audit found no debugger backend or separate Output/Debug Console/Ports yet. Java reports its own real JVM debug tool | Open: feasible backend contract/control implementation and useful real log/port panels. Stop/logs do not count as a debugger. |
| R8 OHOS user headers | Current 31-check real bridge suite covers nested headers, mixed sources, linker/diagnostic/recovery behavior; portable host curriculum 200/200 | Open: actual C owning-app packaged device execution for user-created headers. |
| R9 Python modules | Assigned to Python coordinator; no current Python evidence independently adopted by C | Open: offline module inventory, fixes and device acceptance. |
| R10 all apps/integration/commits | Core ef345913, Java content9a1c8b9 and workspace daddce27 pushed/remote verified. Current core712 passed/2 skipped and scoped analysis clean. C tools343b637 pushed/remote verified with209 app tests. Dart b90f4b9 pushed with116 app tests; Java4d5d2a3 pushed with235 tests and actual x86OHOS gates | Open: all-product R1-R10 ledger and remaining runtime/content/device/debug gates. |

## Coordinator gates observed on October 22

- Dart: delivered adapter/embedded tools at `b90f4b93cc5c3f1cea3d3434ecbe61006a8d81ae`.
  Shipped portable baseline remains 43/120 pairs. Its repaired tom_d4rt host candidate
  passes old 240 programs but awaits real descendant cancellation and offline IO
  review before production migration. Do not count the candidate as delivered.
- Web: actual QuickJS diagnostics drive real EditorPage at 1280x900 and 390x844;
  C reran `test/web_editor_analysis_test.dart` after repairing reentrant repaint,
  2/2 passed in `../qfli_web/build/content/core-live-editor-repair.log`.
  Web reports 481 semantic catalogs checked on desktop/mobile; final subject-chip
  actual-asset acceptance and current signed device execution remain separate.
- Java: durable `../qfli_java/.trellis/tasks/10-22-offline-ide-completeness/research/java-final-handoff.md`
  records final host280/280 with1120 assertions, actual OHOS x86_64 280/280 with1120
  assertions, real dirty-buffer diagnostics and16 JDI lifecycle checks passed.
  The initial host279/280 and OHOS266/280 failures remain retained. Product235 tests
  and analysis pass; main4d5d2a3 and Java-only core9a1c8b9 pushed/remote verified.
  Physical ARM64 remains open. Global119 releases Java's device window to Web;
  C has not manipulated the emulator or claimed a C device pass.
