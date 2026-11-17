#!/usr/bin/env python3
"""Unit tests for the pure functions and the package command of ohos_build.py."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock
import zipfile

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


def write_zip(target, entries: dict[str, bytes]) -> None:
    with zipfile.ZipFile(target, "w") as archive:
        for name, data in entries.items():
            archive.writestr(name, data)


def hap_bytes(names: list[str]) -> bytes:
    stream = io.BytesIO()
    write_zip(stream, {name: name.encode("utf-8") for name in names})
    return stream.getvalue()


class PackageTest(unittest.TestCase):
    """Run package() on a small project inside a temporary GitHub workspace."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        workspace = Path(directory.name).resolve()
        self.project = workspace / "qfli_c"
        self.temporary = workspace / "temporary"
        self.output = self.project / "dist/app"
        self.hap = self.project / "build/ohos/hap/entry-default-unsigned.hap"
        self.app = self.project / "build/ohos/app/ohos-default-unsigned.app"
        for path in (self.temporary, self.hap.parent, self.app.parent):
            path.mkdir(parents=True)
        self.hap.write_bytes(hap_bytes(REQUIRED + ["module.json"]))
        write_zip(self.app, {"pack.info": b"{}", "entry-default.hap": hap_bytes(REQUIRED)})
        (self.project / "pubspec.yaml").write_text("name: qfli_c\nversion: 1.2.3+4\n", encoding="utf-8")
        (self.project / "LICENSE").write_bytes(b"License text.\n")
        (self.temporary / "ohos-toolchain.json").write_text('{"sdk": {"apiVersion": "26"}}\n', encoding="utf-8")
        (self.temporary / "ohos-flutter-version.json").write_text(
            '{"frameworkVersion": "3.41.9"}\n', encoding="utf-8")
        environment = {
            "GITHUB_ACTIONS": "true",
            "GITHUB_WORKSPACE": str(workspace),
            "RUNNER_TEMP": str(self.temporary),
            "GITHUB_SHA": "a" * 40,
            "GITHUB_REPOSITORY": "owner/repository",
            "GITHUB_RUN_ID": "42",
            "GITHUB_SERVER_URL": "https://github.com",
            "CORE_REVISION": "b" * 40,
            "FLUTTER_OHOS_REVISION": "c" * 40,
            "FLUTTER_OHOS_TAG": "3.41.9+ohos-1.0.2",
        }
        for patch in (mock.patch.object(ohos_build, "PROJECT", self.project),
                      mock.patch.dict(os.environ, environment)):
            patch.start()
            self.addCleanup(patch.stop)

    def package(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            ohos_build.package()

    def provenance(self) -> dict:
        return json.loads((self.output / "provenance.json").read_text(encoding="utf-8"))

    def test_writes_the_packages_and_records(self) -> None:
        self.package()
        names = sorted(path.name for path in self.output.iterdir())
        self.assertEqual(names, sorted([
            ohos_build.HAP_OUTPUT, ohos_build.APP_OUTPUT, "hap-contents.json",
            "SIGNING.txt", "provenance.json", "LICENSE", "SHA256SUMS"]))
        self.assertEqual((self.output / ohos_build.HAP_OUTPUT).read_bytes(), self.hap.read_bytes())
        self.assertEqual((self.output / ohos_build.APP_OUTPUT).read_bytes(), self.app.read_bytes())
        self.assertEqual((self.output / "LICENSE").read_bytes(), (self.project / "LICENSE").read_bytes())
        self.assertEqual((self.output / "SIGNING.txt").read_text(encoding="utf-8"), ohos_build.SIGNING_NOTE)
        # SHA256SUMS lists every file of the directory except itself.
        lines = (self.output / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
        self.assertEqual(sorted(lines), sorted(
            f"{ohos_build.sha256(self.output / name)}  {name}" for name in names if name != "SHA256SUMS"))
        contents = json.loads((self.output / "hap-contents.json").read_text(encoding="utf-8"))
        self.assertEqual(contents, {"hap": [{"name": name, "size": len(name)} for name in sorted(REQUIRED)]})
        record = self.provenance()
        self.assertEqual(record["applicationCommit"], "a" * 40)
        self.assertEqual(record["coreCommit"], "b" * 40)
        self.assertEqual(record["flutterCommit"], "c" * 40)
        self.assertEqual(record["flutterTag"], "3.41.9+ohos-1.0.2")
        self.assertEqual(record["runUrl"], "https://github.com/owner/repository/actions/runs/42")
        self.assertEqual(record["applicationVersion"], "1.2.3+4")
        self.assertEqual(record["signing"], "unsigned")
        self.assertIsNone(record["nativeInput"])
        self.assertEqual(record["toolchain"], {"sdk": {"apiVersion": "26"}})
        self.assertEqual(record["flutter"], {"frameworkVersion": "3.41.9"})
        self.assertIs(record["deviceRuntimeVerified"], False)
        self.assertEqual(record["packages"], [
            {"file": name, "sha256": ohos_build.sha256(self.output / name), "size": (self.output / name).stat().st_size}
            for name in (ohos_build.HAP_OUTPUT, ohos_build.APP_OUTPUT)])
        self.assertEqual(len(record["validation"]), 2 * (len(REQUIRED) + 1))

    def test_native_record_enters_the_provenance(self) -> None:
        native = {"name": "qfli-native-ohos-arm64-v8a", "runId": 7}
        (self.temporary / "native-input.json").write_text(json.dumps(native), encoding="utf-8")
        self.package()
        self.assertEqual(self.provenance()["nativeInput"], native)

    def test_run_outside_github_actions_fails(self) -> None:
        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaises(RuntimeError) as caught:
                self.package()
        self.assertIn("GitHub Actions", str(caught.exception))
        self.assertFalse(self.output.exists())

    def test_missing_build_output_fails(self) -> None:
        self.hap.unlink()
        with self.assertRaises(RuntimeError) as caught:
            self.package()
        self.assertIn(self.hap.name, str(caught.exception))
        self.assertFalse(self.output.exists())

    def test_filled_output_directory_fails(self) -> None:
        self.output.mkdir(parents=True)
        (self.output / "stale.hap").write_bytes(b"stale")
        with self.assertRaises(RuntimeError) as caught:
            self.package()
        self.assertIn("already holds files", str(caught.exception))
        self.assertEqual([path.name for path in self.output.iterdir()], ["stale.hap"])

    def test_app_without_nested_hap_fails(self) -> None:
        write_zip(self.app, {"pack.info": b"{}"})
        with self.assertRaises(RuntimeError) as caught:
            self.package()
        self.assertIn("no nested HAP", str(caught.exception))
        self.assertEqual(list(self.output.iterdir()), [])

    def test_nested_hap_without_a_required_entry_fails(self) -> None:
        write_zip(self.app, {"entry-default.hap": hap_bytes(REQUIRED[1:])})
        with self.assertRaises(RuntimeError) as caught:
            self.package()
        self.assertIn(REQUIRED[0], str(caught.exception))
        self.assertEqual(list(self.output.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
