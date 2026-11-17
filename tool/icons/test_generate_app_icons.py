"""Check the generated icons against the source image and the platform rules.

The tests read the checked-in files. They need Pillow, so a runner without
Pillow cannot run them. Run them on a development computer:

    python -m unittest discover -s tool/icons -p "test_*.py"
"""

from __future__ import annotations

import io
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import xml.dom.minidom

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_app_icons as icons  # noqa: E402

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
ICO_HEADER = struct.Struct('<HHH')
ICO_ENTRY = struct.Struct('<BBBBHHII')


def open_output(name):
    """Return a loaded copy of a generated file, so no handle stays open."""
    with Image.open(icons.ROOT / name) as image:
        image.load()
        return image.copy()


def content_radius(image, colour):
    """Return the largest distance of a non-background pixel from the centre."""
    width, height = image.size
    pixels = image.load()
    centre = width / 2
    radius = 0.0
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == colour:
                continue
            distance = ((x + 0.5 - centre) ** 2 + (y + 0.5 - centre) ** 2) ** 0.5
            radius = max(radius, distance)
    return radius / width


def ico_entries(data):
    """Return (size, format, payload) for every entry of an icon file."""
    reserved, kind, count = ICO_HEADER.unpack_from(data, 0)
    if reserved != 0 or kind != 1:
        raise AssertionError('Icon header is not a resource icon')
    entries = []
    for index in range(count):
        width, height, colours, _, planes, bits, size, offset = ICO_ENTRY.unpack_from(
            data, ICO_HEADER.size + index * ICO_ENTRY.size)
        payload = data[offset:offset + size]
        shape = 'png' if payload.startswith(PNG_SIGNATURE) else 'bmp'
        entries.append((width or 256, shape, (height or 256, bits, payload)))
    return entries


class SourceTest(unittest.TestCase):
    def test_source_colour_is_the_border_colour(self):
        image = Image.open(icons.ROOT / icons.SOURCE).convert('RGB')
        self.assertEqual(icons.background_colour(image), (75, 69, 233))
        image.close()

    def test_source_border_is_flat(self):
        image = Image.open(icons.ROOT / icons.SOURCE).convert('RGB')
        width, height = image.size
        pixels = image.load()
        colours = {pixels[x, 0] for x in range(width)}
        colours |= {pixels[x, height - 1] for x in range(width)}
        colours |= {pixels[0, y] for y in range(height)}
        colours |= {pixels[width - 1, y] for y in range(height)}
        self.assertEqual(len(colours), 1)
        image.close()


class OutputSizeTest(unittest.TestCase):
    def test_every_output_has_its_declared_size(self):
        expected = {name: (size, size) for name, size in icons.WEB_SIZES.items()}
        expected |= {f'{icons.IOS_DIR}/{name}': (size, size)
                     for name, size in icons.IOS_SIZES.items()}
        expected |= {f'{icons.MACOS_DIR}/{name}': (size, size)
                     for name, size in icons.MACOS_SIZES.items()}
        expected |= {f'{icons.LINUX_PACKAGING}/app_icon_{size}.png': (size, size)
                     for size in icons.LINUX_SIZES}
        for density, size in icons.ANDROID_LEGACY_SIZES.items():
            expected[icons.android_mipmap(density, 'ic_launcher.png')] = (size, size)
        for density, size in icons.ANDROID_ADAPTIVE_FOREGROUND_SIZES.items():
            expected[icons.android_mipmap(density, 'ic_launcher_foreground.png')] = (
                size, size)
        for name, size in expected.items():
            with self.subTest(name=name):
                self.assertEqual(open_output(name).size, size)

    def test_every_catalogue_entry_names_a_file_of_its_pixel_size(self):
        for directory in (icons.IOS_DIR, icons.MACOS_DIR):
            catalogue = json.loads(
                (icons.ROOT / directory / 'Contents.json').read_text(encoding='utf-8'))
            for entry in catalogue['images']:
                points = float(entry['size'].split('x')[0])
                pixels = round(points * int(entry['scale'].rstrip('x')))
                with self.subTest(directory=directory, name=entry['filename'],
                                  size=entry['size'], scale=entry['scale']):
                    self.assertEqual(open_output(f"{directory}/{entry['filename']}").size,
                                     (pixels, pixels))

    def test_byte_copies_equal_the_source(self):
        source = (icons.ROOT / icons.SOURCE).read_bytes()
        for name in icons.COPY_TARGETS:
            with self.subTest(name=name):
                self.assertEqual((icons.ROOT / name).read_bytes(), source)


class IosAlphaTest(unittest.TestCase):
    def test_ios_icons_have_no_alpha(self):
        for name in icons.IOS_SIZES:
            path = icons.ROOT / icons.IOS_DIR / name
            with self.subTest(name=name), Image.open(path) as image:
                image.load()
                self.assertIn(image.mode, ('RGB', 'P'))
                self.assertNotIn('transparency', image.info)
                self.assertFalse(image.has_transparency_data)


class MacosShapeTest(unittest.TestCase):
    colour = (75, 69, 233)

    def test_every_macos_size_holds_the_rounded_square(self):
        left = (icons.MACOS_CANVAS - icons.MACOS_BODY) // 2
        right = left + icons.MACOS_BODY
        for name, size in icons.MACOS_SIZES.items():
            with self.subTest(name=name):
                alpha = open_output(f'{icons.MACOS_DIR}/{name}').convert('RGBA').split()[3]
                # The box holds each pixel that the square covers in part.
                low = left * size // icons.MACOS_CANVAS
                high = -(-right * size // icons.MACOS_CANVAS)
                self.assertEqual(alpha.getbbox(), (low, low, high, high))
                for corner in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
                    self.assertEqual(alpha.getpixel(corner), 0)
                self.assertEqual(alpha.getpixel((size // 2, size // 2)), 255)

    def test_macos_edge_is_anti_aliased(self):
        image = open_output(f'{icons.MACOS_DIR}/app_icon_1024.png').convert('RGBA')
        # The straight sides of a rounded rectangle are exact. The corner
        # arc carries the anti-aliased pixels.
        partial = sum(1 for value in image.split()[3].getdata() if 0 < value < 255)
        self.assertGreater(partial, 0, 'The macOS corner holds no partial pixel')

    def test_macos_edge_keeps_the_background_colour(self):
        # The edge of the shape lies on the flat border of the artwork. An
        # edge pixel of another colour shows as a ring around the icon. The
        # 16 px icon is left out: its artwork reaches the edge pixels.
        for name, size in icons.MACOS_SIZES.items():
            if size < 32:
                continue
            image = open_output(f'{icons.MACOS_DIR}/{name}').convert('RGBA')
            edge = [pixel for pixel in image.getdata() if 0 < pixel[3] < 255]
            with self.subTest(name=name):
                self.assertTrue(edge)
                worst = max(edge, key=lambda pixel: max(
                    abs(channel - expected)
                    for channel, expected in zip(pixel, self.colour)))
                for channel, expected in zip(worst, self.colour):
                    self.assertLessEqual(abs(channel - expected), 2, worst)


class AndroidTest(unittest.TestCase):
    colour = (75, 69, 233)

    def test_adaptive_foreground_keeps_content_in_the_safe_circle(self):
        limit = icons.ADAPTIVE_SAFE_DP / icons.ADAPTIVE_CANVAS_DP / 2
        for density in icons.ANDROID_ADAPTIVE_FOREGROUND_SIZES:
            name = icons.android_mipmap(density, 'ic_launcher_foreground.png')
            with self.subTest(density=density):
                image = open_output(name).convert('RGB')
                self.assertLessEqual(content_radius(image, self.colour), limit)

    def test_adaptive_icon_names_the_expected_resources(self):
        text = (icons.ROOT / 'android/app/src/main/res/mipmap-anydpi-v26/'
                'ic_launcher.xml').read_text(encoding='utf-8')
        xml.dom.minidom.parseString(text)
        self.assertIn('@color/ic_launcher_background', text)
        self.assertIn('@mipmap/ic_launcher_foreground', text)

    def test_background_resource_holds_the_border_colour(self):
        text = (icons.ROOT / 'android/app/src/main/res/values/'
                'ic_launcher_background.xml').read_text(encoding='utf-8')
        xml.dom.minidom.parseString(text)
        self.assertIn('#4B45E9', text)

    def test_legacy_icons_show_the_full_square(self):
        for density, size in icons.ANDROID_LEGACY_SIZES.items():
            name = icons.android_mipmap(density, 'ic_launcher.png')
            with self.subTest(density=density):
                image = open_output(name).convert('RGB')
                self.assertEqual(image.size, (size, size))
                # A full square keeps the background colour at every corner.
                for corner in ((0, 0), (size - 1, 0), (0, size - 1),
                               (size - 1, size - 1)):
                    self.assertEqual(image.getpixel(corner), self.colour)


class WebTest(unittest.TestCase):
    colour = (75, 69, 233)

    def test_maskable_icons_keep_content_in_the_safe_circle(self):
        for name in sorted(icons.MASKABLE_FILES):
            with self.subTest(name=name):
                image = open_output(name).convert('RGB')
                self.assertLessEqual(content_radius(image, self.colour),
                                     icons.MASKABLE_RADIUS_FRACTION)

    def test_maskable_canvas_is_the_background_colour(self):
        for name in sorted(icons.MASKABLE_FILES):
            with self.subTest(name=name):
                image = open_output(name).convert('RGB')
                self.assertEqual(image.getpixel((0, 0)), self.colour)

    def test_plain_web_icons_show_the_full_square(self):
        for name in ('web/favicon.png', 'web/icons/Icon-192.png', 'web/icons/Icon-512.png'):
            with self.subTest(name=name):
                image = open_output(name).convert('RGB')
                size = image.size[0]
                for corner in ((0, 0), (size - 1, 0), (0, size - 1),
                               (size - 1, size - 1)):
                    self.assertEqual(image.getpixel(corner), self.colour)


class WindowsIcoTest(unittest.TestCase):
    def setUp(self):
        self.data = (icons.ROOT / icons.ICO_PATH).read_bytes()
        self.entries = ico_entries(self.data)

    def test_entry_list_is_the_declared_one(self):
        self.assertEqual([entry[0] for entry in self.entries], icons.ICO_SIZES)

    def test_small_entries_are_32_bit_bmp(self):
        for size, shape, (height, bits, payload) in self.entries:
            if size >= icons.ICO_PNG_FROM:
                continue
            with self.subTest(size=size):
                self.assertEqual(shape, 'bmp')
                self.assertEqual(bits, 32)
                self.assertEqual(height, size)
                # The header holds two heights and no compression.
                header = struct.unpack_from('<IiiHHIIiiII', payload, 0)
                self.assertEqual(header[1], size)
                self.assertEqual(header[2], size * 2)
                self.assertEqual(header[4], 32)
                self.assertEqual(header[5], 0)

    def test_large_entry_is_png(self):
        large = [entry for entry in self.entries if entry[0] >= icons.ICO_PNG_FROM]
        self.assertTrue(large)
        for size, shape, (_, _, payload) in large:
            with self.subTest(size=size):
                self.assertEqual(shape, 'png')
                with Image.open(io.BytesIO(payload)) as image:
                    self.assertEqual(image.size, (size, size))
                    # Windows reads a PNG entry only in the 32-bit RGBA form.
                    self.assertEqual(image.mode, 'RGBA')

    def test_entries_do_not_overlap(self):
        total = ICO_HEADER.size + ICO_ENTRY.size * len(self.entries)
        offsets = []
        for index in range(len(self.entries)):
            entry = ICO_ENTRY.unpack_from(self.data, ICO_HEADER.size + index * ICO_ENTRY.size)
            offsets.append((entry[7], entry[6]))
        self.assertEqual([offset for offset, _ in offsets],
                         sorted(offset for offset, _ in offsets))
        previous = total
        for entry_offset, size in offsets:
            with self.subTest(offset=entry_offset):
                self.assertGreaterEqual(entry_offset, previous)
                self.assertLessEqual(entry_offset + size, len(self.data))
            previous = entry_offset + size


def repacked(data, **options):
    """Return another PNG encoding of the same pixels."""
    buffer = io.BytesIO()
    with Image.open(io.BytesIO(data)) as image:
        image.save(buffer, format='PNG', **options)
    return buffer.getvalue()


class SameContentTest(unittest.TestCase):
    name = 'web/icons/Icon-192.png'

    def setUp(self):
        self.data = (icons.ROOT / self.name).read_bytes()

    def test_another_encoding_of_the_same_pixels_matches(self):
        other = repacked(self.data, compress_level=1)
        self.assertNotEqual(other, self.data)
        self.assertTrue(icons.same_content(self.name, other, self.data))

    def test_one_changed_pixel_differs(self):
        with Image.open(io.BytesIO(self.data)) as opened:
            image = opened.convert('RGB')
        image.putpixel((0, 0), (0, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format='PNG')
        self.assertFalse(icons.same_content(self.name, buffer.getvalue(), self.data))

    def test_another_mode_differs(self):
        with Image.open(io.BytesIO(self.data)) as opened:
            image = opened.convert('RGBA')
        buffer = io.BytesIO()
        image.save(buffer, format='PNG')
        self.assertFalse(icons.same_content(self.name, buffer.getvalue(), self.data))

    def test_a_file_that_does_not_decode_differs(self):
        self.assertFalse(icons.same_content(self.name, self.data[:64], self.data))
        self.assertFalse(icons.same_content(self.name, b'', self.data))

    def test_a_byte_copy_must_match_byte_for_byte(self):
        name = icons.COPY_TARGETS[0]
        source = (icons.ROOT / icons.SOURCE).read_bytes()
        other = repacked(source, compress_level=1)
        self.assertEqual(icons.png_pixels(other), icons.png_pixels(source))
        self.assertFalse(icons.same_content(name, other, source))

    def test_text_matches_by_its_lines(self):
        name = 'android/app/src/main/res/values/ic_launcher_background.xml'
        text = (icons.ROOT / name).read_bytes().replace(b'\r\n', b'\n')
        windows = text.replace(b'\n', b'\r\n')
        self.assertTrue(icons.same_content(name, text, text))
        # A Windows checkout with core.autocrlf turns LF into CRLF.
        self.assertTrue(icons.same_content(name, windows, text))
        self.assertFalse(icons.same_content(name, text + b'\n', text))
        self.assertFalse(icons.same_content(name, text.replace(b'4B45E9', b'4B45E8'), text))

    def test_icon_file_matches_by_the_pixels_of_its_png_entry(self):
        data = (icons.ROOT / icons.ICO_PATH).read_bytes()
        # The PNG entry is the last one, so only its length field moves.
        index = len(icons.ICO_SIZES) - 1
        field = ICO_HEADER.size + index * ICO_ENTRY.size
        entry = ICO_ENTRY.unpack_from(data, field)
        payload = data[entry[7]:entry[7] + entry[6]]
        self.assertEqual(entry[7] + entry[6], len(data))
        other_payload = repacked(payload, compress_level=1)
        self.assertNotEqual(other_payload, payload)
        other = bytearray(data[:entry[7]] + other_payload)
        ICO_ENTRY.pack_into(other, field, *entry[:6], len(other_payload), entry[7])
        self.assertTrue(icons.same_content(icons.ICO_PATH, bytes(other), data))
        # One changed blue value in the first BMP entry.
        first = ICO_ENTRY.unpack_from(data, ICO_HEADER.size)
        changed = bytearray(data)
        changed[first[7] + 40] ^= 0xFF
        self.assertFalse(icons.same_content(icons.ICO_PATH, bytes(changed), data))
        self.assertFalse(icons.same_content(icons.ICO_PATH, data[:20], data))


class CheckModeTest(unittest.TestCase):
    def test_check_mode_passes_on_the_generated_tree(self):
        result = subprocess.run(
            [sys.executable, str(Path(icons.__file__)), '--check'],
            capture_output=True, text=True, encoding='utf-8', cwd=icons.ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_check_mode_fails_after_one_changed_pixel(self):
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / 'repo'
            # Copy the files the generator reads and writes.
            files = set(icons.render(icons.read_source()))
            files.add(str(icons.SOURCE))
            for name in files:
                target = copy / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(icons.ROOT / name, target)
            (copy / 'tool/icons').mkdir(parents=True, exist_ok=True)
            shutil.copyfile(Path(icons.__file__), copy / 'tool/icons/generate_app_icons.py')
            changed = copy / 'web/icons/Icon-192.png'
            with Image.open(changed) as opened:
                image = opened.convert('RGB')
            image.putpixel((0, 0), (0, 0, 0))
            image.save(changed, format='PNG')
            result = subprocess.run(
                [sys.executable, str(copy / 'tool/icons/generate_app_icons.py'), '--check'],
                capture_output=True, text=True, encoding='utf-8', cwd=copy)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn('web/icons/Icon-192.png', result.stdout)


if __name__ == '__main__':
    unittest.main()
