"""Freeze/generate-check helpers; execute only inside an owned host window."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile


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
HELPERS = (
    "build/freeze-content-fixture-candidate.py",
    "build/prepare-content-fixture-window.py",
    "build/publish-content-fixture-candidate.py",
)
DART = Path(r"D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def git(*args, cwd=ROOT, env=None, data=None):
    if env is None:
        env = dict(os.environ)
        env.pop("GIT_INDEX_FILE", None)
    return subprocess.check_output(
        ["git", *args], cwd=cwd, env=env, input=data
    ).decode("utf-8").strip()


def paths_for(run_id):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", run_id):
        raise ValueError("Use a fresh simple run ID, at most 80 characters")
    prefix = ROOT / "build" / ("c-content-fixture-" + run_id)
    return {
        "prefix": prefix,
        "candidate": Path(str(prefix) + "-candidate.json"),
        "snapshot": Path(str(prefix) + "-snapshot"),
        "index": Path(str(prefix) + ".index"),
        "archive": Path(str(prefix) + "-candidate.tar"),
        "generatorReport": Path(str(prefix) + "-generator-report.json"),
    }


def file_map(directory, names):
    result = {}
    for name in names:
        path = directory / name
        if not path.exists():
            continue
        for item in sorted(path.rglob("*")) if path.is_dir() else [path]:
            if item.is_file():
                result[str(item)] = sha(item)
    return result


def verify_map(mapping):
    for name, expected in mapping.items():
        if sha(name) != expected:
            raise RuntimeError("Source drift: " + name)


def freeze(run_id):
    paths = paths_for(run_id)
    if git("rev-parse", "HEAD") != BASE:
        raise RuntimeError("C HEAD changed from the authorized base")
    if git("rev-parse", "HEAD", cwd=CORE) != CORE_COMMIT:
        raise RuntimeError("Core HEAD changed from the exact pinned checkpoint")
    if git("rev-parse", CORE_COMMIT + "^{tree}", cwd=CORE) != CORE_TREE:
        raise RuntimeError("Pinned core tree mismatch")
    if git("diff", "--cached", "--name-only"):
        raise RuntimeError("Real index is not empty; refusing to freeze")
    for key in ("candidate", "snapshot", "index", "archive", "generatorReport"):
        if paths[key].exists():
            raise RuntimeError("Run ID already has artifacts: " + str(paths[key]))
    core_snapshot = CORE / "build/checkpoints" / CORE_TREE[:12]
    if not (core_snapshot / "lib/services/studio_profile.dart").is_file():
        raise RuntimeError("Exact published core snapshot is missing")
    published_core = json.loads(
        (CORE / "build/c-workspace-followup-published.json").read_text()
    )
    if (published_core["commit"], published_core["tree"]) != (
        CORE_COMMIT, CORE_TREE
    ):
        raise RuntimeError("Core snapshot publication record mismatch")

    protected = file_map(ROOT, ["lib", "assets"])
    working = {name: sha(ROOT / name) for name in FILES}
    helpers = {name: sha(ROOT / name) for name in HELPERS}
    env = dict(os.environ, GIT_INDEX_FILE=str(paths["index"]))
    git("read-tree", BASE, env=env)
    blobs = {}
    for name in FILES:
        blobs[name] = git(
            "hash-object", "-w", "--path=" + name, "--stdin",
            env=env, data=(ROOT / name).read_bytes(),
        )
        git("update-index", "--add", "--cacheinfo", "100644", blobs[name], name, env=env)
    changed = git("diff", "--cached", "--name-only", BASE, env=env).splitlines()
    if sorted(changed) != sorted(FILES):
        raise RuntimeError("Candidate must contain exactly the authorized four files")
    git("diff", "--cached", "--check", env=env)
    tree = git("write-tree", env=env)
    git("archive", "--format=tar", "--output=" + str(paths["archive"]), tree, env=env)
    paths["snapshot"].mkdir()
    with tarfile.open(paths["archive"]) as bundle:
        bundle.extractall(paths["snapshot"], filter="data")
    for name in (
        ".dart_tool/package_config.json", ".dart_tool/package_graph.json",
        ".flutter-plugins-dependencies", ".flutter-plugins",
    ):
        source = ROOT / name
        if source.is_file():
            target = paths["snapshot"] / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    config_path = paths["snapshot"] / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text())
    bindings = {
        "qfli_c": paths["snapshot"],
        "qfli_c_runtime": paths["snapshot"] / "packages/qfli_c_runtime",
        "qfli_studio_core": core_snapshot,
        "re_editor": core_snapshot / "vendor/re_editor",
    }
    for package in config["packages"]:
        if package["name"] in bindings:
            package["rootUri"] = bindings[package["name"]].as_uri()
        elif "://" not in package["rootUri"]:
            package["rootUri"] = (ROOT / ".dart_tool" / package["rootUri"]).resolve().as_uri()
    write_json(config_path, config)
    inputs = file_map(paths["snapshot"], [
        "lib", "assets", "test", "tool", "packages/qfli_c_runtime", "pubspec.yaml", "pubspec.lock",
        "analysis_options.yaml", ".dart_tool/package_config.json",
    ])
    inputs.update(file_map(core_snapshot, [
        "lib", "assets", "vendor/re_editor/lib", "pubspec.yaml", "pubspec.lock",
        ".dart_tool/package_config.json",
    ]))
    verify_map(protected)
    if git("diff", "--cached", "--name-only"):
        raise RuntimeError("Real index changed while freezing; no publication allowed")
    report = {
        "runId": run_id,
        "base": BASE,
        "tree": tree,
        "coreCommit": CORE_COMMIT,
        "coreTree": CORE_TREE,
        "files": list(FILES),
        "blobs": blobs,
        "workingSha256": working,
        "snapshot": str(paths["snapshot"]),
        "coreSnapshot": str(core_snapshot),
        "packageConfig": str(config_path),
        "inputs": inputs,
        "protectedRootWorking": protected,
        "helperSha256": helpers,
        "scope": "Four-file tutorial stdin fixture repair; staged semantics/materialization only, no native or device execution.",
    }
    write_json(paths["candidate"], report)
    print(json.dumps({"tree": tree, "files": blobs, "inputs": len(inputs), "candidate": str(paths["candidate"])}))


def semantic(value):
    if isinstance(value, dict):
        return {key: semantic(item) for key, item in value.items() if key != "updatedAt"}
    if isinstance(value, list):
        return [semantic(item) for item in value]
    return value


def generate_check(run_id):
    paths = paths_for(run_id)
    candidate = json.loads(paths["candidate"].read_text())
    if candidate["base"] != BASE or candidate["coreCommit"] != CORE_COMMIT:
        raise RuntimeError("Candidate pins do not match this helper")
    verify_map(candidate["inputs"])
    snapshot = Path(candidate["snapshot"])
    config = Path(candidate["packageConfig"])
    asset_paths = [snapshot / "tool/forge_content/staging" / name for name in (
        "forge_tutorials.json", "forge_examples.json", "forge_manifest.json",
    )]
    original_assets = {str(path): sha(path) for path in asset_paths}
    report = {"runId": run_id, "tree": candidate["tree"], "passed": False, "ignoredSemanticKeys": ["updatedAt"], "assets": {}}
    try:
        with tempfile.TemporaryDirectory(prefix="c-content-fixture-generation-", dir=ROOT / "build") as temporary:
            temporary = Path(temporary)
            shutil.copyfile(snapshot / "pubspec.yaml", temporary / "pubspec.yaml")
            command = [str(DART), "--packages=" + str(config), str(snapshot / FILES[0])]
            report["command"] = command
            report["temporaryCwd"] = str(temporary)
            # The outer OwnedJob owns this direct Dart child and its descendants.
            # Never use `dart run`, pub resolution, or the candidate as the cwd.
            subprocess.run(command, cwd=temporary, check=True)
            generated_staging = temporary / "tool/forge_content/staging"
            for name in ("forge_tutorials.json", "forge_examples.json"):
                expected = snapshot / "tool/forge_content/staging" / name
                actual = generated_staging / name
                expected_semantics = semantic(json.loads(expected.read_bytes()))
                actual_semantics = semantic(json.loads(actual.read_bytes()))
                equal = actual_semantics == expected_semantics
                report["assets"][name] = {
                    "candidateSha256": sha(expected),
                    "generatedSha256": sha(actual),
                    "semanticsEqualIgnoringOnlyUpdatedAt": equal,
                }
                if not equal:
                    raise RuntimeError("Generated content semantics differ: " + name)
            report["passed"] = True
    except BaseException as error:
        report["error"] = repr(error)
        raise
    finally:
        verify_map(original_assets)
        verify_map(candidate["inputs"])
        report["candidateAssetsUnchanged"] = True
        write_json(paths["generatorReport"], report)
    print("GENERATOR SEMANTICS PASS; candidate assets unchanged; ignored only updatedAt")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--generate-check", action="store_true")
    args = parser.parse_args()
    if args.generate_check:
        generate_check(args.run_id)
    else:
        freeze(args.run_id)


if __name__ == "__main__":
    main()
