"""Check that CI preparation preserves unsuitable or locally edited checkouts."""

from pathlib import Path
import subprocess
import tempfile
import unittest

from prepare_core import prepare


class PrepareCoreTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.core = root / "core"
        self.core.mkdir()
        self.flutter = root / "flutter"
        self.platform = (
            self.flutter / "packages/flutter/lib/src/foundation/platform.dart"
        )
        self.platform.parent.mkdir(parents=True)
        self.platform.write_text("enum TargetPlatform { android, windows }\n")
        self.source = self.core / "value.txt"
        self.source.write_text("original\n", newline="")
        self.git("init", "-q")
        self.git("config", "core.autocrlf", "false")
        self.git("add", "value.txt")
        self.git(
            "-c", "user.name=CI test", "-c", "user.email=ci@example.invalid",
            "commit", "-qm", "fixture",
        )
        self.revision = self.git("rev-parse", "HEAD").strip()
        self.patch = root / "change.patch"
        self.patch.write_text(
            "diff --git a/value.txt b/value.txt\n"
            "--- a/value.txt\n+++ b/value.txt\n"
            "@@ -1 +1 @@\n-original\n+patched\n",
            encoding="utf-8", newline="",
        )

    def git(self, *arguments):
        return subprocess.check_output(
            ["git", "-C", str(self.core), *arguments], text=True,
            stderr=subprocess.STDOUT,
        )

    def prepare(self, **kwargs):
        prepare(
            self.core, self.flutter, revision=self.revision,
            patch=self.patch, **kwargs,
        )

    def test_check_then_apply(self):
        self.prepare(check_only=True)
        self.assertEqual(self.source.read_text(), "original\n")
        self.prepare()
        self.assertEqual(self.source.read_text(), "patched\n")

    def test_rejects_local_edits(self):
        self.source.write_text("user edit\n")
        with self.assertRaisesRegex(RuntimeError, "must be clean"):
            self.prepare()
        self.assertEqual(self.source.read_text(), "user edit\n")

    def test_windows_crlf_checkout(self):
        self.git("config", "core.autocrlf", "true")
        self.source.unlink()
        self.git("checkout", "--", "value.txt")
        self.prepare()
        self.assertEqual(self.source.read_text(), "patched\n")

    def test_rejects_wrong_revision(self):
        with self.assertRaisesRegex(RuntimeError, "Core revision must be"):
            prepare(
                self.core, self.flutter, revision="0" * 40, patch=self.patch,
            )
        self.assertEqual(self.source.read_text(), "original\n")

    def test_rejects_ohos_sdk(self):
        self.platform.write_text("enum TargetPlatform {\n  android,\n  ohos,\n}\n")
        with self.assertRaisesRegex(RuntimeError, "OHOS SDK"):
            self.prepare()
        self.assertEqual(self.source.read_text(), "original\n")


if __name__ == "__main__":
    unittest.main()
