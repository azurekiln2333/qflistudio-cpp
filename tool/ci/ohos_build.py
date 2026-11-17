#!/usr/bin/env python3
"""Bootstrap a hosted OHOS build and package its unsigned outputs.

Run only in the disposable GitHub Actions checkout. The command line tools URL
and SHA-256 come from the lock file or a complete workflow/repository override. No signing key,
password, certificate, or local SDK is copied from a developer workstation.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.parse
import urllib.request
import zipfile


PROJECT = Path(__file__).resolve().parents[2]

HAP_ABI = "arm64-v8a"
HAP_REQUIRED = (
    "libs/arm64-v8a/libflutter.so",
    "libs/arm64-v8a/libapp.so",
    "libs/arm64-v8a/libqfli_ohos_runner.so",
    "resources/rawfile/qfli_toolchain/ohos-wasi.zip",
)
HAP_RESOURCE_PREFIX = "resources/rawfile/qfli_toolchain/"
HAP_OUTPUT = "qfli-forge-ohos-arm64-unsigned.hap"
APP_OUTPUT = "qfli-forge-ohos-arm64-unsigned.app"

SIGNING_NOTE = (
    "QFLIForge HarmonyOS packages (ARM64)\n"
    "\n"
    "Signing: unsigned.\n"
    "The CI copy removed the signing configuration before the build.\n"
    "Sign the HAP or the APP with a HarmonyOS certificate and profile before installation.\n"
    "An unsigned package does not install on a device.\n"
    "Device execution was not tested.\n"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_ci() -> Path:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Use this helper only in the disposable GitHub Actions checkout.")
    workspace = Path(os.environ["GITHUB_WORKSPACE"]).resolve()
    if not PROJECT.is_relative_to(workspace):
        raise RuntimeError("Project is outside GITHUB_WORKSPACE.")
    return Path(os.environ["RUNNER_TEMP"])


def parse_json5(text: str) -> dict:
    """Parse the JSON5 subset of build-profile.json5.

    Accepts `//` and `/* */` comments and trailing commas. String literals are
    double-quoted and are copied verbatim.
    """
    chunks: list[str] = []
    index, length = 0, len(text)
    while index < length:
        char = text[index]
        if char == '"':
            end = index + 1
            while end < length and text[end] != '"':
                if text[end] == "\n":
                    raise ValueError("Unterminated string in JSON5 text.")
                end += 2 if text[end] == "\\" else 1
            if end >= length:
                raise ValueError("Unterminated string in JSON5 text.")
            chunks.append(text[index:end + 1])
            index = end + 1
        elif text.startswith("//", index):
            end = text.find("\n", index)
            index = length if end < 0 else end
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated block comment in JSON5 text.")
            chunks.append(" ")
            index = end + 2
        else:
            if char in "}]":
                last = len(chunks) - 1
                while last >= 0 and chunks[last].isspace():
                    last -= 1
                if last >= 0 and chunks[last] == ",":
                    del chunks[last]
            chunks.append(char)
            index += 1
    return json.loads("".join(chunks))


def sanitize_profile(profile: Path) -> None:
    document = parse_json5(profile.read_text(encoding="utf-8"))
    document["app"]["signingConfigs"] = []
    for product in document["app"]["products"]:
        product.pop("signingConfig", None)
    profile.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sanitize() -> None:
    require_ci()
    sanitize_profile(PROJECT / "ohos/build-profile.json5")
    print("Removed signing configuration from the disposable CI project copy.")


def unpack(archive: Path, output: Path) -> None:
    output.mkdir()
    if zipfile.is_zipfile(archive):
        links = []
        with zipfile.ZipFile(archive) as package:
            for member in package.infolist():
                relative = PurePosixPath(member.filename)
                if relative.is_absolute() or ".." in relative.parts or "\\" in member.filename:
                    raise RuntimeError("Tool archive contains an unsafe path.")
                target = output.joinpath(*relative.parts)
                mode = member.external_attr >> 16
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                elif mode & 0o170000 == 0o120000:
                    link = package.read(member).decode("utf-8")
                    if Path(link).is_absolute() or not (target.parent / link).resolve().is_relative_to(output.resolve()):
                        raise RuntimeError("Tool archive contains an unsafe symbolic link.")
                    links.append((target, link))
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with package.open(member) as source, target.open("wb") as sink:
                        shutil.copyfileobj(source, sink)
                    if mode & 0o777:
                        target.chmod(mode & 0o777)
        for target, link in links:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(link)
    elif tarfile.is_tarfile(archive):
        with tarfile.open(archive) as package:
            package.extractall(output, filter="data")
    else:
        raise RuntimeError("Command Line Tools must be a ZIP or TAR archive.")


def find_toolchain(root: Path) -> tuple[Path, dict[str, Path], dict]:
    candidates = []
    for metadata in root.rglob("sdk-pkg.json"):
        if len(metadata.relative_to(root).parts) > 6:
            continue
        sdk = metadata.parent
        if not (sdk / "openharmony/toolchains/hdc").is_file():
            continue
        data = json.loads(metadata.read_text(encoding="utf-8"))["data"]
        if int(str(data["apiVersion"]).split(".")[0]) < 24:
            continue
        sdk_root = sdk.parent
        tools_root = sdk_root.parent
        for name in ("tool", "tools"):
            tools = tools_root / name
            for commands in (tools_root, tools):
                executables = {
                    "node": tools / "node/bin/node",
                    "ohpm": commands / "ohpm/bin/ohpm",
                    "hvigor": commands / "hvigor/bin/hvigorw",
                }
                if all(path.is_file() for path in executables.values()):
                    if commands == tools_root:
                        wrappers = {"ohpm": tools_root / "bin/ohpm", "hvigor": tools_root / "bin/hvigorw"}
                        if all(path.is_file() for path in wrappers.values()):
                            executables.update(wrappers)
                    candidates.append((sdk_root, executables, data))
    if len(candidates) != 1:
        raise RuntimeError(
            "Expected one HarmonyOS SDK with API >= 24, tool/node or tools/node, "
            "and ohpm/bin/ohpm plus hvigor/bin/hvigorw in the archive root or tools directory. "
            "Use the complete official Linux x64 Command Line Tools archive."
        )
    return candidates[0]


def toolchain_source() -> dict:
    url = os.environ.get("OHOS_COMMAND_LINE_TOOLS_URL", "").strip()
    expected = os.environ.get("OHOS_COMMAND_LINE_TOOLS_SHA256", "").strip().lower()
    if bool(url) != bool(expected):
        raise RuntimeError(
            "Supply both OHOS_COMMAND_LINE_TOOLS_URL and OHOS_COMMAND_LINE_TOOLS_SHA256 "
            "to override the locked HarmonyOS toolchain."
        )
    source = {"url": url, "sha256": expected} if url else json.loads(
        (PROJECT / "tool/ci/ohos-command-line-tools.lock.json").read_text(encoding="utf-8")
    )
    url, expected = source["url"], source["sha256"]
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise RuntimeError("Command Line Tools URL must use HTTPS without embedded credentials.")
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise RuntimeError("Command Line Tools SHA-256 must contain exactly 64 hexadecimal digits.")
    return source


def bootstrap() -> None:
    temporary = require_ci()
    source_config = toolchain_source()
    url, expected = source_config["url"], source_config["sha256"]
    parsed = urllib.parse.urlsplit(url)
    archive = temporary / "ohos-command-line-tools.archive"
    print("Downloading the official HarmonyOS command line tools.")
    request = urllib.request.Request(url, headers={"User-Agent": "qfli-c-github-actions"})
    try:
        with urllib.request.urlopen(request, timeout=120) as source, archive.open("wb") as target:
            shutil.copyfileobj(source, target)
    except OSError as error:
        raise RuntimeError("Cannot download the Command Line Tools archive. Check the supplied URL and its expiry.") from error
    if sha256(archive) != expected:
        raise RuntimeError("Command Line Tools SHA-256 differs from the supplied digest.")
    unpack(archive, temporary / "ohos-command-line-tools")
    sdk, executables, metadata = find_toolchain(temporary / "ohos-command-line-tools")
    if "expectedApiVersion" in source_config and int(metadata["apiVersion"]) != source_config["expectedApiVersion"]:
        raise RuntimeError("HarmonyOS SDK API differs from the locked API version.")
    # The pinned Flutter OHOS release looks for tool/node on Linux. The official
    # setup guide also documents tools/node. Keep the extracted SDK untouched
    # except for this directory alias when the archive uses the latter layout.
    tools = executables["node"].parents[2]
    linux_tools = sdk.parent / "tool"
    if tools.name == "tools" and not linux_tools.exists():
        linux_tools.symlink_to(tools, target_is_directory=True)
    with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as env:
        env.write(f"DEVECO_SDK_HOME={sdk}\n")
        env.write(f"HOS_SDK_HOME={sdk}\n")
        env.write(f"DEVECO_NODE_HOME={executables['node'].parents[1]}\n")
    with Path(os.environ["GITHUB_PATH"]).open("a", encoding="utf-8") as paths:
        for directory in dict.fromkeys(path.parent for path in executables.values()):
            paths.write(f"{directory}\n")
    (temporary / "ohos-toolchain.json").write_text(json.dumps({
        "archiveSha256": expected,
        "archiveSize": archive.stat().st_size,
        "archiveSource": urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", "")),
        "archiveVersion": source_config.get("version"),
        "sourceReference": source_config.get("sourceReference"),
        "sdk": metadata,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Verified HarmonyOS SDK {metadata.get('version')} (API {metadata['apiVersion']}).")


def checksum_directory(directory: Path) -> None:
    lines = [f"{sha256(path)}  {path.relative_to(directory).as_posix()}"
             for path in sorted(directory.rglob("*")) if path.is_file() and path.name != "SHA256SUMS"]
    (directory / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")


def check_hap_names(names: list[str]) -> list[str]:
    """Check the entry names of one HAP and return the validation strings."""
    present = set(names)
    validation = []
    for required in HAP_REQUIRED:
        if required not in present:
            raise RuntimeError(f"HAP lacks the required entry {required}.")
        validation.append(f"contains {required}")
    for name in names:
        parts = name.split("/")
        if parts[0] == "libs" and len(parts) > 2 and parts[1] != HAP_ABI:
            raise RuntimeError(f"HAP holds the unexpected ABI directory libs/{parts[1]}/ (entry {name}).")
    validation.append(f"libs/ holds only {HAP_ABI}")
    return validation


def hap_contents(entries: list[zipfile.ZipInfo]) -> list[dict]:
    return [
        {"name": entry.filename, "size": entry.file_size}
        for entry in sorted(entries, key=lambda item: item.filename)
        if not entry.is_dir() and (
            (entry.filename.startswith("libs/") and entry.filename.endswith(".so"))
            or entry.filename.startswith(HAP_RESOURCE_PREFIX)
        )
    ]


def application_version(pubspec: Path) -> str:
    match = re.search(r"^version:\s*['\"]?([^\s'\"#]+)", pubspec.read_text(encoding="utf-8"), re.MULTILINE)
    if not match:
        raise RuntimeError("pubspec.yaml has no version line.")
    return match.group(1)


def read_json(path: Path, required: bool = True):
    if not required and not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def read_flutter_version(path: Path) -> dict:
    """Read the output of `flutter --version --machine`.

    A first-run notice can precede the JSON document.
    """
    text = path.read_text(encoding="utf-8")
    start = text.find("{")
    if start < 0:
        raise RuntimeError("Flutter version output holds no JSON document.")
    return json.JSONDecoder().raw_decode(text, start)[0]


def package() -> None:
    temporary = require_ci()
    hap = PROJECT / "build/ohos/hap/entry-default-unsigned.hap"
    app_archive = PROJECT / "build/ohos/app/ohos-default-unsigned.app"
    for source in (hap, app_archive):
        if not source.is_file():
            raise RuntimeError(f"Missing expected unsigned application output: {source.relative_to(PROJECT)}")
    output = PROJECT / "dist/app"
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise RuntimeError("Output directory dist/app already holds files.")

    validation = []
    with zipfile.ZipFile(hap) as archive:
        entries = archive.infolist()
        validation += [f"HAP {text}" for text in check_hap_names([entry.filename for entry in entries])]
        contents = hap_contents(entries)
    with zipfile.ZipFile(app_archive) as archive:
        nested = [entry for entry in archive.infolist() if entry.filename.endswith(".hap")]
        if not nested:
            raise RuntimeError("APP contains no nested HAP.")
        for entry in nested:
            with zipfile.ZipFile(io.BytesIO(archive.read(entry))) as inner:
                validation += [f"APP {entry.filename} {text}" for text in check_hap_names(inner.namelist())]

    packages = []
    for source, name in ((hap, HAP_OUTPUT), (app_archive, APP_OUTPUT)):
        target = output / name
        shutil.copy2(source, target)
        packages.append({"file": name, "sha256": sha256(target), "size": target.stat().st_size})
    (output / "hap-contents.json").write_text(json.dumps({"hap": contents}, indent=2) + "\n", encoding="utf-8")
    (output / "SIGNING.txt").write_text(SIGNING_NOTE, encoding="utf-8")
    evidence = {
        "applicationCommit": os.environ["GITHUB_SHA"],
        "repository": os.environ["GITHUB_REPOSITORY"],
        "runId": os.environ["GITHUB_RUN_ID"],
        "runUrl": f'{os.environ["GITHUB_SERVER_URL"]}/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}',
        "coreCommit": os.environ["CORE_REVISION"],
        "flutterCommit": os.environ["FLUTTER_OHOS_REVISION"],
        "flutterTag": os.environ["FLUTTER_OHOS_TAG"],
        "platform": "HarmonyOS",
        "architecture": HAP_ABI,
        "applicationVersion": application_version(PROJECT / "pubspec.yaml"),
        "signing": "unsigned",
        "nativeInput": read_json(temporary / "native-input.json", required=False),
        "toolchain": read_json(temporary / "ohos-toolchain.json"),
        "flutter": read_flutter_version(temporary / "ohos-flutter-version.json"),
        "packages": packages,
        "validation": validation,
        "deviceRuntimeVerified": False,
    }
    (output / "provenance.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    checksum_directory(output)
    print(f"Packaged {HAP_OUTPUT} and {APP_OUTPUT} in dist/app.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("sanitize", "bootstrap", "package"))
    args = parser.parse_args()
    try:
        {"sanitize": sanitize, "bootstrap": bootstrap, "package": package}[args.command]()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"OHOS {args.command} failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
