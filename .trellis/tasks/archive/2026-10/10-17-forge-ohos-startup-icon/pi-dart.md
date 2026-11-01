# pi-dart result — OHOS native startup handshake (Dart side)

Task: `.trellis/tasks/10-17-forge-ohos-startup-icon` (Dart worker)

## Outcome

The OHOS Dart entry now mirrors the JVMX startup handshake: the native ArkUI
splash holds the first frame until `AppBootstrap` reports ready **and** the home
route has completed build/layout, real initialization progress is streamed to
the native progress bar, and the frame is released in `finally` so a failed
bootstrap still presents the Flutter fallback.

## Files (production — frozen, root is building)

| File | Change |
| --- | --- |
| `lib/ohos_startup.dart` | **new** — `OhosStartup` controller (no `dart:io`) |
| `lib/main.dart` | separate `androidStartup` / `ohosStartup` handles |

### `lib/main.dart`

- Kept the two handles as distinct variables, so no union-typed `Object`
  (`startup?.holdFirstFrame()` would not compile):
  - `androidStartup` — unchanged predicate
    (`!kIsWeb && defaultTargetPlatform == TargetPlatform.android`).
  - `ohosStartup` — `!kIsWeb && defaultTargetPlatform.name == 'ohos'`. No new
    `dart:io` import and no host getter; works with the installed OHOS SDK's
    `TargetPlatform.ohos` and stays portable if the enum is absent.
- Both call `holdFirstFrame()` before `runApp` (each predicate is exclusive).
- The post-frame callback keeps one `load` closure and chooses the completer:
  `ohosStartup.complete(load)`, else `androidStartup.complete(load)`, else
  `load(null)`.
- `forgeProfile` is byte-for-byte unchanged: same templates, runner,
  `terminalCommandDelegate`, tools page, content repository, offline flag,
  product key, `showHomeTabs`, runtime strings, extensions, entry names.
  `cProfile` alias and `StudioProfile.current = cProfile` unchanged.

### `lib/ohos_startup.dart`

`OhosStartup({required WidgetsBinding binding, MethodChannel? channel})`
(`qflistudio/platform`), minimal like `AndroidStartup`:

- `holdFirstFrame()` → `binding.deferFirstFrame()`.
- `complete(load, {minimum, settle, subscribe})`:
  - `Stopwatch` starts at entry, so the **floor is measured from entry** as in
    JVMX; after `load` only `minimum - elapsed` is awaited (skipped when
    already elapsed), concurrently with `settle` — no timer is left pending
    when `load` throws.
  - `await Future.delayed(subscribe)` (160 ms, JVMX) **before** the first
    report, so a fast bootstrap cannot finish before the native component
    subscribes; then `0.05` initial, then `AppBootstrap` progress.
  - `await binding.endOfFrame` after loading (home route + saved theme built
    and laid out), then `allowFirstFrame()` in `finally`.
- `_reportProgress` is private: drops non-finite values, clamps to `0..1` (the
  ArkTS handler validates `Number.isFinite` and clamps), swallows
  `MissingPluginException` and `PlatformException`. No extra public API beyond
  what the lifecycle needs.
- Deliberately **no** extra pre-load `endOfFrame`: the post-frame callback
  already runs after layout and the native component subscribes
  independently.

Constants: `minimumDisplay` 1100 ms, `settleDelay` 320 ms, `subscribeDelay`
160 ms (all JVMX values).

## Tests — `test/ohos_startup_test.dart` (4 focused cases)

Widget tests run fake timers, so each startup future is started, tracked to
completion via `whenComplete`, and driven with `pump(5ms)` until done; cases
pass `minimum: 40ms`, `settle: 1ms`, `subscribe: 10ms` overrides.

1. **Defers the frame until ready home is laid out** — asserts
   `sendFramesToEngine == false` while loading, initial `0.05` on
   `qflistudio/platform.startupProgress`, bootstrap progress in order
   (`0.05`, `1/3`, `2/3`), home text laid out while the frame is still held,
   then released with home visible and all values within `0..1`.
2. **Releases on bootstrap failure** — `StateError` propagated, frame released,
   remaining timers pumped (no pending-timer failure).
3. **Completes when progress cannot be delivered** — missing channel and
   `PlatformException` both still load and release.
4. **Drops non-finite and clamps out-of-range progress** — `NaN` dropped,
   `-0.5`/`1.5` sent as `0.0`/`1.0` instead of triggering `INVALID_PROGRESS`.

## Commands and evidence

```
D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe \
  D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot analyze --no-pub
  -> No issues found!

... test test/ohos_startup_test.dart --no-pub --timeout 30s
  -> 00:00 +4: All tests passed! (4 cases)
```

Earlier in the session (before production freeze, with production files in
their final shape) the full suite also passed: `test --no-pub --timeout 120s`
→ `All tests passed! (194)` — 190 pre-existing + 4 new. No existing test,
including `test/android_startup_test.dart`, was modified. Per root instruction
the suite was not rerun; production files are unchanged since.

## Notes / limitations

- Dart side is verified; the ArkTS splash and the actual deferred-frame
  release on device are the native worker's and root's gates.
- No native files, icons, bundle IDs, signing, Git or HAP builds were touched
  here.
