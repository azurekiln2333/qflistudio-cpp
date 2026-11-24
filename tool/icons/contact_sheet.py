"""Render a contact sheet of every generated icon for a human review.

Not part of the generator: this script only reads the generated files and
writes one PNG outside the repository. Usage:

    python tool/icons/contact_sheet.py <output.png>
"""

from __future__ import annotations

import io
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_app_icons as icons  # noqa: E402

CELL = 168
PAD = 12
LABEL = 26
COLUMNS = 6
BACKGROUND = (128, 128, 128)
CHECK_LIGHT = (150, 150, 150)
CHECK_DARK = (110, 110, 110)
CHECK = 12
INK = (20, 20, 20)
CIRCLE = (220, 60, 60)


def checker(size):
    """Return a grey checkerboard tile, the usual transparency preview."""
    image = Image.new('RGB', (size, size), CHECK_LIGHT)
    draw = ImageDraw.Draw(image)
    for y in range(0, size, CHECK):
        for x in range(0, size, CHECK):
            if (x // CHECK + y // CHECK) % 2:
                draw.rectangle([x, y, x + CHECK - 1, y + CHECK - 1], fill=CHECK_DARK)
    return image


def circle_preview(tile, icon):
    """Return the icon masked by a centre circle, as a launcher would show it."""
    size = tile.size[0]
    masked = icon.copy()
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    masked.putalpha(mask)
    tile.paste(masked, (0, 0), masked)
    return tile


def rows():
    with Image.open(icons.ROOT / icons.SOURCE) as opened:
        colour = icons.background_colour(opened.convert('RGB'))
    entries = []
    for name in icons.COPY_TARGETS:
        entries.append((name, icons.ROOT / name, False))
    for density in icons.ANDROID_LEGACY_SIZES:
        entries.append((f'android legacy {density}',
                        icons.ROOT / icons.android_mipmap(density, 'ic_launcher.png'), False))
    for density in icons.ANDROID_ADAPTIVE_FOREGROUND_SIZES:
        entries.append((f'adaptive fg {density}',
                        icons.ROOT / icons.android_mipmap(density,
                                                          'ic_launcher_foreground.png'),
                        True))
    entries.append(('adaptive composite mdpi', None, True))
    for name in icons.IOS_SIZES:
        entries.append((f'ios {name}', icons.ROOT / icons.IOS_DIR / name, False))
    for name in icons.MACOS_SIZES:
        entries.append((f'macos {name}', icons.ROOT / icons.MACOS_DIR / name, False))
    entries.append(('windows ico', icons.ROOT / icons.ICO_PATH, False))
    for size in icons.LINUX_SIZES:
        entries.append((f'linux {size}',
                        icons.ROOT / f'{icons.LINUX_PACKAGING}/app_icon_{size}.png', False))
    for name in icons.WEB_SIZES:
        entries.append((name, icons.ROOT / name, name in icons.MASKABLE_FILES))
    return entries, colour


def ico_frame(path):
    """Return the largest PNG entry of the icon file as a PIL image."""
    data = path.read_bytes()
    count = struct.unpack_from('<H', data, 4)[0]
    best = None
    for index in range(count):
        _, _, _, _, _, _, size, offset = struct.unpack_from('<BBBBHHII', data, 6 + 16 * index)
        payload = data[offset:offset + size]
        if not payload.startswith(b'\x89PNG'):
            continue
        with Image.open(io.BytesIO(payload)) as opened:
            image = opened.convert('RGBA')
        if best is None or image.size[0] > best.size[0]:
            best = image
    return best


def main(argv):
    if len(argv) != 2:
        print('usage: contact_sheet.py <output.png>')
        return 2
    entries, colour = rows()
    cells = []
    for label, path, maskable in entries:
        if path is None:
            # The adaptive icon as a launcher draws it: foreground over the
            # background colour, then the circle mask. The 72 dp viewport is
            # smaller than the 108 dp canvas, so the preview shrinks a little.
            size = icons.ANDROID_ADAPTIVE_FOREGROUND_SIZES['mdpi']
            with Image.open(icons.ROOT / icons.android_mipmap(
                    'mdpi', 'ic_launcher_foreground.png')) as opened:
                foreground = opened.convert('RGB')
            composite = Image.new('RGB', (size, size), colour)
            composite.paste(foreground, (0, 0))
            cells.append((label, composite.convert('RGBA'), True,
                          icons.ADAPTIVE_VIEWPORT_DP / icons.ADAPTIVE_CANVAS_DP))
            continue
        if path.suffix == '.ico':
            icon = ico_frame(path).convert('RGBA')
        else:
            with Image.open(path) as opened:
                icon = opened.convert('RGBA')
        cells.append((label, icon, maskable, 1.0))

    total = len(cells)
    rows_count = (total + COLUMNS - 1) // COLUMNS
    width = COLUMNS * (CELL + PAD) + PAD
    height = rows_count * (CELL + LABEL + PAD) + PAD
    sheet = Image.new('RGB', (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('arial.ttf', 12)
    except OSError:
        font = ImageFont.load_default()

    for index, (label, icon, maskable, scale) in enumerate(cells):
        column = index % COLUMNS
        row = index // COLUMNS
        left = PAD + column * (CELL + PAD)
        top = PAD + row * (CELL + LABEL + PAD)
        tile = checker(CELL)
        inner = max(1, round(CELL * scale) - 16)
        shown = icon.resize((inner, inner), Image.LANCZOS)
        offset = ((CELL - inner) // 2, (CELL - inner) // 2)
        if maskable:
            circle = Image.new('L', (inner, inner), 0)
            ImageDraw.Draw(circle).ellipse([0, 0, inner - 1, inner - 1], fill=255)
            shown.putalpha(circle)
        tile.paste(shown, offset, shown)
        if maskable:
            draw.ellipse([left, top, left + CELL - 1, top + CELL - 1], outline=CIRCLE)
        sheet.paste(tile, (left, top))
        draw.rectangle([left, top, left + CELL, top + CELL], outline=(80, 80, 80))
        draw.text((left, top + CELL + 4), label[:30], fill=INK, font=font)
    sheet.save(argv[1])
    print(f'sheet: {width}x{height}, {total} variants')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
