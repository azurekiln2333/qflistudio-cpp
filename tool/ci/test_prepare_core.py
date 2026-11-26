"""Check that CI preparation preserves unsuitable or locally edited checkouts."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from prepare_core import CORE_PATH, CORE_REVISION, PATCH, prepare


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
        for relative in ("lib", "vendor/re_editor/lib"):
            source_root = self.core / relative
            source_root.mkdir(parents=True)
            (source_root / "portable.dart").write_text(
                "const portable = true;\n", encoding="utf-8", newline="",
            )
        self.git("init", "-q")
        self.git("config", "core.autocrlf", "false")
        self.git("add", ".")
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

    def commit_fixture(self):
        self.git("add", ".")
        self.git(
            "-c", "user.name=CI test", "-c", "user.email=ci@example.invalid",
            "commit", "-qm", "fixture source change",
        )
        self.revision = self.git("rev-parse", "HEAD").strip()

    def test_rejects_remaining_fork_api_in_each_source_tree(self):
        initial_revision = self.revision
        cases = (
            ("lib/new.dart", "final target = TargetPlatform.ohos;\n"),
            ("vendor/re_editor/lib/new.dart", "final view = OhosView();\n"),
        )
        for relative, source in cases:
            with self.subTest(relative=relative):
                self.git("reset", "--hard", initial_revision)
                path = self.core / relative
                path.write_text(source, encoding="utf-8", newline="")
                self.commit_fixture()
                with self.assertRaisesRegex(RuntimeError, "OHOS-only API remains"):
                    self.prepare()

    def test_rejects_missing_source_root(self):
        source = self.core / "vendor/re_editor/lib/portable.dart"
        source.unlink()
        source.parent.rmdir()
        self.commit_fixture()
        with self.assertRaisesRegex(RuntimeError, "Core source directory is missing"):
            self.prepare()

    def test_workflow_core_pins_match_helper(self):
        workflow = PATCH.parents[2] / ".github/workflows/app-installers.yml"
        source = workflow.read_text(encoding="utf-8")
        pins = re.findall(
            r"repository: azurekiln2333/qflistudio-core\s+ref: ([0-9a-f]{40})",
            source,
        )
        self.assertEqual(pins, [CORE_REVISION] * 7)
        self.assertIn(f"CORE_REVISION: {CORE_REVISION}", source)
        self.assertEqual(CORE_PATH, Path("../qflistudio-core"))
        self.assertEqual(source.count("path: qflistudio-core"), 7)
        for filename in ("pubspec.yaml", "pubspec.lock"):
            text = (PATCH.parents[2] / filename).read_text(encoding="utf-8")
            self.assertIn("../qflistudio-core", text)
            self.assertNotIn("../qfli_studio_core", text)
            self.assertIn("qfli_studio_core:", text)

    def test_compatibility_patch_only_changes_the_huawei_view(self):
        source = PATCH.read_text(encoding="utf-8")
        files = [line for line in source.splitlines() if line.startswith("diff --git ")]
        path = "lib/pages/auth/huawei_quick_login_view.dart"
        self.assertEqual(files, [f"diff --git a/{path} b/{path}"])

    def test_real_compatibility_patch_applies_without_other_changes(self):
        target = self.core / "lib/pages/auth/huawei_quick_login_view.dart"
        target.parent.mkdir(parents=True)
        stub = (
            "import 'package:flutter/material.dart';\n\n"
            "/// The stock Flutter copy does not embed a HarmonyOS platform view.\n"
            "class HuaweiQuickLoginView extends StatelessWidget {\n"
            "  const HuaweiQuickLoginView({\n"
            "    super.key,\n"
            "    required this.agreementAccepted,\n"
            "    required this.onAuthorizationCode,\n"
            "    required this.onError,\n"
            "  });\n\n"
            "  final bool agreementAccepted;\n"
            "  final ValueChanged<String> onAuthorizationCode;\n"
            "  final ValueChanged<String> onError;\n\n"
            "  @override\n"
            "  Widget build(BuildContext context) => const SizedBox.shrink();\n"
            "}\n"
        )
        # Match the checkout's line endings; Windows checks the patch out as CRLF.
        newline = "\r\n" if b"\r\n" in PATCH.read_bytes() else "\n"
        target.write_text(stub.replace("\n", newline), encoding="utf-8", newline="")
        self.git("apply", "--reverse", str(PATCH))
        self.assertIn("return OhosView(", target.read_text(encoding="utf-8"))
        self.commit_fixture()
        self.patch = PATCH
        self.prepare()
        self.assertEqual(target.read_text(encoding="utf-8"), stub)
        self.assertEqual(self.source.read_text(), "original\n")
        self.assertEqual(
            self.git("diff", "--name-only").strip(),
            "lib/pages/auth/huawei_quick_login_view.dart",
        )


if __name__ == "__main__":
    unittest.main()
