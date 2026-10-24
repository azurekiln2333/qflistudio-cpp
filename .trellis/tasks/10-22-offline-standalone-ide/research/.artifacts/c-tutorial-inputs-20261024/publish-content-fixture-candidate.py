"""Conditional exact-tree publication; only the owned window may invoke this."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT.parent / "qfli_studio_core"
BASE = "6aaf5a5d64fc96e6e7748ce5a45671e0706be570"
CORE_COMMIT = "2f9039a3ba95449679b17257b0313c1ee3644a2c"
CORE_TREE = "d21ffcdc7ac9c834e0b788b21178e9f80768a519"
FILES = (
    "tool/forge_content/generate_forge_content.dart",
    "tool/forge_content/verify_forge_content.dart",
    "tool/forge_content/staging/forge_tutorials.json",
    "test/forge_tutorial_fixture_test.dart",
)


def git(*args, cwd=ROOT, data=None):
    env = dict(os.environ)
    env.pop("GIT_INDEX_FILE", None)
    return subprocess.check_output(["git", *args], cwd=cwd, env=env, input=data).decode().strip()


def verify_map(mapping):
    for name, expected in mapping.items():
        if hashlib.sha256(Path(name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Source drift: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", args.run_id):
        parser.error("Invalid run ID")
    prefix = ROOT / "build" / ("c-content-fixture-" + args.run_id)
    load = lambda suffix: json.loads(Path(str(prefix) + "-" + suffix + ".json").read_text())
    candidate = load("candidate")
    if (candidate["base"], candidate["coreCommit"], candidate["coreTree"]) != (BASE, CORE_COMMIT, CORE_TREE):
        raise RuntimeError("Candidate pins differ from authorized publication pins")
    if candidate["runId"] != args.run_id or sorted(candidate["files"]) != sorted(FILES):
        raise RuntimeError("Candidate must contain exactly the authorized four paths")
    if set(candidate["blobs"]) != set(FILES) or set(candidate["workingSha256"]) != set(FILES):
        raise RuntimeError("Candidate file/hash map is incomplete or overbroad")
    for name, sentinel in (("format", "Formatted 3 files"), ("generator", "GENERATOR SEMANTICS PASS"), ("tests", "All tests passed!"), ("analyze", "No issues found!")):
        content = Path(str(prefix) + "-" + name + ".log").read_text(encoding="utf-8", errors="replace")
        if sentinel not in content:
            raise RuntimeError("Unpassed same-run gate: " + name)
    generated = load("generator-report")
    if generated.get("passed") is not True or generated.get("candidateAssetsUnchanged") is not True:
        raise RuntimeError("Generator semantics/preservation gate is incomplete")
    if generated.get("tree") != candidate["tree"] or generated.get("ignoredSemanticKeys") != ["updatedAt"]:
        raise RuntimeError("Generator report is not bound to this exact candidate")
    if set(generated.get("assets", {})) != {"forge_tutorials.json", "forge_examples.json"}:
        raise RuntimeError("Generator report omits a required aggregate")
    if not all(row.get("semanticsEqualIgnoringOnlyUpdatedAt") is True for row in generated["assets"].values()):
        raise RuntimeError("Generator semantics differ")
    verified = load("staged-verifier")
    if verified.get("nativeRequired") is not False:
        raise RuntimeError("This window must never run native curriculum compilation")
    if (verified.get("cCount"), verified.get("cppCount"), verified.get("tutorialCount"), verified.get("exampleCount"), verified.get("passed"), verified.get("failed")) != (100, 100, 200, 200, 200, 0):
        raise RuntimeError("Complete original 200-pair staged gate did not pass")
    if verified.get("shapeErrors") or verified.get("stagedAssetErrors"):
        raise RuntimeError("Verifier retained content errors")
    results = verified.get("results", [])
    expected_ids = {f"{language}-example-{number:03d}" for language in ("c", "cpp") for number in range(1, 101)}
    if len(results) != 200 or {row.get("id") for row in results} != expected_ids:
        raise RuntimeError("Verifier result inventory differs from original 200 IDs")
    if any(row.get("status") != "staged_ok_no_native" for row in results):
        raise RuntimeError("Unexpected native or failed verifier status")
    if git("rev-parse", "HEAD") != BASE or git("rev-parse", "HEAD", cwd=CORE) != CORE_COMMIT:
        raise RuntimeError("C/core source checkpoint moved; publication refused")
    if git("diff", "--cached", "--name-only"):
        raise RuntimeError("Real index is not empty; publication refused")
    verify_map(candidate["inputs"])
    verify_map(candidate["protectedRootWorking"])
    verify_map({str(ROOT / name): value for name, value in candidate["workingSha256"].items()})
    verify_map({str(ROOT / name): value for name, value in candidate["helperSha256"].items()})
    for name, blob in candidate["blobs"].items():
        if git("rev-parse", candidate["tree"] + ":" + name) != blob:
            raise RuntimeError("Frozen tree/blob mismatch: " + name)
    # This is the first real-index mutation, after every source/gate guard.
    entries = "".join("100644 " + candidate["blobs"][name] + "\t" + name + "\n" for name in FILES)
    git("update-index", "--add", "--index-info", data=entries.encode("utf-8"))
    if git("write-tree") != candidate["tree"]:
        raise RuntimeError("Real staged tree differs; no commit was made")
    git("diff", "--cached", "--check")
    env = dict(os.environ)
    env.pop("GIT_INDEX_FILE", None)
    subprocess.run(["git", "commit", "-m", "fix(content): preserve tutorial stdin fixtures for editor imports"], cwd=ROOT, env=env, check=True)
    commit = git("rev-parse", "HEAD")
    if git("rev-parse", "HEAD^{tree}") != candidate["tree"] or git("rev-parse", "HEAD^") != BASE:
        raise RuntimeError("Committed identity differs from exact tested tree")
    if git("diff", "--cached", "--name-only"):
        raise RuntimeError("Real index retained unexpected staged changes")
    report = {"commit": commit, "tree": candidate["tree"], "base": BASE, "coreCommit": CORE_COMMIT, "coreTree": CORE_TREE, "files": candidate["blobs"], "scope": candidate["scope"]}
    Path(str(prefix) + "-published.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EXACT TESTED C CONTENT FIXTURE CHECKPOINT", commit, "TREE", candidate["tree"])


if __name__ == "__main__":
    main()
