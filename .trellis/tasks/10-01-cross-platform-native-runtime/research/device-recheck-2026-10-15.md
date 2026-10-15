# OHOS device recheck — 2026-10-15 (pi w6 OHOS device acceptance)

Date: 2026-10-15 (device attempt ~02:28 device/local clock)
Role: OHOS 真机验收负责人 (continuation of the completed fix, no re-work of passed tests)
Mode: **device-launch check only.** No source edits, no rebuild, no re-packaging,
no `git add`/`git commit`, no Android device contact, no lock bypass.
Single file written: this report.

## 0. Workspace gate (passed)

```powershell
Get-Location                 # D:\MyNewProjects\qfli_c
git rev-parse --show-toplevel # D:/MyNewProjects/qfli_c
```

Both equal the authorized workspace `D:/MyNewProjects/qfli_c`. Only this repo was
written (this report). The shared core and other sibling workspaces were not
touched. The Android device/emulator was not contacted.

## 1. Context read (no re-run of passed tests)

- `.trellis/tasks/10-01-cross-platform-native-runtime/ohos-status.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/implement.md`
- `.trellis/tasks/10-01-cross-platform-native-runtime/research/acceptance-artifacts-2026-10-15.json`
- `.trellis/spec/backend/ohos-runtime.md`

Per instruction, the already-passed checks reported in `ohos-status.md` (Flutter
analysis 0 issues, 176 VM tests, 7 native bridge host groups, OHOS SDK cross-link,
ArkTS source checks, HAP build/sign/audit, Android build-only audit, 200/200 C/C++
native + 33 content tests) were **not** re-executed. This turn only re-checked the
outstanding device gate.

## 2. Device connection

HDC used:
`D:\ProgramFiles\Huawei\OpenHarmony\Sdk\23\toolchains\hdc.exe`

```text
hdc list targets
192.168.68.207:46551
```

Target device identity (read-only `param get`):

| Property | Value |
| --- | --- |
| `const.product.model` | `MRT-AL10` |
| `const.product.brand` | `HUAWEI` |
| `const.product.name` | `nova 14 Ultra` |

Matches the authorized target exactly (`192.168.68.207:46551`, nova 14 Ultra /
MRT-AL10).

## 3. Installed app

Host audit HAP on disk (per `acceptance-artifacts-2026-10-15.json`):

| kind | path | bytes | sha256 |
| --- | --- | --- | --- |
| ohos-app-audit | `native/build/ohos-audit-20261015.hap` | 213031944 | `1decdeb0b74b26f41bf84bf8f5676e24a4706ba7fddd389cd13410b774ef7424` |

Installed bundle (read-only `bm dump`), target package present:

```text
bm dump -a | grep azurekiln
  com.azurekiln.qfli.forge      <-- target
  ... (other unrelated azurekiln products)

bm dump -n com.azurekiln.qfli.forge
  bundleName   : com.azurekiln.qfli.forge
  versionCode  : 1
  mainAbility  : EntryAbility
  mainElement  : EntryAbility
  entry ability name: EntryAbility (srcEntrance ./ets/entryability/EntryAbility.ets)
  installTime  : 1790355495360
  updateTime   : 1792062087263
```

Package `com.azurekiln.qfli.forge` with `EntryAbility` is installed, consistent
with the documented diagnostic HAP deployment. No signature material is recorded
here (deliberately omitted).

## 4. Launch attempt and result — BLOCKED (screen locked)

Preconditions observed before the attempt:

- No forge process running: `ps -ef | grep -i forge` returned only the grep
  itself, i.e. the app was not started.
- Screen lock present: `hidumper -s WindowManagerService -a '-a'` shows a
  `SCBScreenLock13` lock window.
- Display off: `hidumper -s RenderService -a screen` →
  `screen[0]: id=0, powerStatus=POWER_STATUS_OFF, ...`.

Normal start command (no bypass, no `power-shell wakeup`, no unlock API):

```text
hdc -t 192.168.68.207:46551 shell "aa start -a EntryAbility -b com.azurekiln.qfli.forge"
```

Result (verbatim):

```text
error: failed to start ability.
Error Code:10106102  Error Message:The device screen is locked during the application launch, unlock screen failed.
Error cause: The current mode is developer mode, and the screen cannot be unlocked automatically
  Try the following:
  > Check in the settings whether the current device is in developer mode, and turn off developer mode
```

**This is the same blocker as the prior acceptance attempt (`10106102`).** The
phone screen is locked/off, and developer mode prevents automatic unlock. The
launch cannot proceed and the app never reached first frame.

## 5. Evidence collection for `QFLI_C_OHOS_CASE` / `QFLI_C_OHOS_AUDIT`

Because the app could not launch, no in-app audit could run, so the expected
210/210 (10 base cases + 200 curriculum samples) could not be produced. A
read-only log scan confirmed there is no prior audit evidence either:

```text
hdc -t <target> shell "hilog -x -T 2000 | grep -i QFLI_C_OHOS"
(no output)
```

| Metric | Required | Observed |
| --- | --- | --- |
| `QFLI_C_OHOS_CASE` lines | 10 base cases | **0** (app never launched) |
| Curriculum `QFLI_C_OHOS_CASE` lines | 200 | **0** |
| `QFLI_C_OHOS_AUDIT ok:true` | required | **absent** |
| Pass count | 210/210 | **not produced** |

Therefore `ohosAppExecutionVerified` remains **false**. No failure logs exist to
attribute to app behavior because no case executed; this is an environment/lock
blocker, not an app defect.

## 6. Actions explicitly NOT taken

- Did not bypass the lock screen (no `power-shell wakeup`, no unlock gesture/API,
  no developer-mode change on the device).
- Did not wait in a retry loop; one normal start attempt was made and reported.
- Did not modify shared source, regenerate staging, or re-package any HAP/APK.
- Did not install/start/contact any Android device or emulator.
- Did not run `git add` / `git commit`; left all commits to the coordinator.
- Did not record or expose signing material.

## 7. Required next step (unchanged sequence)

The observed launch blocker is the physical lock. To begin the device gate the user must
**unlock the phone and keep the screen on** (developer mode stays as-is; no
setting change is requested). Then, unchanged from `ohos-status.md`:

1. Launch the installed audit App and capture `QFLI_C_OHOS_CASE` lines for the
   10 base cases plus the 200 curriculum samples, requiring
   `QFLI_C_OHOS_AUDIT {"ok":true,...,"passed":210}`.
2. If any case actually fails, report the concrete log for that case before any
   source change; do not modify shared source or re-package without coordinator
   approval.
3. After in-app audit passes, install the restored `lib/main.dart` production
   release HAP and verify ordinary editor Run/Stop and the tutorial/example
   entries.

## 8. Verdict

**BLOCKED — device screen locked (Error 10106102); no re-verification possible
this turn.**

- Device connected and correctly identified: `192.168.68.207:46551` /
  nova 14 Ultra / `MRT-AL10`.
- Target bundle `com.azurekiln.qfli.forge` / `EntryAbility` (versionCode 1)
  installed; audit HAP SHA256 matches the acceptance record.
- Normal `aa start` fails with `10106102` (screen locked, developer mode). No
  lock bypass attempted.
- `QFLI_C_OHOS_CASE` = 0, `QFLI_C_OHOS_AUDIT` = absent → 210/210 not produced;
  `ohosAppExecutionVerified` stays false.
- No source/package/commit/Android action taken.
