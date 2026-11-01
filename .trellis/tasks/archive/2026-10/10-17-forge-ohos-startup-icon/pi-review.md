# pi-review — independent review: OHOS native startup + icons

Task: `.trellis/tasks/10-17-forge-ohos-startup-icon` (in_progress)
Reviewer: pi (independent). No implementation edits, no build, no install, no Git.
Env: cwd / git root = `D:/MyNewProjects/qfli_c`.

Status: **Interim — awaiting implementation.** Other agents' ArkTS + Dart startup
code has not landed yet (verified). This records the reference contract, the
current parity gaps, the icon audit, and the checks to run on landing.

---

## 1. Reference contract — JVMX startup

`design.md` points at "JVMX `Index.ets`", but `qflistudio`'s `Index.ets` is a bare
`FlutterPage` with no splash and no `startupProgress`. The real reference is
sibling **`qfli_java`**:

- `Index.ets`: `StartupSplash` = `Image($r('app.media.icon'))` 96x96
  (rounded, clipped) + `Progress` driven by `EVENT_STARTUP_PROGRESS`, 420 max
  width, `start_window_background`, 280 ms fade-out transition; passed to
  `FlutterPage({ splashScreenView })`. Subscribes in `aboutToAppear`, unsubscribes
  in `aboutToDisappear`.
- `EntryAbility.ets`: `qflistudio/platform` handles `startupProgress`; validates
  `Number.isFinite`, emits `Math.max(0, Math.min(1, p))` on the eventHub, else
  `INVALID_PROGRESS`.
- `lib/main.dart`: `TargetPlatform.ohos` → `deferFirstFrame`; progress
  0.05 → 0.25 → `0.25 + p*0.75`; 1100 ms minimum display + 320 ms tail; `endOfFrame`;
  `finally allowFirstFrame`.

## 2. Current C baseline — gaps

| Area | Reference | Current `qfli_c` | Gap |
| --- | --- | --- | --- |
| ArkUI splash | `StartupSplash` + `splashScreenView` | bare `FlutterPage` | **MISSING** |
| `startupProgress` handler | in `qflistudio/platform` | same channel, but only `openAgreement`/`openUrl`/`shareText`/picker | **MISSING** |
| Dart OHOS deferral | `TargetPlatform.ohos` → `deferFirstFrame` | `AndroidStartup` is Android-only; OHOS uses plain load | **MISSING** |
| Progress channel | `qflistudio/platform` | `AndroidStartup` uses `qfli_forge/startup` | **MISMATCH** |
| Ready wait | `endOfFrame` + `allowFirstFrame` in `finally` | Android-only | needs OHOS parity |

`lib/android_startup.dart` targets `qfli_forge/startup`, which no ArkTS handler
registers (they register `qflistudio/platform`) — dead for OHOS today, but a trap
if reused by name. After implementation, Dart and ArkTS must agree on **one**
channel; a split name silently no-ops (reference swallows `MissingPluginException`).

## 3. Icon audit — clean

Three sources identical, current C art:

| File | SHA256 | Size |
| --- | --- | --- |
| `ohos/AppScope/resources/base/media/app_icon.png` | `daee6bd…` | 265026 |
| `ohos/entry/src/main/resources/base/media/icon.png` | `daee6bd…` | 265026 |
| `assets/app_icon.png` | `daee6bd…` | 265026 |

- Working tree is newer than HEAD (`assets/app_icon.png` HEAD was `366e7fc…`/24467 B),
  so the icon refresh has landed.
- References complete, nothing stale: `app.json5:7 → $media:app_icon`;
  `module.json5:19,21 → $media:icon` (ability `icon` + `startWindowIcon`);
  Flutter About/splash/login use `assets/app_icon.png` (core ships no icon).
- No script writes icons (`rg` over `tool/*.ps1`), so no overwrite risk;
  `build_ohos_release.ps1` does not touch icons.
- Packaged HAP (root inspection): `app.bundleName == com.azurekiln.qfli.cpp`,
  packaged media re-encoded by the SDK (expected), Flutter asset passes through.
  Consistent — not a defect.
- `ohosTest/.../icon.png` (6790 B) is the test module's own icon; irrelevant.

## 4. Build-time check — not added

The three icons are committed artefacts with no script rewriting them; a guard
could only compare the three sources (a one-line `Get-FileHash`). Adding it would
edit root's in-flight script for little gain. **Recommendation: skip;** hand root
the one-liner (§5.1) instead.

## 5. Validations for root

1. `Get-FileHash` the three icon sources — all must be `daee6bd…`.
2. HAP: `app.bundleName == com.azurekiln.qfli.cpp` and both media entries present.
3. Startup handshake after implementation: one shared channel; finite progress,
   clamped 0..1 in ArkTS; `deferFirstFrame` on `TargetPlatform.ohos` with
   `allowFirstFrame` in `finally`; splash unsubscribes on disappear; native view
   held until theme + home laid out (`endOfFrame`).
4. Then capture device startup; confirm usable home/About.

**Bundle coexistence note:** the phone has BOTH `…qfli.cpp` and `…qfli.forge`
installed. Device verification must target `.cpp` explicitly; root will
update/start `.cpp` without uninstalling. No review action needed — recorded so
no one audits or launches the `.forge` bundle by mistake.

## 6. Non-claims

- The earlier icon-only HAP was inspected for bundle/icons only and predates the
  splash work; this review does not claim that artifact showed a native splash.
- No device/build/install/Git actions performed.

## 7. FINAL REVIEW (implementations landed)

Files reviewed read-only: `lib/main.dart`, `lib/ohos_startup.dart`,
`ohos/.../pages/Index.ets`, `ohos/.../entryability/EntryAbility.ets`.
Automation is root's: root ran analyzer and the 8 focused startup tests.

### Resolved — previously flagged gaps

| Check | Result |
| --- | --- |
| ArkUI splash | `StartupSplash` in `Index.ets`, passed as `splashScreenView`; icon 96x96 rounded/clipped, linear `Progress` (max 420), `start_window_background`, 280 ms asymmetric fade; `aboutToAppear`/`aboutToDisappear` subscribe/unsubscribe | **OK** |
| `startupProgress` handler | in `qflistudio/platform`: `Number.isFinite` guard, `Math.max(0, Math.min(1, p))`, emits `EVENT_STARTUP_PROGRESS`, else `INVALID_PROGRESS` | **OK** |
| Channel agreement | Dart `qflistudio/platform` == ArkTS `CHANNEL_PLATFORM` | **OK** |
| Event name agreement | `'EVENT_STARTUP_PROGRESS'` identical in both ArkTS files | **OK** |
| Progress unit | ArkTS emits 0..1; `Index.ets` converts `p * 100` for `Progress(total:100)` | **OK** (matches JVMX) |
| OHOS deferral | `defaultTargetPlatform.name == 'ohos'` → `OhosStartup`; no `dart:io`, no `isOhos` | **OK** |
| Separate startup vars | `androidStartup` / `ohosStartup` distinct nullables; no mixed ternary `Object` inference | **OK** |
| Frame release | `allowFirstFrame()` in `finally` (load failure still releases) | **OK** |
| Ready wait | `await _binding.endOfFrame` before release | **OK** |
| Progress robustness | non-finite dropped; values clamped 0..1 on the Dart side too; `MissingPluginException`/`PlatformException` swallowed | **OK** |

### Timing vs JVMX (root's explicit ask) — validated OK

Root required: subscription 160 ms, floor started **before** load, settle
**after** load concurrent with the floor.

- `subscribeDelay = 160 ms` awaited before the first progress report — matches
  JVMX (`Future.delayed(160)` then `reportProgress(0.05)`).
- Floor is `Stopwatch`-measured **from `complete()` entry**, i.e. before load:
  after `await load(...)` only `minimum - elapsed` remains and is awaited
  concurrently with `settleDelay`. Equivalent to JVMX creating
  `minimumDisplay` at function entry (line 125) before the 160 ms wait.
- Settle `320 ms` starts after load, concurrent with the remaining floor — matches
  JVMX `Future.wait([minimumDisplay, Future.delayed(320)])`.
- Total delay = `max(minimum, subscribe + load + settle)` (root's verified
  figure). The floor is measured from entry, so the subscribe wait and the
  bootstrap load both count against the 1100 ms minimum; the 320 ms settle is
  measured from when loading finishes, so the two ends are:
  `minimum` and `subscribe + load + settle`.

Earlier intermediate state (floor started only *after* load, giving an extra
1100 ms on warm start) has been corrected; do not re-report.

### Remaining notes (non-blocking, no action requested)

1. **Progress curve differs from JVMX by design.** JVMX maps bootstrap progress
   to `0.25 + p*0.75` because it reserves 0.25 for `JavaProgramRunner.prepare()`.
   `qfli_c` has no prepare phase and reports `0.05` then bootstrap `p` directly,
   staying monotonic within 0..1. Intentional; not a defect.
2. The splash exists only in the current source/this build; the earlier
   icon-only HAP predates it and was never claimed to contain one.

### Non-claims
- No device/build/install/Git actions by this review.
- One attempted local Flutter startup test run was **cancelled** mid-flight by
  root (stale fake timers while the Dart agent was still editing); no result from
  it is used. Test/analyzer evidence quoted here is root's.
- Bundle coexistence unchanged: verify/launch `com.azurekiln.qfli.cpp`
  explicitly (`.forge` is also installed).

