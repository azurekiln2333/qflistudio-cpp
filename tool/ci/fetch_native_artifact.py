#!/usr/bin/env python3
"""Download and verify one output of the "Native artifacts" workflow.

The application jobs do not rebuild LLVM. They take the newest unexpired
package that the "Native artifacts" workflow uploaded for the selected branch,
or the package of one pinned run. The GitHub CLI reads the token from GH_TOKEN.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile


WORKFLOW_NAME = "Native artifacts"
PAGE_SIZE = 100


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def select_artifact(artifacts: list[dict], name: str, run_id: str | None = None,
                    branch: str = "main") -> dict | None:
    """Return the newest unexpired artifact for one run or one branch."""
    candidates = []
    for artifact in artifacts:
        if artifact.get("name") != name or artifact.get("expired"):
            continue
        run = artifact.get("workflow_run") or {}
        if run_id:
            if str(run.get("id")) != str(run_id):
                continue
        elif run.get("head_branch") != branch:
            continue
        candidates.append(artifact)
    return max(candidates, key=lambda artifact: artifact["created_at"], default=None)


def missing_message(name: str, run_id: str | None, branch: str) -> str:
    source = f"run {run_id}" if run_id else f"branch '{branch}'"
    return (
        f"No unexpired artifact '{name}' exists for {source}. "
        f'Run the "{WORKFLOW_NAME}" workflow first, or provide a different '
        "unexpired native_run_id."
    )


def parse_digest(text: str, archive_name: str) -> str:
    fields = text.split()
    if len(fields) != 2 or fields[1].lstrip("*") != archive_name:
        raise RuntimeError(f"Digest file does not describe {archive_name}.")
    digest = fields[0].lower()
    if len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        raise RuntimeError("Digest file holds no SHA-256 value.")
    return digest


def gh(*arguments: str) -> bytes:
    return subprocess.run(["gh", "api", *arguments], check=True, stdout=subprocess.PIPE).stdout


def list_artifacts(repository: str, name: str) -> list[dict]:
    artifacts: list[dict] = []
    page = 1
    while True:
        document = json.loads(gh(
            f"repos/{repository}/actions/artifacts?name={name}&per_page={PAGE_SIZE}&page={page}"
        ))
        batch = document.get("artifacts", [])
        artifacts.extend(batch)
        if len(batch) < PAGE_SIZE:
            return artifacts
        page += 1


def download(repository: str, artifact: dict, target: Path) -> None:
    with target.open("wb") as stream:
        subprocess.run(
            ["gh", "api", f"repos/{repository}/actions/artifacts/{artifact['id']}/zip"],
            check=True, stdout=stream,
        )


def unpack_outer(outer: Path, directory: Path) -> tuple[Path, str]:
    """Extract the inner archive and return it with its expected digest."""
    with zipfile.ZipFile(outer) as package:
        names = [entry.filename for entry in package.infolist() if not entry.is_dir()]
        archives = [name for name in names if name.endswith(".tar.gz")]
        if len(archives) != 1 or f"{archives[0]}.sha256" not in names:
            raise RuntimeError("Artifact must hold one .tar.gz archive and its .sha256 file.")
        archive_name = PurePosixPath(archives[0]).name
        expected = parse_digest(
            package.read(f"{archives[0]}.sha256").decode("utf-8"), archive_name)
        inner = directory / archive_name
        with package.open(archives[0]) as source, inner.open("wb") as sink:
            shutil.copyfileobj(source, sink)
    return inner, expected


def extract(archive: Path, target: Path) -> None:
    if not hasattr(tarfile, "data_filter"):
        raise RuntimeError("This Python has no tar extraction filter. Use Python 3.12 or newer.")
    target.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as package:
        package.extractall(target, filter="data")


def fetch(args: argparse.Namespace) -> None:
    repository = args.repository or os.environ["GITHUB_REPOSITORY"]
    run_id = (args.run_id or "").strip() or None
    artifact = select_artifact(list_artifacts(repository, args.name), args.name, run_id, args.branch)
    if artifact is None:
        raise RuntimeError(missing_message(args.name, run_id, args.branch))
    run = artifact.get("workflow_run") or {}
    print(f"Using artifact {artifact['id']} of run {run.get('id')} ({run.get('head_sha')}), "
          f"expires {artifact.get('expires_at')}.")
    if args.check_only:
        return
    temporary = Path(os.environ.get("RUNNER_TEMP") or tempfile.gettempdir())
    with tempfile.TemporaryDirectory(dir=temporary, prefix="native-input-") as scratch:
        outer = Path(scratch) / "artifact.zip"
        download(repository, artifact, outer)
        inner, expected = unpack_outer(outer, Path(scratch))
        outer.unlink()
        actual = sha256(inner)
        if actual != expected:
            raise RuntimeError(f"SHA-256 of {inner.name} differs from its digest file.")
        extract(inner, args.extract_to)
        record = {
            "name": artifact["name"],
            "artifactId": artifact["id"],
            "runId": run.get("id"),
            "headSha": run.get("head_sha"),
            "headBranch": run.get("head_branch"),
            "createdAt": artifact.get("created_at"),
            "expiresAt": artifact.get("expires_at"),
            "archive": inner.name,
            "archiveSha256": actual,
        }
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {record['archive']} and extracted it to {args.extract_to}.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="artifact name")
    parser.add_argument("--extract-to", required=True, type=Path, help="extraction directory")
    parser.add_argument("--record", required=True, type=Path, help="output JSON record")
    parser.add_argument("--run-id", help='run of the "Native artifacts" workflow')
    parser.add_argument("--repository", help="owner/repository, default GITHUB_REPOSITORY")
    parser.add_argument("--branch", default="main", help="branch of the source run")
    parser.add_argument("--check-only", action="store_true", help="verify selection without downloading")
    args = parser.parse_args()
    try:
        fetch(args)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError,
            tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"Native input failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
