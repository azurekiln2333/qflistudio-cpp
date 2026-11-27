# Forge OHOS asset size audit — 2026-10-17

READ-ONLY analysis. Nothing deleted, edited or rebuilt. Sources: packaged
`ohos/entry/src/main/resources/rawfile/flutter_assets/**` (the staged HAP copy),
`lib/**`, `../qfli_studio_core/lib/**`, both `pubspec.yaml`. No device/build run.

## Used on Forge OHOS

| Asset | Bytes | Why it is reachable |
| --- | --- | --- |
| `tool/forge_content/staging/forge_tutorials.json` | 472 105 | `ForgeContentRepository` (only content repo Forge installs) |
| `tool/forge_content/staging/forge_examples.json` | 236 704 | same repository |
| `assets/app_icon.png` | 265 026 | `SplashScreen`, About/Home branding |
| `packages/qfli_studio_core/assets/fonts/roboto_mono/static/*.ttf` (4) | 365 172 | `EditorFonts.bundledFamily` — editor font |
| `packages/qfli_studio_core/assets/fonts/roboto_mono/OFL.txt` | 4 488 | license registered by `EditorFonts` |
| `fonts/MaterialIcons-Regular.otf`, `shaders/*.frag`, `NOTICES.Z`, `FontManifest.json`, `AssetManifest.bin` | 191 731 | engine/toolkit runtime |

Reachability check: `main.dart: contentRepositoryFactory: ForgeContentRepository.new`
→ `home_page.dart:59` builds that **one** repo; `LocalTutorialsTab` and
`ExampleCodeTab` (lazy tabs 2 and 3) receive it via `repository:` and call
`Filter.forProduct('forge')` = `{'c','cpp'}`. `AssetContentRepository`
(`assets/content/*`) is only the `??` fallback, and `TutorialService`
(`assets/tutorials/*.json`) has **no non-test caller** in either repo.

## Genuinely unused on Forge OHOS (10 assets, 6 807 831 B ≈ 6.49 MiB)

| Asset | Bytes | Verdict |
| --- | --- | --- |
| `packages/qfli_studio_core/assets/content/tutorials.json` | 3 969 122 | unused — `AssetContentRepository` never instantiated (Forge passes its own repo everywhere it is nullable) |
| `packages/qfli_studio_core/assets/content/examples.json` | 1 904 586 | unused — same |
| `packages/qfli_studio_core/assets/tutorials/python.json` | 378 456 | unused — `TutorialService._readAsset` has no production caller |
| `packages/qfli_studio_core/assets/tutorials/java.json` | 249 035 | unused — same |
| `packages/qfli_studio_core/assets/tutorials/web.json` | 16 495 | unused — same |
| `packages/qfli_studio_core/assets/tutorials/dart.json` | 14 252 | unused — same |
| `packages/qfli_studio_core/assets/tutorials/c.json` | 13 801 | unused — same (C content ships in Forge staging) |
| `packages/qfli_studio_core/assets/tutorials/cpp.json` | 2 279 | unused — same |
| `packages/qfli_studio_core/assets/tutorials/lua.json` | 2 177 | unused — same |
| `packages/cupertino_icons/assets/CupertinoIcons.ttf` | 257 628 | unused — no `CupertinoIcons.` reference in app or core |

Caveats that keep this "potential" rather than auto-deletable:
`packages/qfli_studio_core/assets/content/*` and `assets/tutorials/` are
declared by the **shared core** pubspec (all products), so removal belongs to
a Forge-only packaging step, not to core. `AssetContentRepository` is still
constructed as a fallback inside shared pages; a future change that stops
passing `repository:` would silently need those two JSONs again.

## Exact potential savings

Measured on the staged HAP copy (`flutter_assets` total 8 343 057 B):

- 10 unused assets: **6 807 831 B (6.49 MiB)** — assets shrink to
  **1 535 226 B (1.46 MiB), −81.6 %**.
- Current HAP is 151 351 796 B (144.34 MiB); removing these entries alone
  estimates 144 543 965 B (137.85 MiB, −4.5 %), subject to rebuilt manifests
  and signing/container overhead. No package has been changed.
- Largest wins: `content/tutorials.json` 3.97 MB + `content/examples.json`
  1.90 MB + `tutorials/python.json` 0.38 MB + `tutorials/java.json` 0.25 MB
  = 6.50 MB of the 6.81 MB.
- Keep: Forge staging (708 809 B), `app_icon.png` (265 026 B), RobotoMono
  TTFs + OFL (369 660 B), engine/toolkit runtime.

Nothing here is removed; Forge staging, app icon, editor fonts, templates and
every lazy route stay intact.
