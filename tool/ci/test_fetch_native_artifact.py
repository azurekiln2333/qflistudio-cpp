#!/usr/bin/env python3
"""Unit tests for the pure functions of fetch_native_artifact.py."""

from __future__ import annotations

import hashlib
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
import zipfile

HERE = Path(__file__).resolve().parent

_spec = importlib.util.spec_from_file_location("fetch_native_artifact", HERE / "fetch_native_artifact.py")
fetch_native_artifact = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fetch_native_artifact)

NAME = "qfli-native-ios"
ARCHIVE = f"{NAME}.tar.gz"


def artifact(identifier: int, created: str, run_id: int = 1, branch: str = "main",
             name: str = NAME, expired: bool = False) -> dict:
    return {
        "id": identifier,
        "name": name,
        "expired": expired,
        "created_at": created,
        "workflow_run": {"id": run_id, "head_branch": branch, "head_sha": "0" * 40},
    }


def tarball(files: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as package:
        for name, data in files.items():
            entry = tarfile.TarInfo(name)
            entry.size = len(data)
            package.addfile(entry, io.BytesIO(data))
    return buffer.getvalue()


class SelectArtifactTest(unittest.TestCase):
    def test_newest_artifact_of_branch_wins(self) -> None:
        artifacts = [
            artifact(1, "2026-11-01T00:00:00Z"),
            artifact(3, "2026-11-17T02:15:08Z"),
            artifact(2, "2026-11-10T00:00:00Z"),
        ]
        self.assertEqual(fetch_native_artifact.select_artifact(artifacts, NAME)["id"], 3)

    def test_expired_artifact_is_skipped(self) -> None:
        artifacts = [
            artifact(1, "2026-11-01T00:00:00Z"),
            artifact(2, "2026-11-17T00:00:00Z", expired=True),
        ]
        self.assertEqual(fetch_native_artifact.select_artifact(artifacts, NAME)["id"], 1)

    def test_other_name_is_skipped(self) -> None:
        artifacts = [artifact(1, "2026-11-17T00:00:00Z", name="qfli-native-ios-extra")]
        self.assertIsNone(fetch_native_artifact.select_artifact(artifacts, NAME))

    def test_other_branch_is_skipped(self) -> None:
        artifacts = [
            artifact(1, "2026-11-01T00:00:00Z"),
            artifact(2, "2026-11-17T00:00:00Z", branch="feature"),
        ]
        self.assertEqual(fetch_native_artifact.select_artifact(artifacts, NAME)["id"], 1)
        self.assertEqual(fetch_native_artifact.select_artifact(artifacts, NAME, branch="feature")["id"], 2)

    def test_run_id_selects_one_run_on_any_branch(self) -> None:
        artifacts = [
            artifact(1, "2026-11-17T00:00:00Z", run_id=10),
            artifact(2, "2026-11-01T00:00:00Z", run_id=20, branch="feature"),
        ]
        self.assertEqual(fetch_native_artifact.select_artifact(artifacts, NAME, run_id="20")["id"], 2)
        self.assertIsNone(fetch_native_artifact.select_artifact(artifacts, NAME, run_id="30"))

    def test_artifact_without_run_is_skipped(self) -> None:
        orphan = artifact(1, "2026-11-17T00:00:00Z")
        orphan["workflow_run"] = None
        self.assertIsNone(fetch_native_artifact.select_artifact([orphan], NAME))

    def test_no_artifact(self) -> None:
        self.assertIsNone(fetch_native_artifact.select_artifact([], NAME))


class MissingMessageTest(unittest.TestCase):
    def test_branch_message_names_the_source_workflow(self) -> None:
        message = fetch_native_artifact.missing_message(NAME, None, "main")
        self.assertIn(NAME, message)
        self.assertIn("branch 'main'", message)
        self.assertIn('"Native artifacts"', message)

    def test_run_message_names_the_run(self) -> None:
        message = fetch_native_artifact.missing_message(NAME, "44001588302", "main")
        self.assertIn("run 44001588302", message)
        self.assertNotIn("branch", message)


class ParseDigestTest(unittest.TestCase):
    DIGEST = "ab" * 32

    def test_text_mode_line(self) -> None:
        text = f"{self.DIGEST}  {ARCHIVE}\n"
        self.assertEqual(fetch_native_artifact.parse_digest(text, ARCHIVE), self.DIGEST)

    def test_binary_mode_line(self) -> None:
        text = f"{self.DIGEST.upper()} *{ARCHIVE}\n"
        self.assertEqual(fetch_native_artifact.parse_digest(text, ARCHIVE), self.DIGEST)

    def test_other_archive_name_fails(self) -> None:
        with self.assertRaises(RuntimeError):
            fetch_native_artifact.parse_digest(f"{self.DIGEST}  other.tar.gz\n", ARCHIVE)

    def test_bad_digest_fails(self) -> None:
        for digest in ("ab" * 31, "zz" * 32):
            with self.subTest(digest=digest):
                with self.assertRaises(RuntimeError):
                    fetch_native_artifact.parse_digest(f"{digest}  {ARCHIVE}\n", ARCHIVE)

    def test_empty_text_fails(self) -> None:
        with self.assertRaises(RuntimeError):
            fetch_native_artifact.parse_digest("", ARCHIVE)


class UnpackOuterTest(unittest.TestCase):
    def setUp(self) -> None:
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.directory = Path(scratch.name)
        self.payload = tarball({"package/manifest.json": b"{}\n"})
        self.digest = hashlib.sha256(self.payload).hexdigest()

    def outer(self, files: dict[str, bytes]) -> Path:
        path = self.directory / "artifact.zip"
        with zipfile.ZipFile(path, "w") as package:
            for name, data in files.items():
                package.writestr(name, data)
        return path

    def test_archive_and_digest_are_returned(self) -> None:
        outer = self.outer({
            ARCHIVE: self.payload,
            f"{ARCHIVE}.sha256": f"{self.digest}  {ARCHIVE}\n".encode("utf-8"),
        })
        inner, expected = fetch_native_artifact.unpack_outer(outer, self.directory)
        self.assertEqual(inner, self.directory / ARCHIVE)
        self.assertEqual(expected, self.digest)
        self.assertEqual(fetch_native_artifact.sha256(inner), self.digest)

    def test_missing_digest_file_fails(self) -> None:
        with self.assertRaises(RuntimeError):
            fetch_native_artifact.unpack_outer(self.outer({ARCHIVE: self.payload}), self.directory)

    def test_two_archives_fail(self) -> None:
        outer = self.outer({
            ARCHIVE: self.payload,
            f"{ARCHIVE}.sha256": f"{self.digest}  {ARCHIVE}\n".encode("utf-8"),
            "second.tar.gz": self.payload,
        })
        with self.assertRaises(RuntimeError):
            fetch_native_artifact.unpack_outer(outer, self.directory)

    def test_digest_for_another_archive_fails(self) -> None:
        outer = self.outer({
            ARCHIVE: self.payload,
            f"{ARCHIVE}.sha256": f"{self.digest}  other.tar.gz\n".encode("utf-8"),
        })
        with self.assertRaises(RuntimeError):
            fetch_native_artifact.unpack_outer(outer, self.directory)


class ExtractTest(unittest.TestCase):
    def test_archive_is_extracted_into_a_new_directory(self) -> None:
        with tempfile.TemporaryDirectory() as scratch:
            archive = Path(scratch) / ARCHIVE
            archive.write_bytes(tarball({"package/manifest.json": b"{}\n"}))
            target = Path(scratch) / "native" / "package-root"
            fetch_native_artifact.extract(archive, target)
            self.assertEqual((target / "package/manifest.json").read_bytes(), b"{}\n")

    def test_path_outside_the_target_fails(self) -> None:
        with tempfile.TemporaryDirectory() as scratch:
            archive = Path(scratch) / ARCHIVE
            archive.write_bytes(tarball({"../escape.txt": b"x"}))
            with self.assertRaises(tarfile.TarError):
                fetch_native_artifact.extract(archive, Path(scratch) / "target")
            self.assertFalse((Path(scratch) / "escape.txt").exists())


if __name__ == "__main__":
    unittest.main()
