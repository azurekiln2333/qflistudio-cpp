# WP-ICONS report

Status: `DONE`

Worktree `D:/MyNewProjects/_wt/qfli_c-wp-icons`, branch `wp/icons`. Nothing was
committed and nothing was pushed.

## 1. Source measurements

Both numbers come from `python` with Pillow 12.0.0, read from
`ohos/entry/src/main/resources/base/media/icon.png` (1024×1024, mode `RGB`, no
alpha, 265026 bytes).

- **Background colour: `#4B45E9` = (75, 69, 233).** The most frequent colour of
  the file counts 720578 of 1048576 pixels. The generator reads it from the
  border at every run, so the file and the generated PNGs and XML cannot drift
  apart.
- **Border is flat.** All 4096 border pixels (the top row, the bottom row and
  both side columns) hold exactly one colour, tolerance zero, no pixel within
  a tolerance of 1, 2, 4, 8 or 16 differs. The flat-border rule holds, so the
  adaptive and the maskable variants were generated.
- **Content extent.** The pixels that differ from the background fill the
  bounding box (156, 187)–(888, 836). The largest distance of a content pixel
  from the centre is 428.68 px, which is 0.4186 of the icon side. That is more
  than the Android safe radius (33/108 = 0.3056 of the canvas at the viewport
  scale) and more than the maskable 40 % radius. Both padded variants
  therefore scale the artwork down. The rules below say how far.

## 2. Files changed

New in `tool/icons/`:

- `tool/icons/generate_app_icons.py`
- `tool/icons/test_generate_app_icons.py`
- `tool/icons/contact_sheet.py` (review helper, writes the contact sheet)

The two byte copies (blob `4a004e995ec9534bbc36f1cb8830d5f2d65f6f44` at both):

- `assets/app_icon.png`
- `ohos/AppScope/resources/base/media/app_icon.png`

Android, legacy square (modified):

- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192)

Android, adaptive icon (new):

- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png` (108)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png` (162)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png` (216)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png` (324)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png` (432)

iOS, `Contents.json` unchanged:

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` (20)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` (40)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` (60)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` (29)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` (58)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` (87)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` (40)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` (80)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` (120)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` (120)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` (180)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` (76)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` (152)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` (167)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (1024)

macOS, `Contents.json` unchanged:

- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`

Windows:

- `windows/runner/resources/app_icon.ico`

Linux (new):

- `linux/packaging/icons/app_icon_16.png`
- `linux/packaging/icons/app_icon_24.png`
- `linux/packaging/icons/app_icon_32.png`
- `linux/packaging/icons/app_icon_48.png`
- `linux/packaging/icons/app_icon_64.png`
- `linux/packaging/icons/app_icon_128.png`
- `linux/packaging/icons/app_icon_256.png`
- `linux/packaging/icons/app_icon_512.png`

Web:

- `web/favicon.png` (16)
- `web/icons/Icon-192.png` (192)
- `web/icons/Icon-512.png` (512)
- `web/icons/Icon-maskable-192.png` (192)
- `web/icons/Icon-maskable-512.png` (512)

`git status --short` in the worktree lists these 44 entries and nothing else.
`git status --short -- linux/flutter windows/flutter macos/Flutter` is empty,
so the generated plugin files did not change and `flutter pub get` was not run.

## 3. Checks I ran

All commands ran in `D:/MyNewProjects/_wt/qfli_c-wp-icons` with
`PYTHONIOENCODING=utf-8` and `python` = Python 3.13 with Pillow 12.0.0.

1. `python tool/icons/generate_app_icons.py`
   Result: `50 files written`, exit 0.
2. `python tool/icons/generate_app_icons.py --check`
   Result: `50 files match`, exit 0.
3. `python -m unittest discover -s tool/icons -p "test_*.py"`
   Result: `Ran 22 tests in 15.144s` … `OK`, exit 0.
   The same command with `-W error::ResourceWarning` also ends `OK`, so no test
   leaks an image handle.
4. `git hash-object assets/app_icon.png` → `4a004e995ec9534bbc36f1cb8830d5f2d65f6f44`
   `git hash-object ohos/AppScope/resources/base/media/app_icon.png` →
   `4a004e995ec9534bbc36f1cb8830d5f2d65f6f44`
   Both equal the blob the brief names.
5. Determinism: two consecutive runs gave the same SHA-256 for
   `windows/runner/resources/app_icon.ico` and for `web/icons/Icon-192.png`
   (`ico deterministic: True`, `png deterministic: True`). The PNG output is
   written by Pillow with `optimize=True` and no metadata, so the bytes are a
   function of the pixels only.
6. `--check` fails on one changed pixel. I saved a copy of
   `web/icons/Icon-512.png`, set the pixel (256, 256) to (1, 2, 3), and ran
   `--check`:
   Result: `differs: web/icons/Icon-512.png`, `1 of 50 files differ`, exit 1.
   I restored the file from the copy and re-ran: `50 files match`, exit 0. A
   fresh `render()` compared byte for byte with the restored file returned
   `restored identical: True`. The same test also runs inside the unittest as
   `CheckModeTest.test_check_mode_fails_after_one_changed_pixel`, in a
   temporary copy of the tree.
7. Android resources with `aapt2`:
   `D:/ProgramData/Android/Sdk/build-tools/37.0.0/aapt2.exe compile --dir android/app/src/main/res -o D:/MyNewProjects/_scratch/icons/res.zip`
   Result: exit 0, no diagnostics, 159698 bytes. The compiled archive holds
   `mipmap-anydpi-v26_ic_launcher.xml.flat`,
   `values_ic_launcher_background.arsc.flat` and the ten
   `mipmap-*_ic_launcher*.png.flat` files, so `aapt2` accepts the adaptive XML
   and resolves both resource names.
8. The two XML files also parse with `xml.dom.minidom` (asserted in the
   unittest).
9. Safe-circle measurements, from a script over the generated files, counting
   a pixel as content when any channel differs from (75, 69, 233):

   | Variant | largest content distance / icon size | limit |
   | --- | --- | --- |
   | adaptive mdpi (108) | 0.2992 | 0.3056 |
   | adaptive hdpi (162) | 0.2902 | 0.3056 |
   | adaptive xhdpi (216) | 0.2870 | 0.3056 |
   | adaptive xxhdpi (324) | 0.2846 | 0.3056 |
   | adaptive xxxhdpi (432) | 0.2835 | 0.3056 |
   | `Icon-maskable-192.png` | 0.3980 | 0.40 |
   | `Icon-maskable-512.png` | 0.3990 | 0.40 |

10. `.ico` layout, read with `struct`:
    header `(0, 1, 7)`, 134677 bytes. Entries in this order:
    `16 bmp 32bpp`, `24 bmp 32bpp`, `32 bmp 32bpp`, `48 bmp 32bpp`,
    `64 bmp 32bpp`, `128 bmp 32bpp`, `256 png`. The BMP entries carry two
    heights (`size * 2`), 32 bits and no compression. The directory offsets are
    strictly increasing and lie inside the file (asserted in the unittest).
    Pillow reads all seven entries: `PIL.Image.open(...).info['sizes']` returns
    the set of seven sizes and each `load()` succeeds.
11. macOS master: the alpha bounding box of `app_icon_1024.png` is
    `(100, 100, 924, 924)`, i.e. 824×824 centred in 1024, and the four canvas
    corners have alpha 0. The corner arc carries 2380 partial-alpha pixels, so
    the edge is anti-aliased. A 200×200 nearest-neighbour zoom of the top-left
    corner shows a clean arc with no dark or bright ring, and the partial
    pixels never drop below the background colour minus 4 (unittest).
12. No seam in the adaptive foreground: a 140×140 nearest-neighbour zoom of
    `mipmap-xxxhdpi/ic_launcher_foreground.png` around the artwork is uniform
    `(75, 69, 233)`, and every pixel of the top row of that file is exactly the
    background colour.
13. iOS files are mode `RGB` with empty `info` (no `transparency` key) and
    `has_transparency_data` is false (unittest). macOS files stay `RGBA` as
    before. All 15 iOS and 7 macOS file names and pixel sizes are unchanged and
    both `Contents.json` files are untouched.
14. Contact sheet: `python tool/icons/contact_sheet.py <path>` →
    `sheet: 1092x1866, 49 variants`. I opened
    `reports/wp-icons-contact-sheet.png` and looked at it. Every variant shows
    the same artwork and background, the two adaptive and the two maskable
    cells have their red circle preview, and no cell is clipped or empty.
15. `python -m py_compile` on the three scripts: exit 0.

## 4. What I did not verify, and why

- **No device or OS showed an icon.** Nothing was run on Android, iOS, macOS,
  Windows or a Linux desktop. I proved the files and the resource wiring only.
  Nobody has seen the new launcher icon on a real home screen, in the Dock, in
  the Start menu or in a browser tab.
- **`rc.exe`, Inno Setup 6 and NSIS 3 were not run.** No `rc.exe` was on this
  computer and I installed nothing. The `.ico` layout follows the documented
  rule (BMP below 256, PNG at 256) and Pillow reads every entry, but the three
  consumers are untested. The cloud `app-windows-x64` run compiles the runner
  resource and is the first proof.
- **No Xcode build.** `actool` was not run, so I did not see Xcode accept the
  iOS asset catalogue. The files keep their existing names, sizes and
  `Contents.json`, and carry no alpha, which are the conditions `actool` checks.
- **No macOS bundle.** The rounded master was checked as a PNG only.
- **`aapt2 compile` is not `aapt2 link`.** I compiled the resource tree but did
  not link an APK, so the manifest reference `@mipmap/ic_launcher` resolving to
  the new `mipmap-anydpi-v26` entry is not proven. The name is unchanged, so the
  cloud Android job remains the proof.
- **No phone drew an adaptive icon.** The safe-circle numbers come from a
  measurement in Python, not from a launcher that applies its own mask.
- **No Linux desktop read `linux/packaging/icons`.** CI decides where these
  files are installed. I only deliver the eight PNGs.
- **Web icons were not loaded by a browser.** The maskable rule was checked
  arithmetically, not by installing the PWA.
- **The test needs Pillow, so no runner can run it.** No workflow calls the
  generator or the test. I did not add a workflow step, because the workflows
  belong to the CI package.

## 5. Decisions the brief left open

1. **Adaptive foreground and maskable padding is solved by bisection, not by a
   closed form.** Reason: the source content radius is 0.4186 of the side, so a
   simple ratio would leave the content outside the circle once the LANCZOS
   halo is counted. The first ratio attempt gave 0.4012 for the 512 px maskable
   icon, which is outside the 0.40 limit. `fitted_box` bisects over the artwork
   box side, pastes it on a canvas of the target size and measures the rendered
   result, so the measurement and the delivered file use the same renderer.
   Sixteen bisection steps are enough for a side up to 1024 px.
2. **"Content" means a pixel whose colour differs from the background in any
   channel, at tolerance zero.** Reason: the brief says "the pixels that differ
   from the background colour". Using a tolerance would let faint halo pixels
   outside the circle pass the test, so the generator keeps the strict reading.
3. **The safe circle is checked against the full icon square, for both the
   adaptive foreground and the maskable icon.** Reason: the adaptive foreground
   PNG is the 108 dp canvas and the safe circle is 66 dp of that canvas
   (radius 33/108 = 0.3056). Measuring against the full canvas is the stricter
   reading and it also satisfies the viewport reading.
4. **Extra generated files: `values/ic_launcher_background.xml` and the
   `mipmap-*/ic_launcher_foreground.png` files.** Reason: the brief asks for "a
   background colour resource" and "one foreground PNG per density". The colour
   resource is a new file, not an edit of the existing `values/colors.xml`, so
   no other resource keeps a dependency on my change.
5. **`mipmap-anydpi-v26/ic_launcher.xml` replaces nothing.** The name
   `ic_launcher` is kept and the legacy PNGs stay in the density folders, so
   Android 7 and older still find a square icon and `AndroidManifest.xml` is
   untouched as the brief requires.
6. **iOS PNGs are written as `RGB`, not palette mode.** Reason: iOS rejects an
   alpha channel and Flutter shipped these as palette images. `RGB` removes any
   `tRNS` chunk risk and matches the 1024 px file that was already `RGB`. The
   file names and sizes are unchanged, so `Contents.json` still matches.
7. **The macOS rounded rectangle masks the artwork itself (an alpha mask on the
   pixels), instead of pasting a cornered square over the canvas.** Reason: a
   rounded mask on the artwork means the artwork's own edge is the anti-aliased
   edge, so no second colour can appear between the artwork and the canvas. The
   rounded rectangle is drawn at 4× and reduced, which is the anti-aliasing the
   brief asks for.
8. **Every PNG is written by Pillow with `optimize=True` and no metadata.**
   Reason: the source carries an Adobe XMP block. Keeping metadata would make
   the output depend on Pillow's writer version. Dropping it keeps `--check`
   stable across Pillow upgrades in the pixels but not in unrelated bytes. Note
   that `--check` compares bytes, not only pixels, so a Pillow zlib change can
   report "differs" for an identical image. A run of the generator fixes it.
9. **The `.ico` container is assembled by hand.** Reason: the brief warns that
   Pillow writes one format for all entries, and on this computer Pillow 12.0.0
   writes **all seven entries as PNG**. I confirmed that with a direct
   `Image.save(format='ICO', sizes=...)` test. The hand-built container writes
   BMP below 256 px and PNG at 256 px, so no legacy consumer sees a PNG at
   16–128 px. The BMP entries carry a full transparent AND mask, because the
   alpha channel of the 32-bit part carries the shape.
10. **The source image is not resampled before the Android legacy, Linux,
    Windows and web square variants.** Reason: the brief says "full square
    artwork". Only iOS, macOS, the adaptive foreground and the maskable icons
    get a treated image, and the iOS and macOS treatments are the platform's own
    shapes.
11. **No shadow on the macOS icon.** Reason: the brief says a shadow is not
    required. A shadow would also need a different blur radius per size to look
    right, which the "derive every size from that master" rule forbids.
12. **New file `tool/icons/contact_sheet.py`.** Reason: the contact sheet has to
    be reproducible, and a script under `tool/icons/**` is inside my package.
    It writes one PNG to the path given on the command line and is not called by
    the generator or by any test.
13. **Comments and docstrings in English, `logging`-free, `print` output.**
    Reason: `tool/ci/*.py` and `tool/icons` are read by the CI package and by
    the main session, and the existing Python tools use English docstrings.

## 6. Requests for files outside my package

1. **`pubspec.yaml` (main session).** `assets/app_icon.png` is declared as a
   Flutter asset at line 45. The file changes from 473×476 `RGBA` to 1024×1024
   `RGB`. I found no Dart code that reads this asset by size
   (`grep app_icon` over `lib/` returns nothing), so I ask for no change. If the
   main session knows a reader that depends on the old size, it must adjust that
   reader.
2. **`tool/ci/package_app.py` (CI package).** `build_deb` copies
   `assets/app_icon.png` into the `.deb` and picks the install path with
   `icon_install_path(*png_size(...))`. 1024 is not in `HICOLOR_SIZES`, so the
   icon now installs to `usr/share/pixmaps/qfli.…png` instead of
   `usr/share/icons/hicolor/<N>x<N>/apps/…`. The file was 473×476 before, which
   also fell into the `pixmaps` branch, so the path does not change. I ask the
   CI package to read `linux/packaging/icons/app_icon_<N>.png` (16…512) as the
   design says and to install those into `hicolor` instead. I changed nothing
   there.
3. **No workflow change is needed for the icons.** Do not call the generator
   from a workflow: runners have no Pillow. I ask the CI package not to add
   such a step.
4. **`.gitignore` (main session, only if wanted).** `__pycache__/` under
   `tool/icons/` appears after a test run. `*.pyc` is already ignored, so git
   never lists it. A `__pycache__/` line would keep the tree tidy. I deleted the
   directory and ask for no change.
