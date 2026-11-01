# OHOS terminal and shared UI delivery — 2026-10-17

Completed and installed the signed production `lib/main.dart` HAP on the
user-authorized nova 14 Ultra / MRT-AL10 at `192.168.68.207:46551`.
Bundle: `com.azurekiln.qfli.forge`, ability: `EntryAbility`.

## Resolved defects

- `forgeProfile` lacked `terminalCommandDelegate`. OHOS terminal Clang commands
  now reach the actual signed in-process compiler, with persistent output,
  separate program execution, argv, diagnostics, statuses and cancellation.
  Editor Run and the terminal share one event stream and unique run IDs.
- The generated package config overrode the sibling core with an ignored
  `shared-core-7768b91a3ea3` snapshot. Refreshed it to the live core at
  `183865fcff8884f395350de219e604b8040ac082`, and added a release build script
  that refreshes dependencies and verifies both core and re_editor roots.
- NAPI called `qfli_compiler_command` before the merged compiler archive had
  been rebuilt. Recompiled/staged both OHOS adapters, verified the new symbols,
  and reran the exact DevEco/Hvigor assembleHap route successfully.
- An interrupt during asynchronous toolchain preparation could be lost before
  `runStreams` received its cancel callback. Fixed the shared backend and
  verified the reproduced lifecycle case.

## Herdr collaboration

The three existing QFLI C pi agents were coordinated through Herdr:

| Agent | Pane | Completed work |
| --- | --- | --- |
| forge-native | w6:p4 | Native diff review, exact DevEco/Hvigor build and symbol/link checks |
| forge-terminal | w6:p5 | 190 app tests, expanded device audit entry, ArkTS regression |
| forge-core | w6:p7 | Live core resolution, About/header/My review, 166 focused core/app checks |

Root integrated the adapters, cancellation fix, dependency guard, signed builds,
artifact verification and phone installation/interaction. An additional native
test worker prepared the task-specific Linux host and ran the actual NAPI
regression without rebuilding LLVM.

## Validation

- Application tests: **190 passed**; full static analysis: **No issues found**.
- Focused core/UI/shell/app checks: **166 passed** (overlap with the full app
  suite is intentional; counts are not summed).
- Actual host compiler/interpreter/NAPI regression: original 31 runs plus new
  terminal cases passed, including object linking, C++ exceptions, argv/cwd,
  preprocessing stdout, clang++ on a .c input, errors and cancellation recovery.
- Actual ArkTS regression: passed resource preparation/hashes/cache repair,
  cancellation, native failure propagation and output/status preservation.
- DevEco/Hvigor command from the user's failure log: **BUILD SUCCESSFUL**.
- `tool/build_ohos_release.ps1`: signed production release built with the live
  sibling core. Packaged resources, dependency hashes, native dependencies and
  16 KiB ELF load alignment passed verification.

## Phone verification

The signed alternate-entry audit used the production profile/delegate, actual
sandbox backend and native channel. Its native runner SHA256 equals the final
production runner. `QFLI_OHOS_TERMINAL_AUDIT` reported **ok:true, 20/20 cases**,
elapsed **4248 ms**. The cases cover version/help, C/C++ compile/run, spaced
arguments, object output/link/run, clang++ .c mode, -E file/stdout, subdirectory
cwd, quoted paths/-D, exit 7, compile diagnostics and recovery.

Afterward, restored the signed production HAP with `hdc install -r`, preserving
app data, and launched it successfully (PID 58103). Ordinary UI checks passed:

- Five home-tab screenshots show primary-tinted titles and the My title `我的`.
- About displays QFLIForge branding, C/C++ description, feedback group
  `694120628`, and the copy-group button.
- Tools → terminal → typed `clang --version`: actual Clang **22.1.0** output.
- Existing test project `ohos_cpp_verified_20261016`: editor Run produced
  `Hello, QFLIStudio+!`; the terminal Stop button produced **exit code 130**;
  another Run succeeded afterward. Source files were not edited.

The phone initially blocked launch with lock error 10106102. The user unlocked
it; all phone checks above were subsequently completed. The audit app is no
longer installed as the final entry: the delivered build is the production UI.

## Artifacts

- Production HAP: `build/ohos/hap/entry-default-signed.hap` (144.0 MB).
- Production HAP SHA256:
  `7c527c571ce26c8308f4cf95b52407379ffa7c7e0299c46c750a048567dbd9a7`.
- Native runner SHA256:
  `cde3ce8fd0a65c884a06ea45829f1c381246d29049a4db2515a274ae64e7763d`.
- Full machine-readable case/results record: `delivery.json` beside this file.
- Logs/screenshots under `native/build/forge-terminal-*`,
  `native/build/forge-production-*`, and `native/build/herdr-*`.

Terminal compilation uses the existing WASI target/interpreter. The supported
compiler option subset is documented in README; unsupported shell constructs
and compiler options retain explicit errors. No remaining acceptance failures.
No Git commit/push was requested. Existing unrelated signing/module/core edits
were preserved.
