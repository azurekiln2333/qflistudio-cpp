# pi-native: OHOS native splash (Index.ets + EntryAbility startupProgress)

Scope owned by this agent: `ohos/entry/src/main/ets/pages/Index.ets` and
`ohos/entry/src/main/ets/entryability/EntryAbility.ets` only. No Dart, icon,
bundle/signing, runtime, Git or HAP-build changes were made here. Root builds
and validates on the phone.

## Reference

Ported from `D:\MyNewProjects\qfli_java\ohos\entry\src\main\ets\pages\Index.ets`
(JVMX) — `StartupSplash`, the `@Builder startupSplash()`, and
`FlutterPage({ viewId, splashScreenView: this.startupSplash })`. The native
`FlutterPage` in the pinned `@ohos/flutter_ohos` already declares
`@BuilderParam splashScreenView` and renders it while `showSplashScreen` is
true (cleared in `onFirstFrame`), so no SDK change is needed.

## pages/Index.ets

- Added `@Component struct StartupSplash`:
  - `@State progress: number` (0..100 for `Progress`), fed by an eventHub
    subscription to `EVENT_STARTUP_PROGRESS` created in `aboutToAppear` and
    removed in `aboutToDisappear` (subscribed only while mounted; after the
    Flutter first frame `FlutterPage` drops the builder).
  - `Image($r('app.media.icon'))` 96x96, `ImageFit.Contain`, radius 24, clipped.
  - Bottom-anchored `Progress` (`ProgressType.Linear`, `total: 100`,
    `strokeWidth: 4`, smooth + scan effects), `constraintSize({maxWidth: 420})`.
  - Splash background uses `$r('app.color.start_window_background')` (same
    resource as the window/ability start background, light + dark) so there is
    no flash between the system start window and the native splashes.
  - Fade-out transition: `TransitionEffect.asymmetric(IDENTITY, OPACITY,
    280ms EaseOut)`, matching JVMX (Flutter reveals underneath).
- `Index` keeps `@LocalStorageLink('viewId')`, `onBackPress` ->
  `EVENT_BACK_PRESS`, and the outer `Column`/background exactly as before; it
  now passes `splashScreenView` to `FlutterPage`.

### Stable component IDs for device UI validation

- `qfli-native-startup-splash` on the splash root `Stack`.
- `qfli-native-startup-progress` on the `Progress` bar.

## entryability/EntryAbility.ets

Added (additive only, `git diff` shows +16/-0 for this file):

```ts
} else if (call.method === 'startupProgress') {
  const progress = call.argument('progress') as number;
  if (typeof progress === 'number' && Number.isFinite(progress)) {
    abilityContext.eventHub.emit(EVENT_STARTUP_PROGRESS, Math.max(0, Math.min(1, progress)));
    result.success(null);
  } else {
    result.error('INVALID_PROGRESS', 'Startup progress must be a finite number', null);
  }
}
```

- Handler lives on the existing `qflistudio/platform` channel, next to
  `openAgreement`/`openUrl`/`shareText`/picker dispatch.
- Validation: non-number and non-finite (`NaN`/`Infinity`) are rejected with
  `INVALID_PROGRESS`; finite values are clamped to `[0, 1]`.
- Emission uses the ability `eventHub` (same hub the page subscribes through
  `getContext(this)`), so no channel re-registration is needed.
- Emitting after the splash is gone is a no-op and still returns success, so
  Dart progress reporting never fails the app.

### Preserved handlers (unchanged)

- `registerQfliNativeChannel` (C compiler backend `qfli_forge/native` +
  `/events`), including the try/catch `QFLI native channel unavailable` path.
- `qflistudio/platform`: `openAgreement`, `openUrl`, `shareText`,
  `isPickerMethod`/`handlePickerCall`, `notImplemented` fallback.
- `qflistudio/huawei_account` `login` flow (Account Kit).
- `onWindowStageCreate` dark/light window background logic.

## Contract for the Dart side (owned by forge-terminal)

- Channel: `qflistudio/platform`, method `startupProgress`, arg map
  `{ 'progress': <double 0..1> }`. Success -> `null`; invalid -> `PlatformException`
  code `INVALID_PROGRESS`.
- `lib/android_startup.dart` currently uses `qfli_forge/startup` (Android
  route); OHOS needs the `qflistudio/platform` channel plus
  `deferFirstFrame`/`allowFirstFrame` (JVMX `lib/main.dart` pattern:
  160ms delay before first report so the splash subscribes, then real
  `AppBootstrap` progress, wait for `endOfFrame`, release in `finally`).

## Checks run here

- Read the JVMX reference and the pinned SDK `FlutterPage.ets` to confirm the
  `splashScreenView` builder contract.
- Icon resources verified identical (SHA256
  `DAEE6BD0...90DD`) across `assets/app_icon.png`,
  `ohos/AppScope/resources/base/media/app_icon.png`,
  `entry/.../resources/base/media/icon.png` and the packaged
  `rawfile/flutter_assets/assets/app_icon.png` — the splash `$r('app.media.icon')`
  therefore shows the current C mascot. No icon files were modified by me.
- Brace/paren/bracket balance check on both edited files: 0/0/0.
- `git diff --stat`: `Index.ets` +64/-2, `EntryAbility.ets` +16/-0.

Not run here (root-owned): ohpm install, hvigor ArkTS check, production HAP
build, HAP icon/bundle inspection, `hdc install -r`, and phone screenshot of
`qfli-native-startup-splash` / `qfli-native-startup-progress`.
