"""Derive every platform icon of the application from the OHOS icon.

The single source is ``ohos/entry/src/main/resources/base/media/icon.png``.
One run writes every generated file. ``--check`` compares the pixels on disk
with a fresh rendering and names each file that differs.

Runners do not hold Pillow, so nothing calls this script from a workflow.
Run it on a development computer after the source image changes:

    python tool/icons/generate_app_icons.py
    python tool/icons/generate_app_icons.py --check
"""

from __future__ import annotations

import argparse
import io
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('ohos/entry/src/main/resources/base/media/icon.png')
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'

# Android legacy launcher icons, one file per density.
ANDROID_LEGACY_SIZES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

# Android adaptive icons use a 108 dp canvas with a 72 dp visible viewport and
# a 66 dp safe circle that the launcher never masks.
ANDROID_ADAPTIVE_FOREGROUND_SIZES = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}
ADAPTIVE_CANVAS_DP = 108
ADAPTIVE_VIEWPORT_DP = 72
ADAPTIVE_SAFE_DP = 66
ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
ADAPTIVE_BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{colour}</color>
</resources>
"""

# Web maskable icons keep the content inside a centred circle of 40% radius.
MASKABLE_RADIUS_FRACTION = 0.40
WEB_SIZES = {
    'web/favicon.png': 16,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
}
MASKABLE_FILES = {
    'web/icons/Icon-maskable-192.png',
    'web/icons/Icon-maskable-512.png',
}

# macOS draws its own square icons smaller than the canvas. Bake that shape in.
MACOS_CANVAS = 1024
MACOS_BODY = 824
MACOS_RADIUS = 185
MACOS_SUPERSAMPLE = 4
MACOS_SIZES = {
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
}

# Windows reads the icon with rc.exe, Inno Setup 6 and NSIS 3. Entries below
# 256 px are uncompressed 32-bit BMP, the 256 px entry is PNG.
ICO_PATH = 'windows/runner/resources/app_icon.ico'
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ICO_PNG_FROM = 256

# Linux packaging takes PNG files named after their pixel size.
LINUX_PACKAGING = 'linux/packaging/icons'
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]

# Byte copies of the source. Local history already holds this blob at these
# paths, so a byte-identical file merges cleanly.
COPY_TARGETS = [
    'assets/app_icon.png',
    'ohos/AppScope/resources/base/media/app_icon.png',
]

IOS_DIR = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
MACOS_DIR = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'

# The iOS asset catalogue names its files after the point size and the scale.
IOS_SIZES = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}


def android_mipmap(density, name):
    return f'android/app/src/main/res/mipmap-{density}/{name}'


def background_colour(image):
    """Return the colour of the image border as an (r, g, b) tuple."""
    width, height = image.size
    pixels = image.load()
    border = [pixels[x, 0] for x in range(width)]
    border += [pixels[x, height - 1] for x in range(width)]
    border += [pixels[0, y] for y in range(height)]
    border += [pixels[width - 1, y] for y in range(height)]
    counts = {}
    for colour in border:
        counts[colour] = counts.get(colour, 0) + 1
    return max(counts, key=counts.get)


def content_radius(image, colour):
    """Return the largest distance of a content pixel from the centre.

    A pixel counts as content when one channel differs from the background.
    """
    width, height = image.size
    pixels = image.load()
    centre_x = width / 2
    centre_y = height / 2
    radius = 0.0
    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            if pixel[0:3] == colour:
                continue
            distance = ((x + 0.5 - centre_x) ** 2 + (y + 0.5 - centre_y) ** 2) ** 0.5
            if distance > radius:
                radius = distance
    return radius


def resize_square(image, size):
    """Downscale square artwork. LANCZOS keeps the small sizes readable."""
    if image.size == (size, size):
        return image.copy()
    return image.resize((size, size), Image.LANCZOS)


def macos_layers(artwork, colour):
    """Return the colour layer and the shape mask of the macOS icon.

    macOS shows a rounded square that is smaller than the canvas. The colour
    layer holds the artwork on a canvas of its own background colour. So no
    colour edge lies under the edge of the shape, and a reduced icon shows
    neither a dark ring nor a bright ring. The mask holds the rounded square
    at a larger scale than the canvas.
    """
    scale = MACOS_SUPERSAMPLE
    left = (MACOS_CANVAS - MACOS_BODY) // 2
    colours = Image.new('RGB', (MACOS_CANVAS, MACOS_CANVAS), colour)
    colours.paste(resize_square(artwork, MACOS_BODY), (left, left))
    mask = Image.new('L', (MACOS_CANVAS * scale, MACOS_CANVAS * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [left * scale, left * scale,
         (left + MACOS_BODY) * scale - 1, (left + MACOS_BODY) * scale - 1],
        radius=MACOS_RADIUS * scale,
        fill=255,
    )
    return colours, mask


def macos_icon(colours, mask, size):
    """Return one macOS icon size. Each layer is reduced on its own.

    The mask side is a multiple of every icon side. A box filter therefore
    gives each pixel the exact share that the rounded square covers.
    """
    icon = resize_square(colours, size).convert('RGBA')
    icon.putalpha(mask.resize((size, size), Image.BOX))
    return icon


def fitted_box(artwork, colour, size, limit):
    """Return the artwork box side in pixels, content inside ``limit``.

    ``size`` is the canvas side. ``limit`` is the allowed content radius as a
    share of that canvas. A resize halo spreads the content slightly wider
    than a pure scale predicts, and its width depends on the target size. So a
    bisection pastes the box onto the canvas and measures the result.
    """
    allowed = limit * size

    def fits(box):
        content = resize_square(artwork, box)
        canvas = Image.new('RGB', (size, size), colour)
        offset = (size - box) // 2
        canvas.paste(content, (offset, offset))
        return content_radius(canvas, colour) <= allowed

    if fits(size):
        return size
    low = 1
    high = size
    while low < high:
        # The upper middle, so a step always moves one of the two bounds.
        middle = (low + high + 1) // 2
        if fits(middle):
            low = middle
        else:
            high = middle - 1
    return low


def centred_artwork(artwork, colour, size, limit, cap=1.0):
    """Return a background canvas with the artwork centred inside ``limit``.

    ``cap`` is the largest box side as a share of the canvas.
    """
    box = min(fitted_box(artwork, colour, size, limit), round(size * cap))
    content = resize_square(artwork, box)
    canvas = Image.new('RGB', (size, size), colour)
    offset = (size - box) // 2
    canvas.paste(content, (offset, offset))
    return canvas


def maskable_square(artwork, colour, size):
    """Return artwork on a background canvas, content inside the safe circle.

    The canvas is the background colour, so smaller content leaves no seam.
    """
    return centred_artwork(artwork, colour, size, MASKABLE_RADIUS_FRACTION)


def adaptive_foreground(artwork, colour, size):
    """Return the adaptive foreground: background canvas, centred artwork.

    The source square covers the 72 dp viewport. The content must stay inside
    the 66 dp safe circle. The source content reaches 0.4186 of its side, so
    the scale that fits the safe circle also fits inside the viewport.
    """
    safe = ADAPTIVE_SAFE_DP / ADAPTIVE_CANVAS_DP / 2
    viewport = ADAPTIVE_VIEWPORT_DP / ADAPTIVE_CANVAS_DP
    return centred_artwork(artwork, colour, size, safe, cap=viewport)


def png_bytes(image):
    """Return PNG file content. No metadata enters the file."""
    buffer = io.BytesIO()
    image.save(buffer, format='PNG', optimize=True)
    return buffer.getvalue()


def ico_bmp_entry(image):
    """Return a 32-bit BMP entry of an icon file.

    The header holds two heights, the XOR part with the pixels and the AND
    mask. The mask is all zero because the alpha channel carries the shape.
    """
    size = image.size[0]
    pixels = image.convert('RGBA').tobytes()
    rows = []
    stride = size * 4
    for y in range(size - 1, -1, -1):
        row = pixels[y * stride:(y + 1) * stride]
        # BMP stores blue, green, red, alpha.
        rows.append(bytes(
            component
            for x in range(size)
            for component in (row[x * 4 + 2], row[x * 4 + 1], row[x * 4], row[x * 4 + 3])
        ))
    xor = b''.join(rows)
    mask_stride = ((size + 31) // 32) * 4
    and_mask = b'\x00' * (mask_stride * size)
    header = struct.pack('<IiiHHIIiiII',
                         40, size, size * 2, 1, 32, 0, len(xor) + len(and_mask), 0, 0, 0, 0)
    return header + xor + and_mask


def ico_bytes(artwork):
    """Return an icon file with BMP entries below 256 px and a PNG at 256 px."""
    entries = []
    for size in ICO_SIZES:
        image = resize_square(artwork, size)
        if size >= ICO_PNG_FROM:
            # Windows reads a PNG entry only in the 32-bit RGBA form.
            data = png_bytes(image.convert('RGBA'))
        else:
            data = ico_bmp_entry(image)
        entries.append((size, data))
    offset = 6 + 16 * len(entries)
    directory = b''
    payload = b''
    for size, data in entries:
        directory += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32,
                                 len(data), offset + len(payload))
        payload += data
    return struct.pack('<HHH', 0, 1, len(entries)) + directory + payload


def render(source_bytes):
    """Return an ordered mapping of repository path to file content."""
    artwork = Image.open(io.BytesIO(source_bytes))
    artwork.load()
    artwork = artwork.convert('RGB')
    colour = background_colour(artwork)
    hex_colour = '#{:02X}{:02X}{:02X}'.format(*colour)
    outputs = {}

    for target in COPY_TARGETS:
        outputs[target] = source_bytes

    for density, size in ANDROID_LEGACY_SIZES.items():
        outputs[android_mipmap(density, 'ic_launcher.png')] = png_bytes(
            resize_square(artwork, size))
    for density, size in ANDROID_ADAPTIVE_FOREGROUND_SIZES.items():
        outputs[android_mipmap(density, 'ic_launcher_foreground.png')] = png_bytes(
            adaptive_foreground(artwork, colour, size))
    outputs['android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'] = (
        ADAPTIVE_XML.encode('utf-8'))
    outputs['android/app/src/main/res/values/ic_launcher_background.xml'] = (
        ADAPTIVE_BACKGROUND_XML.format(colour=hex_colour).encode('utf-8'))

    for name, size in IOS_SIZES.items():
        # iOS rejects an alpha channel in an application icon.
        outputs[f'{IOS_DIR}/{name}'] = png_bytes(resize_square(artwork, size))

    colours, mask = macos_layers(artwork, colour)
    for name, size in MACOS_SIZES.items():
        outputs[f'{MACOS_DIR}/{name}'] = png_bytes(macos_icon(colours, mask, size))

    outputs[ICO_PATH] = ico_bytes(artwork)

    for size in LINUX_SIZES:
        outputs[f'{LINUX_PACKAGING}/app_icon_{size}.png'] = png_bytes(
            resize_square(artwork, size))

    for path, size in WEB_SIZES.items():
        if path in MASKABLE_FILES:
            outputs[path] = png_bytes(maskable_square(artwork, colour, size))
        else:
            outputs[path] = png_bytes(resize_square(artwork, size))
    return outputs


def read_source():
    """Return the source image bytes from the repository."""
    return (ROOT / SOURCE).read_bytes()


def write_all(outputs):
    """Write every generated file."""
    for path, data in outputs.items():
        target = ROOT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


def png_pixels(data):
    """Return the mode, the size and the pixels that a PNG decodes to."""
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        return image.mode, image.size, image.tobytes()


def ico_entries(data):
    """Return one comparable value for each entry of an icon file.

    A PNG entry gives its decoded pixels, a BMP entry gives its bytes.
    """
    count = struct.unpack_from('<H', data, 4)[0]
    entries = []
    for index in range(count):
        *shape, size, offset = struct.unpack_from('<BBBBHHII', data, 6 + 16 * index)
        payload = data[offset:offset + size]
        if payload.startswith(PNG_SIGNATURE):
            payload = png_pixels(payload)
        entries.append((shape, payload))
    return entries


def same_content(path, on_disk, rendered):
    """Tell whether a file on disk holds what a rendering holds.

    An image matches when its decoded pixels match. The PNG bytes depend on
    the zlib build, so two computers can pack the same pixels differently.
    The byte copies must match byte for byte. An XML file matches when its
    lines match, because a Windows checkout can turn LF into CRLF.
    """
    if on_disk == rendered:
        return True
    if path in COPY_TARGETS:
        return False
    if path.endswith('.xml'):
        return on_disk.replace(b'\r\n', b'\n') == rendered.replace(b'\r\n', b'\n')
    try:
        if path == ICO_PATH:
            return ico_entries(on_disk) == ico_entries(rendered)
        if path.endswith('.png'):
            return png_pixels(on_disk) == png_pixels(rendered)
    except (OSError, SyntaxError, ValueError, struct.error):
        # A file that does not decode differs.
        return False
    return False


def differing(outputs):
    """Return the paths whose content on disk differs from a rendering."""
    changed = []
    for path, data in outputs.items():
        target = ROOT / path
        if not target.is_file() or not same_content(path, target.read_bytes(), data):
            changed.append(path)
    return changed


def main(argv=None):
    parser = argparse.ArgumentParser(description='Generate the platform icons.')
    parser.add_argument('--check', action='store_true',
                        help='compare the files on disk and change nothing')
    arguments = parser.parse_args(argv)
    outputs = render(read_source())
    if arguments.check:
        changed = differing(outputs)
        for path in changed:
            print(f'differs: {path}')
        if changed:
            print(f'{len(changed)} of {len(outputs)} files differ')
            return 1
        print(f'{len(outputs)} files match')
        return 0
    write_all(outputs)
    print(f'{len(outputs)} files written')
    return 0


if __name__ == '__main__':
    sys.exit(main())
