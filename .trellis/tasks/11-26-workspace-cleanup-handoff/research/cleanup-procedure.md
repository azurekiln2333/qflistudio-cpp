# Source cleanup inventory and preservation

## Current authority

- Directive: `D:/MyNewProjects/_orchestra/qfli-unified-migration.md`, 2026-11-27.
- Active task: `.trellis/tasks/11-26-github-workspace-migration`.
- Source coordinator: Codex, Herdr `w5R:p1`.
- Source: `D:/MyNewProjects/qfli_c`.
- Target: `E:/MyNewProjects/QFLIProjects/qflistudio-cpp`.
- Backup: `D:/MyNewProjects/_migration-backup/qflistudio-cpp-20261127`.
- Core path is fixed: `../qflistudio-core`. Dart package remains `qfli_studio_core`.
- Coordinator-accepted CI: run `45892017304`, attempt `2`.

**Inventory only. No deletion, WSL unregister, or WSL command execution.**
The coordinator owns publication, exact source/target comparison, target pull and handoff.
This worker did not execute `compare.sh`, edit the target, or claim final equality.
The coordinator's final integration evidence will record exact observed commits and run results after publication.

## Completed preservation

At 2026-11-27T09:03:38+08:00, 29 paths were preserved under matching relative paths in `backup/source/`: 9,786 files, 5,811,262,437 bytes.
The complete mixed root `build/` tree accounts for 9,162 files and 4,855,516,423 bytes.
Its complete move was explicitly authorized by the coordinator so historical texts remain available to p3.
This is preservation, not deletion or storage reclamation.

Preflight checked exact absolute roots and every existing ancestor, same volume, destination absence, parent Git index, independent ignored status, no reparse points, no nested repository metadata, and process command/executable path references.
Each move used PowerShell `Move-Item -LiteralPath` without overwrite or force.
Read-back verified source absence plus all relative entries, types, lengths and file UTC timestamps at the destination.
No byte-hash verification is claimed for the moved trees.

All paths below are relative to the source and now reside at `backup/source/<relative path>`:

| Relative path | Classification |
| --- | --- |
| `build/` | Mixed generated output and historical progress. P3 must curate portable texts. |
| `.dart_tool/` | Flutter/Dart cache |
| `.flutter-plugins-dependencies` | Generated Flutter dependency state |
| `android/.gradle/` | Gradle cache |
| `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` | Generated registrant |
| `android/local.properties` | Private machine paths |
| `ios/Flutter/Generated.xcconfig` | Generated configuration |
| `ios/Flutter/ephemeral/` | Generated configuration |
| `ios/Flutter/flutter_export_environment.sh` | Generated environment |
| `ios/Runner/GeneratedPluginRegistrant.h` | Generated registrant |
| `ios/Runner/GeneratedPluginRegistrant.m` | Generated registrant |
| `macos/Flutter/ephemeral/` | Generated configuration |
| `native/toolchain/__pycache__/` | Python bytecode cache |
| `native/toolchain/tests/__pycache__/` | Python bytecode cache |
| `native/web/node_modules/` | Installed dependency cache |
| `ohos/.hvigor/` | Generated build/cache state |
| `ohos/entry/.cxx/` | Generated native configuration |
| `ohos/entry/libs/` | Generated packaged libraries |
| `ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets` | Generated registrant |
| `ohos/entry/src/main/resources/rawfile/flutter_assets/` | Generated asset bundle. Original source assets remain untouched. |
| `ohos/entry/src/main/resources/rawfile/qfli_toolchain/` | Generated toolchain package |
| `ohos/local.properties` | Private machine paths |
| `scripts/__pycache__/` | Python bytecode cache |
| `tool/ci/__pycache__/` | Python bytecode cache |
| `tool/forge_content/staging/core-patch/examples.json.index` | Generated intermediate. Tracked patch retained. |
| `tool/forge_content/staging/core-patch/examples.json.merged` | Generated intermediate. Tracked patch retained. |
| `tool/forge_content/staging/core-patch/tutorials.json.index` | Generated intermediate. Tracked patch retained. |
| `tool/forge_content/staging/core-patch/tutorials.json.merged` | Generated intermediate. Tracked patch retained. |
| `web/forge-worker.bundle.js` | Generated web bundle |

## Retained source paths

The following link-containing roots were not moved. No link target was traversed or copied:

- `linux/flutter/ephemeral/`
- `windows/flutter/ephemeral/`
- `ohos/build/`
- `ohos/entry/build/`
- `ohos/entry/oh_modules/`
- `ohos/node_modules/`
- `ohos/oh_modules/`

Active agent definitions/runtime and all Trellis progress/runtime remain in place.
Ignored wrappers, lockfiles, manifests, editor configuration, diagnostic progress and unclassified paths remain in place.
`android/.kotlin/` is an empty retained directory. Its root did not pass the independent ignore check.
Neither ignored status nor a build-like name alone authorizes moving or deleting a path.
`native/build/` belongs exclusively to p2. This worker did not traverse or move it.
Source assets, Git metadata, worktrees, sibling repositories, external signing stores and shared WSL remain untouched.
`ohos/build-profile.json5` remains normally tracked. DevEco password fields are encrypted ciphertext.

## WSL inventory: historical metadata only

No WSL query, startup, export or unregister command ran.
These registrations are carried forward from the existing baseline, not newly verified:

| Distribution | Recorded storage | Ownership |
| --- | --- | --- |
| `Ubuntu` | `D:/WindowsExt/Subsystem/Ubuntu/Ubuntu_2204.1.7.0_x64` | System/shared |
| `qfli-terminal-test` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/ubuntu` | Studio, w65 |
| `qfli-terminal-al3-clean` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3-clean` | Studio, w65 |
| `qfli-terminal-al3-test` | `D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3` | Studio, w65 |
| `qfli-java-build` | `D:/MyNewProjects/qfli_java/build/wsl/qfli-java-build` | Java, w5W |

C++ does not own any listed distribution. No destructive cleanup is authorized.

## Evidence and ownership

External report directory: `D:/MyNewProjects/_pi_reports/qfli_c/2026-11-27`.

- Backup audit: `backup/cpp-handoff-preservation.jsonl`.
- External metadata inventory: `cpp-handoff-preservation-files.jsonl`.
- External move result: `cpp-handoff-preservation-result.json`.
- External resume: `cpp-handoff-resume.md`.
- Tracked concise summary: `preservation-summary.md` in this research directory.
- Prior detailed inventory: `historical-cleanup-procedure-2026-11-27-pre-unified.md` externally.
- Prior handoff: `historical-handoff-draft-2026-11-27-pre-unified.md` externally.

The historical drafts contain obsolete instructions and are evidence only, not executable guidance for this run.
P2 owns native/build. P3 owns portable historical-text curation and narrow `.gitignore` agent-definition rules.
The coordinator owns journal/task JSON, Git writes, publication and final integration.
No commit, push, gate write, target edit, local build, test, lint, analysis tool, package install, artifact download or destructive cleanup was performed by this worker.
