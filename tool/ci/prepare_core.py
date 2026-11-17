#!/usr/bin/env python3
"""Apply the reviewed core compatibility patch to a clean CI checkout.

Use only with upstream Flutter. OHOS builds must use the unpatched core checkout
with the OHOS Flutter fork. The local shared core is never copied or modified by
this script unless it is explicitly passed, clean, and at the pinned revision.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys


CORE_REVISION = "573d1b6eecf1c2b392ad753264a5a09f62f8335e"
PATCH = Path(__file__).with_name("stock-flutter-core.patch")


def git(core: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(core), *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def prepare(
    core: Path,
    flutter: Path,
    *,
    check_only: bool = False,
    revision: str = CORE_REVISION,
    patch: Path = PATCH,
) -> None:
    core = core.resolve(strict=True)
    flutter = flutter.resolve(strict=True)
    patch = patch.resolve(strict=True)
    platform = flutter / "packages/flutter/lib/src/foundation/platform.dart"
    source = platform.read_text(encoding="utf-8")
    if re.search(r"^\s*ohos\s*,", source, flags=re.MULTILINE):
        raise RuntimeError("Do not apply the stock Flutter patch to an OHOS SDK.")
    if "enum TargetPlatform" not in source:
        raise RuntimeError(f"Flutter TargetPlatform enum not found: {platform}")
    actual = git(core, "rev-parse", "HEAD")
    if actual != revision:
        raise RuntimeError(f"Core revision must be {revision}; found {actual}.")
    if git(core, "status", "--porcelain", "--untracked-files=all"):
        raise RuntimeError("Core checkout must be clean; local edits are preserved.")
    git(core, "apply", "--check", str(patch))
    if not check_only:
        git(core, "apply", str(patch))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--flutter", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="Validate without editing.")
    args = parser.parse_args()
    try:
        prepare(args.core, args.flutter, check_only=args.check)
    except (OSError, RuntimeError) as error:
        print(f"Core preparation failed: {error}", file=sys.stderr)
        return 1
    action = "Checked" if args.check else "Applied"
    print(f"{action} stock Flutter core patch at {CORE_REVISION}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
