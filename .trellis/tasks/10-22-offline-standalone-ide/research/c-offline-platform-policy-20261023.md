# C/C++ OHOS offline platform policy — October 23, 2026

## Finding and owned change

The actual `EntryAbility.ets` still exposed `openAgreement`, `openUrl` and Huawei
Account `login` directly. A hidden Dart UI did not prevent MethodChannel calls.
The module still requested INTERNET. The local native registration calls the
in-process LLVM/WASI/WasmEdge bridge; the reviewed C runtime paths have no JDWP
or preview listener requiring network access.

The narrow patch adds `OFFLINE_ONLY = true` and early `OFFLINE_ONLY` errors before
argument reads and platform constructors, and removes only the INTERNET entry.
Existing startup-progress changes, window setup, generated plugin registration,
native registration/error handling, picker, share, device types and all signing
or native WIP are preserved. No shared-core file is modified in this batch.

`tool/test_c_offline_platform.cjs` adapts Python's actual-handler VM check to the
C registration and startup behavior. SDK discovery also accepts C's existing
`hwsdk.dir` property. It requires installed SDK TypeScript and has no dependency
download step.

## Original source-only validation handoff

Source review only. The shared Web then JSON validation queue forbids running
tests, Node, analysis, formatting or builds in this worker. No pass is claimed.
The root should run the positive behavior check and both negative controls when
its serial slot becomes available. Example PowerShell commands:

```powershell
node tool/test_c_offline_platform.cjs

git show :ohos/entry/src/main/ets/entryability/EntryAbility.ets |
  Set-Content -Encoding utf8 "$env:TEMP/qfli-c-entry-staged-old.ets"
node tool/test_c_offline_platform.cjs "$env:TEMP/qfli-c-entry-staged-old.ets"
# Must fail while the index still contains the unguarded edition.

$cPolicySource = [IO.File]::ReadAllText("$PWD/ohos/entry/src/main/ets/entryability/EntryAbility.ets")
$cPolicyDisabled = $cPolicySource.Replace('const OFFLINE_ONLY = true;', 'const OFFLINE_ONLY = false;')
[IO.File]::WriteAllText("$env:TEMP/qfli-c-entry-policy-disabled.ets", $cPolicyDisabled, [Text.UTF8Encoding]::new($false))
node tool/test_c_offline_platform.cjs "$env:TEMP/qfli-c-entry-policy-disabled.ets"
# Must fail because the browser/provider is reached.
```

Save the old staged edition before staging the policy hunk. A negative result
from SDK discovery or transpilation is insufficient: confirm that the failure
comes from the remote handler/provider assertions. These host checks remain
separate from ArkTS/hvigor, signed-HAP inspection, native compile/run and device
acceptance. The umbrella R1/R10 acceptance remains open until those gates finish.

## Executed host checks — October 24, 2026

Under the explicitly accepted C415 host window, all four driver expectations
passed. The full current source with `--require-startup` exited 0. The exact
policy-only source edition exited 0 and explicitly reported that its original
startup-progress handler is absent. Both the old source and the policy-disabled
source exited 1 because `Unexpected browser` proved the browser path was reached;
neither negative depends on missing SDK discovery or transpilation failure.

The positive checks exercise the actual registered handlers with installed SDK
TypeScript and local doubles, including no argument reads/provider calls for
denied methods, single response, local picker/share, native registration, and
window setup. The full-source edition additionally exercises the separately
owned startup-progress handler. Only the policy changes and permission removal
are published; startup, signing and device-type changes remain outside this
commit. Exact source/log hashes and process exits are recorded in
`c-offline-platform-verification-20261024.json`.

These are host checks. ArkTS typing, HAP permissions and actual installed-app
runtime behavior remain unverified for this new policy commit. No device action
occurred, and the full offline IDE umbrella remains in progress.
