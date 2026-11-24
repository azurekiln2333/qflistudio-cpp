# Work package ICONS: the OHOS icon on every platform

Read `wp-common.md` first.

- Worktree: `D:/MyNewProjects/_wt/qfli_c-wp-icons` (branch `wp/icons`)
- Report: `reports/wp-icons.md`

## Why

The user wrote: "图标能不能跟随ohos已配置的图标 几个平台都一样". The OHOS
build shows the new icon. Android, iOS, macOS, Windows, Linux and the web
still show Flutter placeholders or the old icon. After this package every
platform shows the OHOS icon.

## Source image

`ohos/entry/src/main/resources/base/media/icon.png`: 1024×1024, 8-bit RGB, no
alpha, 265026 bytes, git blob `4a004e995ec9534bbc36f1cb8830d5f2d65f6f44`. It
shows a white mascot shaped like the letter C with a pencil, a code window and
a laptop on an indigo background. It is the single source. Do not edit it.

Look at the image before you start. Measure two things and put them into the
report: the background colour, and whether the border of the image is flat
(one colour within a small tolerance). The rules below assume a flat border.
When the border is not flat, stop the padded variants (Android adaptive, web
maskable), report it, and deliver the rest.

## Owned files

- `tool/icons/**` (new): generator, its test
- `assets/app_icon.png`
- `ohos/AppScope/resources/base/media/app_icon.png`
- `android/app/src/main/res/**` (launcher icon resources only)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/*`
- `windows/runner/resources/app_icon.ico`
- `linux/packaging/icons/*` (new)
- `web/favicon.png`, `web/icons/*`

## Deliverables

1. `tool/icons/generate_app_icons.py` (Python 3, Pillow, LANCZOS). One run
   rewrites every generated file from the source image. The output is
   deterministic. `--check` generates in memory, compares decoded pixels with
   the files on disk, names each file that differs and exits 1.
2. The generated files:

| Target | Files | Rule |
| --- | --- | --- |
| Flutter asset | `assets/app_icon.png` | byte copy of the source |
| OHOS application | `ohos/AppScope/resources/base/media/app_icon.png` | byte copy of the source |
| Android legacy | `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (48, 72, 96, 144, 192 px) | full square artwork |
| Android 8+ | `mipmap-anydpi-v26/ic_launcher.xml`, one foreground PNG per density (108, 162, 216, 324, 432 px), background colour resource | adaptive icon, see below |
| iOS | every PNG in `AppIcon.appiconset` | same file names and pixel sizes as now, `Contents.json` unchanged, RGB without alpha |
| macOS | every PNG in `AppIcon.appiconset` | same file names and pixel sizes as now, `Contents.json` unchanged, macOS shape, see below |
| Windows | `windows/runner/resources/app_icon.ico` | 16, 24, 32, 48, 64, 128, 256 px, full square artwork |
| Linux | `linux/packaging/icons/app_icon_<N>.png`, N = 16, 24, 32, 48, 64, 128, 256, 512 | full square artwork |
| Web | `web/favicon.png`, `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` | same pixel sizes as now, maskable rule below |

The two byte copies matter. Unpublished local history already holds exactly
this blob at both paths. A byte-identical file merges without a conflict.
Check both with `git hash-object`.

## Shape rules

"The same on every platform" means the same artwork and the same background
colour. The system or the file supplies the outline, by platform convention.

- OHOS and iOS mask a full square image. Deliver the full square without
  alpha.
- Android 8 and later mask an adaptive icon. A legacy square PNG alone sits
  shrunk inside a white shape there. So add the adaptive icon. The foreground
  is a 108 dp canvas filled with the background colour, with the source image
  pasted in the centre. The background layer is the same colour. Scale: the
  source square equals the 72 dp viewport, unless the content then leaves the
  66 dp safe circle. In that case scale down until the content is inside.
  "Content" means the pixels that differ from the background colour. Measure
  the largest distance of a content pixel from the centre. Keep the resource
  name `ic_launcher`: `AndroidManifest.xml` refers to `@mipmap/ic_launcher`
  and you do not edit it.
- Web maskable icons follow the same rule: canvas in the background colour,
  content inside the centre circle with a radius of 40 % of the icon size.
- macOS masks nothing, and a full square looks wrong in the Dock. Bake the
  macOS shape into the files: a rounded rectangle of 824×824 px in the centre
  of a transparent 1024×1024 canvas, corner radius 185 px, with the full
  square artwork scaled to 824×824 inside. Anti-alias the edge. No shadow is
  required. Derive every size from that master.
- Windows and Linux show the file as it is. Deliver the full square.
- `app_icon.ico`: three tools read it, `rc.exe` (the runner resource), Inno
  Setup 6 (`SetupIconFile`) and NSIS 3 (`Icon`). Store the entries below 256 px
  as uncompressed 32-bit BMP and the 256 px entry as PNG. All three tools
  accept that layout. Pillow writes every entry in one format, so check what
  your Pillow version writes and assemble the container yourself when needed.
- Small sizes (16 to 32 px) come from the same downscale. No hand tuning is
  expected.

## Tests and checks

- `tool/icons/test_generate_app_icons.py` (unittest): pixel size of every
  output, no alpha in the iOS files, the entry list and the entry formats of
  the `.ico`, adaptive and maskable content inside the safe circle, `--check`
  passes on the generated tree and fails after one changed pixel in a
  temporary copy.
- `python tool/icons/generate_app_icons.py --check` passes.
- `python -m unittest discover -s tool/icons -p "test_*.py"` passes.
- The adaptive icon XML is well formed. When a local Android SDK holds
  `aapt2`, compile the resources with it. Otherwise say that only the cloud
  build proves them.
- `git status --short` in the worktree lists owned files only.
- Write a contact sheet to
  `D:/MyNewProjects/qfli_c/.trellis/tasks/11-18-desktop-env-icons-packages/reports/wp-icons-contact-sheet.png`:
  every generated variant on a grey checkerboard, labelled, with a circle mask
  preview for the adaptive and maskable variants. The main session reviews the
  icons with it. Look at it yourself first: no seam around the pasted artwork,
  no clipped content, no dark fringe on the macOS edge.

Runners do not hold Pillow, and no workflow calls the generator. The test
runs locally only. Say so in the report.
