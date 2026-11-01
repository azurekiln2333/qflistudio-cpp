# JSON product owner and evidence audit — 2026-10-22

This read-only audit inspected `D:/MyNewProjects/qfli_json`. It made no JSON or shared-core edits, ran no Flutter builds/tests, and performed no device actions. Python only read asset JSON, counted records, checked hashes, and inspected the existing HAP archive. JSON parsing and transformation are data operations, not executable-language program execution.

## Existing owner and source-control boundary

- Active task: `qfli_json/.trellis/tasks/10-22-offline-json-ide/task.json`, status `in_progress`, creator/assignee `codex`, branch `feat/offline-json-workbench`. No live pane identifier or named coordinator was documented.
- Product HEAD: `6df694e3e695fdb69d7b59232cfc4b833139f3f6`, `feat(json): add offline workbench and 340 verified examples`.
- `design.md` explicitly assigns shared-core integration to the C coordinator. The JSON session contributed explorer/history work and the owner-aware backup fix. Its evidence attributes shared integration to `ef34591`, `daddce2`, and backup correction `96e6833`.
- No `AGENTS.md` was present in the JSON root, `D:/MyNewProjects`, or `D:/`. The product has `.trellis/workflow.md` but no local `.agents` directory. `git remote -v` was empty.
- Preserve dirty task evidence/implementation metadata, `ohos/build-profile.json5`, `main_pages.json`, untracked `AgreementReader.ets`, `LICENSE`, desktop generated registrants, and untracked OHOS evidence. This audit did not claim any of these paths.
- Ordinary UI screenshots were appearing during the audit. `research/ohos.md` still says the JSON root worker is checking the ordinary UI. Coordinate with that existing session before taking over product writes.

## Exact bundled inventory

`assets/content/examples.json` has 340 examples, 340 unique IDs, 340 distinct source strings, and 340 fixtures; all entries have language `json`. `tutorials.json` has 340 tutorials, 340 lessons, and 440 exercise answers.

`catalog_audit.json` records 100 inherited examples/tutorials and 240 newly authored examples/tutorials. All 100 inherited example code strings matched their recorded SHA-256 fingerprints. The 240 additions span 24 categories, ten per category: foundations, pointers, configuration, records, commerce, money, schedule, documents, education, diagnostics, storage, patches, forms, metrics, science, geography, household, media, accessibility, schemas, interchange, tests, workflows, structures.

Recorded corrections comprise 100 example outputs, 100 lesson outputs, 200 prose exercise answers, and 100 fixtures. The audit file retains 500 correction-detail records. A fresh read-only Python `json.loads` pass accepted all 340 example sources, 340 expected outputs, 340 lesson sources, 340 lesson outputs, 440 exercise answers, and 340 fixtures. This independently checks data syntax only; shipped Dart semantics are covered by the separate evidence below.

Product asset SHA-256 values, independently recomputed:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `assets/content/catalog_audit.json` | 142948 | `6442c06e699d130ee7eec32d2fb80d1226d6810b3537ade9a1ba3972ad92bb4f` |
| `assets/content/examples.json` | 508014 | `20a555e3f0671dfc0cafd09adb4895ba57ace25babdca332dd6bc59e33f33675` |
| `assets/content/tutorials.json` | 941971 | `8cb0b9e82ba0185d6cf0c988458f7e16ac0ea3c45fea1c541ce22c50c7869ca2` |

## Implemented product contracts and limits

`lib/main.dart` injects `JsonRunner`, `JsonCodeAnalyzer`, `JsonContentRepository`, `jsonToolsTab`, `JsonDocumentPage`, and `jsonTerminalCommand` into an offline JSON-only `StudioProfile`. The repository loads only bundled product assets.

`lib/json/json_tools.dart` directly exposes 16 tool cards: format/check, minify, recursive key sorting, JSON Pointer, diff, Merge Patch, JSON Patch, flatten, unflatten, JSON Lines to array, array to JSON Lines, string escape, string unescape, CSV, local Schema, and statistics. Each operation uses a killable isolate task with cancellation and a five-second deadline.

The query implementation is RFC 6901 JSON Pointer (`JsonWorkbench.select`), including escaped tokens and strict array indexes. No JSONPath implementation or claim was found in product sources/tests/catalog/task artifacts. Do not report Pointer as JSONPath support.

`json_schema.dart` implements an explicit JSON Schema 2020-12 local subset: types, enums/const, properties/required/additionalProperties, items/prefixItems/uniqueness, numeric/string/container constraints, combinators, and local `#`/`#/` references. Unknown keywords, other dialects, external references, and nested resources report errors. The UI documents unsupported format, conditionals, regex properties, remote references and nested resources. Patterns use Dart Unicode regular expressions, not a claim of complete cross-engine conformance.

`json_workbench.dart` implements strict syntax/duplicate-key checks and bounded transformations. Limits include 2 Mi characters of input, depth 128, 50000 nodes, 4 Mi characters of output/accumulated paths, 200000 CSV cells, and 250000 patch-work nodes. Integer tokens outside signed 64-bit range fail explicitly. Fractions use finite runtime doubles.

`JsonRunner` checks real sandbox files, rejects foreign/symlink-escaping paths and invalid UTF-8, then returns formatted JSON or positioned parse errors. The terminal supports read-only `json check|format|minify|sort|stats <file>` and `json get <file> <Pointer>`; no executable debugger or network service is implied.

`json_analyzer.dart` checks unsaved JSON snapshots in a worker and returns UTF-16 offsets through the shared analysis API. `json_document_page.dart` supplies debounced/generation-fenced analysis, navigable scalar/array structure, highlighted keys/strings/literals/numbers, wavy error spans, Problems/Output and explicit save. Main-editor regressions in `test/json_analyzer_test.dart` cover real CodeEditor decoration, clickable Problems navigation, CRLF/astral offsets, correction clearing, and unchanged disk.

## Actual shipped verification evidence

`lib/json/json_catalog_verification.dart` is shared by host tests and the installed verification page. It checks every example's formatted output, all fixtures, lesson outputs and exercise answers; Pointer exercises compare selected values. It also executes ten promised semantic fixtures through the shipped Patch/Merge Patch implementation: three merge fixtures and seven patch fixtures. This is not a claim that all 340 examples have business-rule/schema semantics independently checked. All 16 tool defaults run in background tasks; the harness itself only requires nonempty tool output, while host tool tests additionally compare worker results to direct execution.

Existing logs were read, not rerun:

- `%TEMP%/qfli-json-final-review-tests.log`: `+116: All tests passed!`.
- `%TEMP%/qfli-json-final-analyze.log`: no issues.
- `%TEMP%/qfli-json-ohos-x64-final-harness-build.log`: Hvigor success, 16.085 seconds, 42 tasks.
- `%TEMP%/qfli-json-ohos-x64-normal-build.log`: Hvigor success, 18.355 seconds, 42 tasks.

The final installed harness report is `qfli_json/.trellis/tasks/10-22-offline-json-ide/research/ohos-harness-final-result.json`:

```json
{"passed":true,"examples":340,"runnerPasses":340,"tutorials":340,"lessons":340,"exerciseAnswers":440,"fixtures":340,"semanticOperations":10,"tools":16,"platform":"ohos","failures":[]}
```

Adjacent `research/ohos-harness-final.log` exists and contains the actual process `5271` result marker at `2026-10-22 20:48:02.595`. The task documentation identifies an API 26 x86_64 emulator at `127.0.0.1:5555`. `ohos-harness-final.png` preserves the passed harness screen. Raw `.log` evidence is physically present but absent from the ordinary untracked-file listing; ensure retained/committed evidence is intentional before archiving.

Artifact metadata lives in `research/ohos-final-harness-artifact.json` and `research/ohos-normal-artifact.json`:

| Mode | HAP bytes | HAP SHA-256 | Kernel SHA-256 |
| --- | ---: | --- | --- |
| final harness | 123852051 | `e2a945a8687ffa73e8552a5874610ef0d44420320dec5b3297f805e3f3f71268` | `5b6a52a26e6130fc9c34735613558aabef9b84f70b09117bdc125a4f119bc71a` |
| ordinary app | 123864987 | `a7b17b33ca7a97ccdbc62ca5addbf31bf8f960ff716146298f9ac2fc48aebfa7` | `51d40fff1d792540983f00c8c8ec80db456187eceaf7265b12191315f4ba3933` |

The ordinary HAP still exists at `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`; independently recomputed size/hash exactly match the table. Read-only ZIP inspection found 39 entries, bundle `com.azurekiln.qfli.json`, only `ohos.permission.READ_PASTEBOARD`, and byte-identical copies of all three product content assets. Shared-core catalogs are separately bundled dependencies and are not the product-owned catalogs.

The task's final and ordinary snapshots record 160 app/core Dart/content files, in `research/ohos-final-source-snapshot.json` and `research/ohos-normal-source-snapshot.json`. Their artifact-recorded snapshot hashes are respectively `2c87621c71e0f53ee7abb45dc5f94a6891f90da32d421710578458fcf653f85b` and `e1aeeb18004e73cbadc295220f42d880c73085cb17d04f48f175b2e44f2ae45f`. At audit time all product files still matched; only `core/lib/services/process_supervisor.dart` and `core/lib/services/studio_profile.dart` differed from both recorded snapshots. Device acceptance therefore applies to the captured shared-core bytes, not automatically to later common-core edits.

Visually inspected existing ordinary-app screenshots show direct tool cards (`ohos-ui-tools.png`), `/items/0/id` returning `1` (`ohos-ui-pointer.png`), and main-editor syntax colors, a red wavy error and Problems row `src/data.json:1:6` (`ohos-ui-problems.png`). Screenshots alone do not prove diagnostic correction/navigation, workspace persistence, every interactive tool, or fresh installation of current shared-core sources. Host regressions cover several of these interactions; the ordinary UI handoff is still being updated by its owner.

## Remaining coordination and acceptance gaps

- Locate/coordinate the existing JSON owner; task metadata has only `codex`, not a pane. Product implementation already exists and must not be duplicated.
- JSON task steps 9 and 11 are still unchecked despite stored verification logs: final review/spec/journal/archive and evidence commits remain owner work.
- Current device evidence is an unsigned x64 emulator result. Release signing materials were missing; no signed release or physical ARM-device pass is established.
- The earlier Flutter `--no-codesign` attempt failed at configured signing. Successful builds used Hvigor's `-c properties.enableSignTask=false` without altering the user's signing profile.
- Tooling previously fetched `@ohos/hypium` through ohpm. This is evidence for an offline application, not an entirely disconnected build process.
- Product has no remote; do not invent a push destination. Several final artifact/result/screenshot files are still untracked.
- Do not infer sibling executable-language runtimes, C headers, Python modules, or whole-family acceptance from JSON parsing/transformation success.


## Superseding coordinator handoff — October 23

The historical unknown-owner and steps 9/11 observations above are superseded.
JSON coordinator thread `01a15fa1-ce8b-7263-b09b-5766783ab535` supplied product
implementation `6df694e`, handoff `8f4d8e3` and family audit `62fbeb1`. Authoritative
product records are `qfli_json/.trellis/tasks/10-22-offline-json-ide/research/`
`final-handoff.md`, `family-audit-20261023.md` and its per-gate files. JSON has
340 paired catalog entries (+240), 440 answers, 340 fixtures, 10 operations and
16 inline tools; 116 host tests and recorded x64 OHOS 340 runner/16 worker checks
are product-owned evidence. Device evidence binds the captured 160-file snapshot,
not later shared-core bytes, physical ARM64 or release signing. No JSON remote is
configured, so no product push is claimed.

The later child-profile multi-root regression passed once (JSON307) and covers
legacy ProjectHistory owner tabs/cursors/document-save restoration. Named saved
workspace UI is still main-only at this checkpoint; C320 explicitly retains that
standalone UI gap. Shared dynamic ApiClient offline guards and C++ owner-header
mapping passed their focused 8 and 4 host cases in C297; current common debugger,
terminal and final composed page validation remains incomplete. C's platform
remote-entry refusals are source-ready pending actual-handler checks. None of
these source or host observations closes the unified all-product OHOS gate.
