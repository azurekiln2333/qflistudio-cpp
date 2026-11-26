#!/usr/bin/env python3
"""Archive bounded release outputs before installer assembly on hosted runners."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tarfile


OUTPUT_PATTERNS = {
    "android": ("build/app/intermediates/flutter/release",),
    "windows": ("build/windows/x64/runner/Release",),
    "linux": ("build/linux/x64/release/bundle",),
    "macos": ("build/macos/Build/Products/Release/*.app",),
    "ios": ("build/ios/archive/*.xcarchive",),
    # The fork stages these Flutter outputs before Hvigor packages the HAP.
    # Cache stamps are not build payloads; SDK/Hvigor caches stay excluded.
    "ohos": (
        "ohos/entry/libs/arm64-v8a/libapp.so",
        "ohos/entry/src/main/resources/rawfile/flutter_assets",
    ),
}


def source_paths(root: Path, platform: str) -> list[Path]:
    candidates = sorted({path for pattern in OUTPUT_PATTERNS[platform]
                         for path in root.glob(pattern) if path.exists()})
    sources = [path for path in candidates
               if not any(parent in candidates for parent in path.parents)]
    if not sources:
        raise RuntimeError(f"No Flutter release output for {platform}: {OUTPUT_PATTERNS[platform]}")
    if platform == "ohos":
        aot = root / OUTPUT_PATTERNS["ohos"][0]
        assets = root / OUTPUT_PATTERNS["ohos"][1]
        if not aot.is_file() or not aot.stat().st_size:
            raise RuntimeError("OHOS Flutter output is missing its AOT libapp.so payload")
        if not assets.is_dir() or not any(path.is_file() for path in assets.rglob("*")):
            raise RuntimeError("OHOS Flutter output is missing its flutter_assets payload")
    return sources


def archive_build(root: Path, platform: str, abi: str | None = None) -> dict:
    sources = source_paths(root, platform)
    output = root / "dist/flutter-build"
    output.mkdir(parents=True, exist_ok=True)
    name = f"flutter-build-{platform}" + (f"-{abi}" if abi else "")
    archive = output / f"{name}.tar.gz"
    with tarfile.open(archive, "w:gz", dereference=False) as target:
        for path in sources:
            target.add(path, arcname=path.relative_to(root).as_posix())
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    record = {
        "applicationCommit": os.environ.get("GITHUB_SHA"),
        "coreCommit": os.environ.get("CORE_REVISION"),
        "nativeRunId": os.environ.get("NATIVE_RUN_ID") or None,
        "flutterVersion": os.environ.get("FLUTTER_OHOS_TAG", os.environ.get("FLUTTER_VERSION")),
        "flutterCommit": os.environ.get("FLUTTER_OHOS_REVISION", os.environ.get("FLUTTER_REVISION")),
        "platform": platform,
        "abi": abi,
        "sources": [path.relative_to(root).as_posix() for path in sources],
        "archive": archive.name,
        "size": archive.stat().st_size,
        "sha256": digest.hexdigest(),
        "retentionDays": 7,
    }
    (output / "provenance.json").write_bytes((json.dumps(record, indent=2) + "\n").encode())
    (output / "SHA256SUMS").write_bytes(f"{record['sha256']}  {archive.name}\n".encode())
    print(json.dumps(record, indent=2))
    return record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=OUTPUT_PATTERNS)
    parser.add_argument("--abi", choices=("arm64-v8a", "x86_64"))
    args = parser.parse_args()
    archive_build(Path.cwd(), args.platform, args.abi)


if __name__ == "__main__":
    main()
