# Planning audit baseline

Observation date: 2026-11-26. This is a planning snapshot, not completion evidence.

## Coordinator-verified identity and Git baseline

- Source: D:/MyNewProjects/qfli_c, Herdr w5R:p1.
- Destination: E:/MyNewProjects/QFLIProjects/qflistudio-cpp, Herdr w6J:p1.
- Four source pi workers: w5R:p2, w5R:p3, w5R:p4, w5R:p5.
- Destination also has four pi workers. They have not been handed ownership.
- The singular E:/MyNewProjects/QFLIProject does not exist.
- Both primary repositories initially had clean git status on main.
- Both HEADs and the live GitHub main advertised by git ls-remote were 9ff5ce6b80de46011490fdc84db098d48758eb26.
- Both committed trees were 7258defc922596dfa07c6b22dc8089c26780ffbf.
- Source remotes: github, cnb, gitcode, gitee, gitlab.
- Destination remote: origin, pointing only to GitHub azurekiln2333/qflistudio-cpp.
- GitHub advertised main plus ci/app-installers at 1969ef40d69134e45eaab6b558d71b96cf9be68a and ci/ui-core-installers-20261121 at dcb4355a6e9e3526db8b69956959dc1680a44872.
- Creating the approved planning task tree added five untracked task directories. Initial cleanliness no longer describes the current source worktree.

## Branch and worktree audit from Herdr pi w5R:p2

The worker inspected all six registered linked worktrees. Four were dirty. Every non-backup local branch tip was already contained in main.

| Worktree below D:/MyNewProjects/_wt | Tracked dirty | Untracked |
| --- | ---: | ---: |
| qfli-c-ui-sync/qfli_c | 0 | 0 |
| qfli_c-ci-app-installers | 1 | 1 |
| qfli_c-wp-ci | 4 | 3 |
| qfli_c-wp-env-core | 10 | 16 |
| qfli_c-wp-env-ui | 9 | 2 |
| qfli_c-wp-icons | 0 | 0 |

All 46 dirty paths already exist on main. The worker reported 34 postimages matching main exactly or after CRLF normalization. Twelve differ and require explicit disposition. Differences include stale Trellis reports, older CI helpers, older toolchain interfaces, and older test compatibility getters. Do not overwrite current main from them.

backup/main-before-sync-20261125 has 22 ancestry-unique commits. The worker classified 19 as patch-equivalent, two as merges, and one as unmatched: ed4c9c02892ac13900f37c6ad8cf4271e5d44ab7. Six of its seven postimages match main. Its remaining change is ohos/build-profile.json5. Do not merge this backup wholesale.

The worker identified nonempty signing-password fields in the current tracked OHOS profile, without printing values. Correction (2026-11-27, owner-confirmed): DevEco stores these fields as ciphertext, decryptable only with the local `~/.ohos/config/material`. They are not plaintext credentials. `ohos/build-profile.json5` stays tracked as-is, and no history remediation is needed.

The worker found stash-like dangling/reflog-protected snapshots. Their safe deltas require disposition before cleanup. refs/stash was absent. Do not assume ordinary stash recovery covers them.

## Trellis and portability

The coordinator counted 496 tracked Trellis paths before the planning task tree. PROJECT_STATUS.md still describes 9e34dcc versus dcb4355 and 32 unpublished commits. Those claims are stale against the live baseline above.

.trellis/.gitignore excludes identity, runtime state, bytecode, and atomic temporary files. Three archived research .log files are ignored. Preserve indispensable historical evidence through sanitized tracked summaries. Do not force-add every ignored file.

The Trellis worker reported missing archived manifest targets and a missing workflow-state-contract.md reference. Local platform skills are ignored. Fresh-clone documentation must not depend on those local copies alone. Eleven generic spec guidelines remain marked To fill; do not mark bootstrap complete.

pubspec.yaml:14,35 and pubspec.lock reference ../qfli_studio_core. The destination sibling is named qflistudio-core. This is a real migration gap. Installer workflows and prepare_core.py pin cbaa4a4166461baafff7c1a343bd3ca1865fcc4f. The worker observed different source/destination core states while other coordinators were active. Coordinate the accepted core revision through Herdr; do not silently upgrade or copy a dirty shared core.

## Current cloud evidence verified by coordinator

Application installers run 45645017677 succeeded at 9ff5ce6b80de46011490fdc84db098d48758eb26. Its API metadata listed 18 successful jobs. These included the reusable native workflow, its artifact gate, Python CI helper tests, and all six application platforms.

Seven non-expired application artifacts were present:

- app-android-arm64-v8a
- app-android-x86_64
- app-windows-x64
- app-linux-x64
- app-macos-universal
- app-ios-arm64-unsigned
- app-ohos-arm64-unsigned

The same run also listed native Android/iOS/OHOS artifacts, iOS slices, OHOS WASI resources, and build logs. The newest standalone native run was 44001588302 at ba5c33a, but that does not describe the reusable native jobs inside the newer installer run. Earlier worker comments suggesting the installer necessarily used the old standalone run are superseded by this evidence.

The coordinator found the Python unit-test job and no flutter test or flutter analyze command in the two workflows. The CI worker also reported missing Dart analysis, actionlint, and shellcheck. Flutter validation coverage requires implementation work. Native/intermediate artifacts and final packages use bounded retention, mostly 30 days for packages and 7 days for logs/slices. Artifact payloads were not downloaded. Their internal digests/provenance and device runtime were not independently revalidated locally.

Signing states remain distinct: Android test-signed, Windows/Linux unsigned, macOS ad hoc, iOS/OHOS unsigned. Cloud packaging success does not make unsigned mobile packages device-installable.

## WSL and cleanup boundary verified by coordinator

wsl --list --verbose showed five stopped WSL2 distributions. Registry metadata identified:

| Distribution | Registered storage |
| --- | --- |
| Ubuntu | D:/WindowsExt/Subsystem/Ubuntu/Ubuntu_2204.1.7.0_x64 |
| qfli-terminal-test | D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/ubuntu |
| qfli-terminal-al3-clean | D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3-clean |
| qfli-terminal-al3-test | D:/MyNewProjects/qflistudio/.artifacts/terminal-runtime-test/al3 |
| qfli-java-build | D:/MyNewProjects/qfli_java/build/wsl/qfli-java-build |

None was established as exclusively C/C++ owned. No distro was started, shut down, compacted, unregistered, or deleted. Coordinate shared owners through Herdr before cleanup.

Source build/ and .dart_tool/ exist. Sizes and deletion-safe inventories are deferred. No output directory has been approved for removal. Do not equate ignored status with disposability.

## Execution record and remaining gate

All four pi workers were switched to gpt-6.1-sol and verified through Herdr. The CI worker encountered repeated provider timeouts/rate-limit failures and an HTTP 525 failure. It was switched to deepseek-v4.1-flash after retries. Coordinator independently checked key cloud evidence.

No branch merge, commit, push, target pull, workflow dispatch, product test, lint, build, dependency install, artifact download, or deletion was performed. Only approved planning records were written. Product implementation awaits review of the plan. Exact signing-backup disposition and shared cleanup ownership must stay explicit.
