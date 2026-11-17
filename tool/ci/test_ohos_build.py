#!/usr/bin/env python3
"""Unit tests for the pure functions of ohos_build.py."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
PROFILE = HERE.parents[1] / "ohos/build-profile.json5"

_spec = importlib.util.spec_from_file_location("ohos_build", HERE / "ohos_build.py")
ohos_build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ohos_build)

REQUIRED = [
    "libs/arm64-v8a/libflutter.so",
    "libs/arm64-v8a/libapp.so",
    "libs/arm64-v8a/libqfli_ohos_runner.so",
    "resources/rawfile/qfli_toolchain/ohos-wasi.zip",
]


class ParseJson5Test(unittest.TestCase):
    def test_real_profile(self) -> None:
        document = ohos_build.parse_json5(PROFILE.read_text(encoding="utf-8"))
        self.assertEqual(document["app"]["products"][0]["name"], "default")
        self.assertEqual(document["modules"][0]["srcPath"], "./entry")
        self.assertIsInstance(document["app"]["signingConfigs"], list)

    def test_line_comment_marker_inside_string_is_kept(self) -> None:
        document = ohos_build.parse_json5('{"url": "https://example.com/a" // note "x"\n}')
        self.assertEqual(document, {"url": "https://example.com/a"})

    def test_block_comment_removed(self) -> None:
        document = ohos_build.parse_json5('{/* a "quoted" * note */"a": 1, "b": "/* kept */"}')
        self.assertEqual(document, {"a": 1, "b": "/* kept */"})

    def test_trailing_comma_removed(self) -> None:
        document = ohos_build.parse_json5('{"a": [1, 2, // last\n ], "b": {"c": ",}",},\n}')
        self.assertEqual(document, {"a": [1, 2], "b": {"c": ",}"}})

    def test_escaped_quote_inside_string(self) -> None:
        document = ohos_build.parse_json5('{"a": "say \\"hi\\" // not a comment", "b": "C:\\\\dir\\\\"}')
        self.assertEqual(document, {"a": 'say "hi" // not a comment', "b": "C:\\dir\\"})

    def test_unterminated_block_comment_fails(self) -> None:
        with self.assertRaises(ValueError):
            ohos_build.parse_json5('{"a": 1 /* open }')


class SanitizeProfileTest(unittest.TestCase):
    def test_real_profile_loses_signing_material(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory) / "build-profile.json5"
            shutil.copyfile(PROFILE, profile)
            ohos_build.sanitize_profile(profile)
            text = profile.read_text(encoding="utf-8")
        document = json.loads(text)
        self.assertEqual(document["app"]["signingConfigs"], [])
        self.assertTrue(document["app"]["products"])
        for product in document["app"]["products"]:
            self.assertNotIn("signingConfig", product)
        self.assertEqual(document["modules"][0]["name"], "entry")
        self.assertTrue(text.endswith("}\n"))
        # "profile" itself stays: buildModeSet holds a mode with that name.
        for marker in ("certpath", "storeFile", "storePassword", "keyPassword", "material", ".p12", ".p7b", ".cer"):
            self.assertNotIn(marker, text)


class ReadFlutterVersionTest(unittest.TestCase):
    def read(self, text: str) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "flutter-version.json"
            path.write_text(text, encoding="utf-8")
            return ohos_build.read_flutter_version(path)

    def test_plain_document(self) -> None:
        self.assertEqual(self.read('{"frameworkVersion": "3.41.9"}\n'), {"frameworkVersion": "3.41.9"})

    def test_notice_around_document_is_skipped(self) -> None:
        text = 'Welcome to Flutter!\n{"frameworkVersion": "3.41.9"}\nA new version is available.\n'
        self.assertEqual(self.read(text), {"frameworkVersion": "3.41.9"})

    def test_output_without_document_fails(self) -> None:
        with self.assertRaises(RuntimeError):
            self.read("Welcome to Flutter!\n")


class CheckHapNamesTest(unittest.TestCase):
    def test_required_entries_pass(self) -> None:
        validation = ohos_build.check_hap_names(REQUIRED + ["module.json", "libs/arm64-v8a/libc++_shared.so"])
        self.assertEqual(len(validation), len(REQUIRED) + 1)
        for name in REQUIRED:
            self.assertTrue(any(name in text for text in validation))

    def test_each_missing_entry_fails(self) -> None:
        for missing in REQUIRED:
            with self.subTest(missing=missing):
                names = [name for name in REQUIRED if name != missing]
                with self.assertRaises(RuntimeError) as caught:
                    ohos_build.check_hap_names(names)
                self.assertIn(missing, str(caught.exception))

    def test_extra_abi_directory_fails(self) -> None:
        for extra in ("libs/x86_64/libflutter.so", "libs/armeabi-v7a/"):
            with self.subTest(extra=extra):
                with self.assertRaises(RuntimeError) as caught:
                    ohos_build.check_hap_names(REQUIRED + [extra])
                self.assertIn(extra.split("/")[1], str(caught.exception))


if __name__ == "__main__":
    unittest.main()
