"""Cloud-only fixture tests for bounded Flutter release artifacts."""

import hashlib
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from archive_flutter_build import archive_build, source_paths


class ArchiveFlutterBuildTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def write(self, name, content=b"release"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def test_each_platform_release_output(self):
        fixtures = {
            "android": "build/app/intermediates/flutter/release/arm64-v8a/app.so",
            "windows": "build/windows/x64/runner/Release/qfli_c.exe",
            "linux": "build/linux/x64/release/bundle/qfli_c",
            "macos": "build/macos/Build/Products/Release/QFLIForge.app/Contents/MacOS/QFLIForge",
            "ios": "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner",
            "ohos": ".dart_tool/flutter_build/abc/ohos-arm64/app.so",
        }
        for platform, name in fixtures.items():
            with self.subTest(platform=platform):
                self.write(name)
                with patch.dict("os.environ", {
                    "GITHUB_SHA": "a" * 40,
                    "CORE_REVISION": "b" * 40,
                    "FLUTTER_VERSION": "3.41.9",
                    "FLUTTER_REVISION": "c" * 40,
                    "NATIVE_RUN_ID": "42",
                }, clear=True):
                    record = archive_build(self.root, platform)
                output = self.root / "dist/flutter-build"
                archive = output / record["archive"]
                self.assertEqual(record["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())
                self.assertEqual(record["applicationCommit"], "a" * 40)
                self.assertEqual(record["nativeRunId"], "42")
                self.assertEqual(record["flutterVersion"], "3.41.9")
                self.assertEqual(record["retentionDays"], 7)
                self.assertEqual(json.loads((output / "provenance.json").read_text()), record)
                with tarfile.open(archive) as source:
                    self.assertIn(name, source.getnames())

    def test_missing_release_fails(self):
        with self.assertRaisesRegex(RuntimeError, "No Flutter release output"):
            source_paths(self.root, "linux")

    def test_ohos_excludes_installer_and_build_cache(self):
        self.write(".dart_tool/flutter_build/abc/flutter_assets/AssetManifest.bin")
        self.write("build/ohos/hap/entry-default-unsigned.hap")
        self.write("build/ohos/app/ohos-default-unsigned.app")
        self.write("ohos/entry/build/cache/compiler.tmp")
        record = archive_build(self.root, "ohos")
        self.assertEqual(record["sources"], [".dart_tool/flutter_build/abc/flutter_assets"])

    def test_abi_names_do_not_collide(self):
        self.write("build/app/intermediates/flutter/release/arm64-v8a/app.so")
        record = archive_build(self.root, "android", "arm64-v8a")
        self.assertEqual(record["archive"], "flutter-build-android-arm64-v8a.tar.gz")


if __name__ == "__main__":
    unittest.main()
