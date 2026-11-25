# Bug Analysis: selected-entry helper loss and fallback

## 1. Root Cause Category

- **Category E - Implicit Assumption**: treating physical lines as C logical lines, and finding a body without checking its preprocessing state, can turn examples or declarations into executable entries. A global function named main can also have internal linkage and belong to an ordinary helper.
- **Category B - Cross-Layer Contract**: Android previously normalized explicit empty/malformed source lists into null, conflating invalid selection with an older caller omitting the feature.
- **Category D - Test Coverage Gap**: transport tests establish payload forwarding but do not establish rejection in native/worker consumers. Token tests alone do not establish successful helper linking.

## 2. Why Fixes Failed

1. Scope tracking and ordinary comment/string skipping fixed some false positives but did not model C translation phases: splicing precedes comment recognition.
2. Conditional tracking at the main token did not cover a body controlled by a later directive.
3. Line-based macro parsing did not account for CRLF splices or comments between directive tokens.
4. A nullable list plus mapNotNull/takeIf hid invalid caller intent at the Android boundary.
5. Applying entry classification to the interpreter include-file map confused compilation units with project contents. Header-defined entries must remain available through includes.
6. Entry selection assumed the caller supplied an in-project file. Runtime boundaries also need normalized and resolved-path validation before accepting the entry.

Evidence: the independent Dart repro originally classified all five helper fixtures as entries and removed them. Android source review demonstrated the empty-list fallback. The five corrected helper cases now pass real desktop baseline/current comparisons and the standalone GCC check. Intermediate runs while pi was editing are inconclusive, not final product failures. Independent integration checks then found header-defined main being removed from the interpreter include map and external entry paths being executed by both desktop and interpreter runners; pi fixed those proven failures; the final three independent checks passed with no remaining task-scope blockers.

## 3. Prevention Mechanisms

| Priority | Mechanism | Specific Action | Status |
| --- | --- | --- | --- |
| P0 | Architecture | Keep one conservative selector shared by Dart runners; retain unknown source instead of silently removing it. | Done; final independent review passed |
| P0 | Runtime contract | Distinguish absent source selection from every present invalid payload. Validate project membership and entry inclusion before compilation. | Android reviewed; worker payload regression passed |
| P0 | Tests | Preserve lexical counterexamples, real helper linking, complete headers and external-entry rejection. | Done; 141 application tests and the final independent integration checks pass |
| P1 | Cross-layer test | Exercise the real worker handler with stubbed compiler/WASM execution to check selected inputs, complete files and invalid payloads. | 10 independent checks passed |
| P1 | Documentation | Record preprocessing order, internal linkage, conditional-body ambiguity, absent-only fallback, full include maps and resolved-path entry checks. | Done in backend/source-selection.md |

## 4. Systematic Expansion

- The same Dart selector serves desktop, interpreter and browser routes, so one lexical fix must have shared regressions. Do not duplicate it in Kotlin, Objective-C++ or JavaScript.
- Native and worker consumers must preserve the difference between selection and project contents: headers/assets/writeback remain complete.
- Review against the pre-implementation snapshot because this workspace contains another runtime task and shared-core work owned by the Java session.
- Test a stable tree after pi finishes each edit. A compiler error from sampling a half-written file is not an actionable released-code finding.

## 5. Knowledge Capture

- [x] Update backend/source-selection.md with executable rules and failure examples.
- [x] Keep Android, desktop, portable and Web runtime specs linked to this contract.
- [x] Verify that src/templates/markdown/spec does not exist in this application repository; no template synchronization applies.
- [x] Record the final independent compiler and regression results in verification.md.
- [x] Include task-owned specification changes in the concrete commit plan; the user approved temporary Git deferral until the runtime baseline is committed.
