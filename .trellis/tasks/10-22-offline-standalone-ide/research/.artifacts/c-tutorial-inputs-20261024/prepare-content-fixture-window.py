"""Prepare an explicitly coordinated <=55s window; never execute its commands."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
import uuid


ROOT = Path(__file__).resolve().parents[1]
BASE = "6aaf5a5d64fc96e6e7748ce5a45671e0706be570"
CORE = "2f9039a3ba95449679b17257b0313c1ee3644a2c"
DART = r"D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe"
FLUTTER = [DART, "--disable-dart-dev", r"D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot"]
DART_FILES = [
    "tool/forge_content/generate_forge_content.dart",
    "tool/forge_content/verify_forge_content.dart",
    "test/forge_tutorial_fixture_test.dart",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--release-successor", required=True,
        help="Current explicitly authorized successor and bounded window; no stored/default peer",
    )
    parser.add_argument("--run-id")
    args = parser.parse_args()
    successor = args.release_successor.strip()
    if not successor or "\n" in successor or "\r" in successor:
        parser.error("Provide one explicit current release successor line")
    run_id = args.run_id or (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8])
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", run_id):
        parser.error("Use a fresh simple run ID, at most 80 characters")
    prefix = ROOT / "build" / ("c-content-fixture-" + run_id)
    if list(prefix.parent.glob(prefix.name + "*")):
        parser.error("This run ID already has artifacts; choose a fresh one")
    snapshot = Path(str(prefix) + "-snapshot")
    package_config = snapshot / ".dart_tool/package_config.json"
    verifier_report = Path(str(prefix) + "-staged-verifier.json")
    log = lambda suffix: str(prefix) + "-" + suffix + ".log"
    freeze = str(ROOT / "build/freeze-content-fixture-candidate.py")
    config = {
        "runId": run_id,
        "cwd": str(ROOT),
        "seconds": 55,
        "report": str(prefix) + "-window-report.json",
        "baseCommit": BASE,
        "coreCommit": CORE,
        "release": (
            "C content-fixture host gate TERMINAL; RELEASE NOW to " + successor
            + ". No retained C heavy reservation or device grant."
        ),
        "steps": [
            {"name": "format only three authorized Dart content fixture files", "command": [DART, "format", *DART_FILES], "seconds": 3, "log": log("format")},
            {"name": "freeze exact four-file content candidate", "command": [sys.executable, freeze, "--run-id", run_id], "seconds": 6, "log": log("freeze")},
            {"name": "generate in temporary cwd and compare exact staged semantics", "command": [sys.executable, freeze, "--run-id", run_id, "--generate-check"], "seconds": 5, "log": log("generator")},
            {"name": "verify staged content without native execution", "command": [DART, "--packages=" + str(package_config), str(snapshot / DART_FILES[1]), "--no-native", "--report", str(verifier_report)], "cwd": str(snapshot), "seconds": 4, "continue_on_failure": True, "log": log("verify")},
            {"name": "test fixture materialization repository and pipeline", "command": FLUTTER + ["test", "--no-pub", "--concurrency=1", "--reporter=expanded", "--timeout", "10s", "test/forge_tutorial_fixture_test.dart", "test/forge_content_repository_test.dart", "test/forge_content_pipeline_test.dart"], "cwd": str(snapshot), "seconds": 15, "continue_on_failure": True, "log": log("tests")},
            {"name": "analyze only three Dart content fixture files", "command": [DART, "analyze", *DART_FILES], "cwd": str(snapshot), "seconds": 6, "continue_on_failure": True, "log": log("analyze")},
            {"name": "commit only exact fully verified four-file content tree", "command": [sys.executable, str(ROOT / "build/publish-content-fixture-candidate.py"), "--run-id", run_id], "seconds": 5, "minimum_start_budget": 5, "requires_all_previous_success": True, "continue_on_failure": True, "log": log("publish")},
        ],
    }
    assert sum(step["seconds"] for step in config["steps"]) == 44
    path = Path(str(prefix) + "-window.json")
    path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "config": str(path), "runId": run_id, "seconds": 55,
        "maxStepSeconds": 44, "releaseSuccessor": successor,
        "runner": str(ROOT.parent / "qfli_studio_core/build/run-c-core-window.py"),
        "note": "Prepared only. Execute the existing OwnedJob runner only after the current resource grant.",
    }))


if __name__ == "__main__":
    main()
