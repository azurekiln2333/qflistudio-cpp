# Acceptance ledger — 2026-10-22

The umbrella remains in progress. Current host, shared UI, package and device gates
are recorded separately. C is the sole shared-core integrator; language coordinators
own their runtime/content/provider implementation. Existing startup/signing changes
remain preserved outside the new integration commits.

Requirement IDs in the original C ledger below retain their legacy meanings.
The PRD's full-umbrella crosswalk also tracks R1-R13: Trellis/coordination (R1),
baseline (R2), expansion (R3), chips (R4), tools (R5), diagnostics (R6), workspace
(R7), debugger/panels (R8), highlighting (R9), C user headers (R10), Python
modules (R11), offline policy (R12), checks/publication (R13). No requirement is
closed by renumbering or by evidence for another product or execution layer.

| Requirement | Evidence | Status / next gate |
| --- | --- | --- |
| R1 current OHOS all examples | `native/build/native-curriculum-20261022.json`: 200/200 native; `portable-curriculum-20261022-relative.json`: 200/200 current rebuilt LLVM/WASI interpreter, exact hashes/source/output, hostOnly=true; `ohos-portable-bridge-20261022.log`: 31 actual bridge checks; `ohos-arkts-20261022.log` passed | Open: current packaged C phone acceptance and complete sibling inventory. October 16 phone reports remain historical. |
| R2 >100 additional examples | Existing C/C++ baseline = 200 pairs. Planned +160 (80 each); no new C examples authored yet | Open: substantive additions, validator inventory expansion and per-case native/portable/device execution. |
| R3 chips/circles | Core intersecting query/language/level filters and shared circles implemented. Metadata/saved overrides and concept-only search preserved. HTML executable type/CSS-JS subject bug fixed and list/detail regression passed | Host core UI implemented; current per-product assets/UI and device review remain open. |
| R4 direct language tools | C `ForgeToolsBody` embedded via profile; strict C/UTF-8 strings and ABI layout calculator. C343b637 pushed/remote verified; full app209 tests and scoped analysis clean. Core public `ToolsGridSliver(tools:)` reused by Web | Host C tools delivered; all-product/device acceptance remains open. |
| R5 diagnostics/highlighting | Frozen CodeAnalyzer API, single-lane unsaved scheduler, UTF-16/CRLF waves/gutter, real Problems and navigation. Missing grammars and JS/TS embedded dependencies added. Core mounted-line-shrink regression plus Web actual QuickJS EditorPage 2/2 passed at desktop/mobile widths | C real Clang unsaved provider implemented; current222app tests, isolated19Dart tests, actual Clang/NAPI/ArkTS suites and signed ARM64 package/signature/resource checks pass (code-analysis-20261022.md). All product providers/device checks remain open; unavailable is never clean. |
| R6 workspace/tree state | Core daddce27 retains queued multi-root history. Core36697b0 adds independent saved documents/retained identity; core2f9039a enables child named sessions by default and refreshes same-id metadata without replacing dirty buffers. Exact tree d21ffcdc7ac9:69 core regressions plus actual JSON Home/save/reopen1 passed;12Dart analysis clean; four remote refs verified. See core-workspace-publication-20261024.json | Shared host batch delivered. Other actual-product full/current-source and device UI acceptance remain open. |
| R7 offline debug/log panels | Core36697b0 publishes real optional debugger controls/gutter, Output/Debug Console/Ports, retained cleanup/retry and all queued-save orphan fences. Exact tested/staged treef6913564b966; scoped wide259 passes plus corrected tail71/71 and scoped34-file analysis clean. Supervisor9b0c01f has48focused and4actual Linux passes | Shared host UI delivered. Open: current actual product adapters and packaged runtime/device gates. macOS/older-Linux parent-only cancellation does not prove descendant cleanup. |
| R8 OHOS user headers | Current 31-check real bridge suite covers nested headers, mixed sources, linker/diagnostic/recovery behavior; portable host curriculum 200/200 | Open: actual C owning-app packaged device execution for user-created headers. |
| R9 Python modules | Python-owned foundation has ten bundled modules and local package transactions; source/build report is `../qfli_python/.trellis/tasks/10-22-python-offline-modules/research/ohos-audit-build-ready.json`. Latest original representations host report records1158/1158 passed, asset preservation0mismatches | Open: installed current package/module/import/tools/debug acceptance. Signed x64 archive is build evidence; changed FFI requires a fresh source-bound package and target run. No online pip claim. |
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

## October 22 follow-up

- Core e13d50d: source-aware Go test import filenames,98 relevant tests and analysis pass; pushed and exact remote verified.
- Core f8edb04: optional offline debugger contract and specification; analysis clean, current C222tests compile against it. Common UI and real adapter/device integration remain open.
- C analyzer: see code-analysis-20261022.md and code-analysis-package-evidence.json for isolated-source verification versus ordinary current-worktree signed ARM64 packaging. No device execution claim.
- The old missing-JSON-owner observation is superseded by the October23 handoff below; do not reassign its implementation.

## October 23 integration checkpoint

- Published core checkpoints: `0ec321c` captures the active workspace owner for
  Run; `9b0c01f` provides bounded owned-process cancellation with explicit platform
  limits; `e025805` preserves preview `session.url` for normal Run and reserves
  `urlForFile` for explicit current-file Run. Preview tests:23isolated core and9Web
  passed. These are separate from later uncommitted debugger/workspace edits.
- Main coordinator owns saved-workspace/content/Home/points/tools changes. Its
  actual composed workspace26, explorer4(including1100x175 at1x/2x), points29,
  tools48 and Home/repository6 passed at their recorded checkpoints. C owns the
  page/controller/terminal/debug integration and preserves those main hunks.
  Narrow normal-Run and Debug orphan guards are in the live page. Main's real
  normal-Run refusal/no-write regression passed; new Debug guard test is pending.
- Current source fixes include layout-safe painted debug gutter, exact captured
  source/pause navigation, queued-save availability checks, hidden-terminal
  execution fencing, retryable cleanup, and preview stop/reference retention.
  Latest additional changes are not covered by the earlier passing tests.
- Import rollback now conditionally preserves completed concurrent saves and
  captures replacement originals after backup. Prior54tests passed; new atomic
  same-isolate creation/failure cases await a fresh59-case run. Cross-process
  filesystem compare-and-swap is not claimed.
- JSON owner thread `01a15fa1-ce8b-7263-b09b-5766783ab535` delivered implementation
  `6df694e`, handoff `8f4d8e3`, and read-only family audit `62fbeb1`. See
  `../qfli_json/.trellis/tasks/10-22-offline-json-ide/research/final-handoff.md`
  and `family-audit-20261023.md`. JSON has340examples/tutorials/lessons(+240),
  440answers,340fixtures,10semantic operations and16direct tools; serial116/116
  host tests and actual x64OHOS340Runner/16worker results are retained. Ordinary
  UI covers unsaved correction without disk write, Problems/structure navigation,
  sidebar reopen and process restart; the123-byte sample was restored exactly.
  The unsigned x64 device result binds160captured source files. Later core bytes,
  multi-root target gestures, physicalARM64 and release signing remain separate.
  JSON has no product remote; do not invent a destination or claim a product push.
- JSON's source audit found C++ `.h` owner highlighting and ApiClient's bottom
  offline guard gaps. Both are C-owned repairs under implementation, not yet
  verified/published. Product native-channel refusals stay with each owner.
- Current device reservation is SQL122(after Lua's explicit deferral), with exact
  target unavailable at the last SQL report. Historical Java/Web/JSON releases
  do not grant a new C window. No current C owning-app device execution is claimed.
- Dart's historical43/120 production failure is superseded for HOST by
  `portable-production-baseline.json`:240checked/0failures using the production
  portable policy/supervisor. Its packaged original OHOS gate remains open.
  Python's old compilation failures are likewise historical; its1158/1158 host
  result does not close the device gate. Every product retains its own final
  original-inventory/expansion/runtime/content/target acceptance requirements.


## October 23 current bounded validation

- C297 first scoped run: 110 passed before the third debugger-page case stalled.
  The verified owned Flutter tree was terminated, session81247 exited1, and the
  host lane was explicitly released. Those 110 include 8 real-loopback API-policy,
  4 owner-header grammar/symbol, 14 concurrent-import, 37 content-import,
  30 controller, 15 output-panel and 2 actual-page cases. The remaining page and
  terminal cases were not run in that attempt.
- C325 corrected bounded run: format exit0, tests exit1 after43.907s total;
  actual footer86passed/4failed. All36 debugger-controller and8 fixture cases
  passed;35of36 terminal cases and7of10 page cases passed. The former paused-source
  shrink stall was fixed by pumping actual cleanup rather than directly awaiting
  widget fake-time completion. The enabled `QFLI_DIAG_TABBAR=true` focused-disposal
  regression passed, superseding the earlier source-only focus-fix status.
- Four retained failures were an orphan-notice wait, busy-terminal test requiring
  an idle editor, a test trying to create a local tab from the online-only menu,
  and real popup label overflow at390px/2x text. Narrow repairs are authored but
  not yet rerun. Scoped analysis was not reached because that wrapper stopped on
  the failing test step. Its `finally` published terminal/release automatically
  to Python245; no C build or device operation occurred.
- Main explicitly authorized13exact workspace dependencies in
  `qflistudio/.trellis/tasks/10-23-studio-release-ux-workspaces/`
  `c-workspace-dependency-authorization-20261023.json`, manifest SHA256
  `CE442557ADCA636EDFDE4C96EDDA8DCA52063668BE7F7E74D3A76588C8670057`.
  All13raw file hashes match. Host/page APIs must publish coherently; Home,
  content, points, tools, assets and diagnostics-module changes remain excluded.
- Go/JSON correctly report that child apps currently expose legacy persisted
  multi-root sessions, not the new named saved-workspace surface. C320 retains
  explicit standalone named-workspace capability/entry/migration work as OPEN;
  product-key bypasses are not an implementation or acceptance substitute.

## October 24 published shared-editor and offline-policy checkpoint

This section supersedes the earlier not-yet-rerun/not-yet-published statuses
above. It does not close the all-product or actual OHOS acceptance gates.

- Core `04a4b9a`, `cd42224`, `43d145d` publish the API offline request boundary,
  concurrent-import conditional rollback and owner-aware C++ header grammar and
  symbols. The real loopback 8, concurrent-import 14 and header 4 cases passed.
- Core `36697b04836a9dc6178f96071eca010f1685218c` publishes the coherent debugger,
  terminal/output/console/ports and workspace/page/host batch. Its Git tree is
  exactly `f6913564b96692619c4c56e45d16b39ddb4d59b8`, the staged/tested candidate.
  Main's v4 manifest authorized 19 exact dependencies, raw hashes and normalized
  blobs verified before freezing. Home/catalog/points/tools/assets WIP was not
  staged. All four core remotes were queried and equal this commit.
- C415 bounded wide run completed 259 passing cases plus one new document-tool
  fixture failure before its 89-second test deadline. The owned process tree was
  terminated; scoped 34-file analysis then exited 0. The four C325 failures all
  passed. The new fixture used a Python extension outside the content-tool menu;
  it now uses a supported Markdown document. No product code was changed to hide
  that test failure.
- C437 targeted tail exited 0: 71/71 cases passed, including all 14 actual-page
  cases, content import, offline gates/background, v4 dialog and selector suites.
  The changed fixture's analysis exited 0. Between these snapshots only eight
  spec lines and the six-line fixture correction changed; runtime/library blobs
  are identical. This is combined scoped validation, not a full core-suite pass.
  C438 published exact terminal/release automatically; no retained test handle.
- Run and Debug reject removed members. Manual/autosave/tab-close/document-tool
  saves recheck current membership after queued IO; four actual-page regressions
  retain dirty recovery text and original bytes. Tab-close identifies the same
  file again after awaits. Terminal cleanup remains busy until actual completion,
  supports retry and preserves reopened panels. Null main analyzer hides both
  Problems UI and unavailable Output text without claiming a clean analysis.
- C `e8dbd6b53c67d11f18f30001429ddf32cd5b2e18` publishes only the native offline
  route policy and INTERNET removal, with its host test/spec/evidence. Full-current
  and policy-only editions exited 0; old/disabled negative controls exited 1 at
  `Unexpected browser`. Five C remotes were queried and equal this commit.
  Startup, signing, native compiler and additional device-type WIP remains local.
- JSON's delegated default-enabled capability has passed one actual-profile
  named Home/save/reopen test in the current working tree. It is not in the
  published core checkpoint: minimal Home/SavedWorkspacesTab dependencies are
  being coordinated with main. Same-id retained rename/member metadata refresh
  is a separate in-progress follow-up. No host proof implies HAP/device proof.

## October 24 named-workspace publication

This supersedes the last in-progress capability/metadata paragraph above.

- Core `2f9039a3ba95449679b17257b0313c1ee3644a2c` has the exact tested and staged
  tree `d21ffcdc7ac9c834e0b788b21178e9f80768a519`. Four remote `main` refs were
  queried and match. Main independently verified the Home/tab blobs against its
  minimal manifest `94317EBCDBDFD6419F151DCEF33B74CFFE5E3EE346BA37A03BC23D8B5C1C0745`.
  The broader Home/catalog/cloud/menu/points/tools WIP was preserved byte for byte.
- Named workspaces default on independently of product identity, offline policy
  and language-chip visibility. An explicit optout retains the child legacy picker;
  existing explicit documents remain manageable. A cloud primary receives a useful
  local-project message before a named-save dialog can open.
- Same-id renames/member edits now refresh retained host, page and explorer
  metadata while preserving page/controller identity, live expansion and dirty
  buffers. Expansion notifications cannot restore an old name. Removed members
  retain the earlier save/run/debug recovery protections.
- Ten scoped core suites passed 69/69. The cloned actual `jsonProfile` Home/save/
  reopen test passed 1/1 against the precise publication candidate. Both package
  configs bind `qfli_studio_core` and `re_editor` to that frozen source. Analysis of
  12 changed Dart files was clean. This does not claim a full core/all-product run.
- The earlier 63-pass/6-failure report remains retained. Its four tooltip casts and
  two callback matcher assertions were fixture defects; runtime/Home blobs did not
  change between candidates. The retry finished in 85.046 seconds. Every validation,
  commit and channel-publisher private Job was terminal with zero active processes.
  A real orphan-child control separately observed root exit 0 with two descendants,
  then confirmed cleanup to zero. The host lane was released to Lua's new gate.
- Durable log copies, exact input hashes, file blobs and process records are in
  `core-workspace-publication-20261024.json` and its `.artifacts` paths. Package/
  device evidence remains separate. The next C-only editor test uses the actual
  provider and page with mocked platform analysis transport. Its subsequent
  verification is recorded below; it cannot establish Clang or device acceptance.

## October 24 C actual-page diagnostics publication

- C `10832c1c1086693572afef7abb23109f073d4958` publishes exactly one new test
  file with tested tree `7a362364a2bc29139b1a82ab940b44b1b0648e8d`. Its normalized
  test blob is `7d2aeea358bab91c9d9b6c030611d3b8745cc0a4`. All five C remote
  `main` refs were queried and equal this commit before the later evidence commit.
- The actual shared `EditorPage` and actual `ForgeCodeAnalyzer` passed at desktop
  C and phone-size C++ dimensions, alongside the existing adapter/runner suites:
  21/21 selected tests passed, and analysis of the new test was clean. The frozen
  package config binds exact published core `2f9039a` and its vendored editor;
  279 source/configuration hashes were checked before exact-tree publication.
- The tests cover dirty nested headers, CRLF/astral byte-to-UTF-16 locations,
  actual waves/gutter/Problems navigation, active `.h` C++ ownership, mounted
  text shrink/correction, cross-project isolation and unchanged payload/output
  bytes. Only native method/event transport is mocked. They establish product UI
  wiring, not Clang, HAP or installed-device execution, or a full app-suite pass.
- The first attempt retained 20 passes and one mobile fixture failure. It tapped
  before layout updated after `ensureVisible`. The only retry source change adds
  a layout pump and a real hit-test assertion before tapping; all navigation and
  payload assertions remain. No core repair was needed for this fixture failure.
- Go explicitly deferred its newly released window to C525. C accepted at global
  536 and released back to Go509 at 537. All five step Jobs and the separate
  channel publisher exited 0, terminal with zero active processes. Validation and
  commit took 14.737 seconds before bounded channel publication. No device action
  was performed; SQL527 reports no reachable assigned OHOS target.
- `c-editor-analysis-publication-20261024.json` binds both attempts' raw logs,
  exact candidate/source identities and terminal records. Later spec/evidence
  commits do not change the tested runtime/test blobs. Unrelated startup,
  terminal, native, signing, content and main work remains excluded.
