"""Validate OHOS packaged artifacts; optional host cross-linking never runs them.

Windows artifact check:
  python native/toolchain/verify-ohos-package.py --project-root . --hap <signed.hap>
Linux/WSL cross-link check with Clang 15:
  python3 native/toolchain/verify-ohos-package.py --project-root . \
    --validation-compiler /usr/bin/clang-15 --validation-linker /usr/bin/ld.lld
"""

import argparse
import hashlib
import io
import json
import pathlib
import struct
import subprocess
import tempfile
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect_elf(data, machine, executable, name):
    require(data[:6] == b"\x7fELF\x02\x01", f"Not ELF64 little endian: {name}")
    header = struct.unpack_from("<HHIQQQIHHHHHH", data, 16)
    require(header[0] == 3 and header[1] == machine, f"Wrong ELF type/ABI: {name}")
    programs = [struct.unpack_from("<IIQQQQQQ", data, header[4] + i * header[8])
                for i in range(header[9])]
    loads = [p for p in programs if p[0] == 1]
    require(loads, f"Missing ELF LOAD segments: {name}")
    interpreter = [p for p in programs if p[0] == 3]
    if executable:
        expected = b"/lib/ld-musl-aarch64.so.1\0" if machine == 183 else b"/lib/ld-musl-x86_64.so.1\0"
        require(len(interpreter) == 1, f"Missing ELF interpreter: {name}")
        p = interpreter[0]
        require(data[p[2]:p[2] + p[5]] == expected, f"Wrong OHOS interpreter: {name}")
        require(header[3] != 0, f"Missing executable entry point: {name}")
    dynamics = [p for p in programs if p[0] == 2]
    require(len(dynamics) == 1, f"Missing ELF dynamic section: {name}")
    p = dynamics[0]
    tags = [struct.unpack_from("<qQ", data, p[2] + i) for i in range(0, p[5], 16)]
    string_address = next(value for tag, value in tags if tag == 5)
    segment = next(p for p in loads if p[3] <= string_address < p[3] + p[5])
    string_offset = segment[2] + string_address - segment[3]
    needed = []
    for tag, value in tags:
        if tag == 1:
            start = string_offset + value
            needed.append(data[start:data.index(b"\0", start)].decode())
    require(set(needed) <= {"libc.so", "libc++_shared.so"}, f"Unexpected dependencies {needed}: {name}")
    return {"neededLibraries": needed, "minimumLoadAlignment": min(p[7] for p in loads)}


def validate_resources(archive):
    names = archive.namelist()
    require(len(names) == len(set(names)), "Duplicate ZIP entries")
    for name in names:
        path = pathlib.PurePosixPath(name)
        require("\\" not in name and not path.is_absolute() and ".." not in path.parts
                and ":" not in name, f"Unsafe/nonportable ZIP path: {name}")
    manifest = json.loads(archive.read("toolchain.json"))
    require(manifest["llvmVersion"] == "15.0.7", "Wrong LLVM version")
    require(manifest["llvmCommit"] == "8dfdcc7b7bf66834a761bd8de445840ef68e4d1a", "Wrong LLVM source pin")
    require(manifest.get("installedNativeExecutables") is True, "Compiler must be installed as native code")
    require(manifest["compiler"] == "libqfli_clang.so" and manifest["linker"] == "libqfli-ld.lld-.so"
            and manifest["executor"] == "libqfli_executor.so", "Native file names differ from bridge contract")
    require("bin/clang" not in names and "bin/ld.lld" not in names, "Writable resource ZIP contains executables")
    triple = manifest["targetTriple"]
    cpu = "aarch64" if manifest["architecture"] == "arm64-v8a" else "x86_64"
    require(triple == f"{cpu}-unknown-linux-ohos", "Manifest ABI/triple mismatch")
    for name in ("bin/ohos.cfg", "sysroot/usr/include/stdio.h", "include/c++/v1/vector",
                 "include/c++/v1/stdexcept", "lib/clang/15.0.7/include/stddef.h",
                 f"lib/clang/15.0.7/lib/{triple}/libclang_rt.builtins.a",
                 f"lib/clang/15.0.7/lib/{triple}/clang_rt.crtbegin.o",
                 f"lib/clang/15.0.7/lib/{triple}/clang_rt.crtend.o",
                 f"sysroot/usr/lib/{cpu}-linux-ohos/libc.so",
                 f"lib/{triple}/libc++.so", f"lib/{triple}/libunwind.a"):
        require(name in names, f"Missing compiler resource: {name}")
    config = archive.read("bin/ohos.cfg").decode()
    for token in (f"--target={triple}", "-D__OHOS__=1", "-D__OHOS_FAMILY__=1",
                  "-D__MUSL__=1", "<CFGDIR>/../sysroot", "<CFGDIR>/../include/c++/v1"):
        require(token in config, f"Missing portable compiler configuration: {token}")
    return manifest


def validate_native(manifest, read_native):
    machine = 183 if manifest["architecture"] == "arm64-v8a" else 62
    report = {}
    for name, field, executable in (
        (manifest["compiler"], "compilerMetadata", True),
        (manifest["linker"], "linkerMetadata", True),
        (manifest["executor"], "executorMetadata", True),
        ("libc++_shared.so", "runtimeMetadata", False),
    ):
        data = read_native(name)
        require(hashlib.sha256(data).hexdigest() == manifest[field]["sha256"],
                f"Packaged native file differs from manifest: {name}")
        report[name] = inspect_elf(data, machine, executable, name)
    return report


def cross_link(archive, compiler, linker):
    version = subprocess.check_output([compiler, "--version"], text=True).splitlines()[0]
    require("15.0.7" in version, f"Validation must use Clang 15.0.7: {version}")
    linker_version = subprocess.check_output([linker, "--version"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="qfli-ohos-link-") as temp:
        root = pathlib.Path(temp)
        resources = root / "resources with spaces"
        archive.extractall(resources)  # Every path was validated before extraction.
        project = root / "mixed project"
        project.mkdir()
        (project / "include").mkdir()
        (project / "include/answer.h").write_text(
            '#ifdef __cplusplus\nextern "C" {\n#endif\nint answer(void);\n'
            '#ifdef __cplusplus\n}\n#endif\n')
        (project / "main.c").write_text(
            '#include <stdio.h>\n#include "answer.h"\n'
            'int main(void) { int n[3] = {[2] = 42}; printf("%d %d\\n", n[2], answer()); return 7; }\n')
        (project / "helper.cpp").write_text(
            '#include "answer.h"\n#include <vector>\n#include <stdexcept>\n#include <span>\n#include <atomic>\n'
            'int answer() { try { throw std::runtime_error("ok"); } catch (const std::exception&) { '
            'std::vector<int> v{42}; std::atomic<unsigned __int128> a{0}; '
            'a.store(std::span<int>(v).front()); return static_cast<int>(a.load()); } }\n')
        (project / "plain.c").write_text(
            '#include <stdio.h>\n#include <math.h>\n#include <stdatomic.h>\n'
            'int main(int argc, char **argv) { _Atomic int n = 1; atomic_fetch_add(&n, argc); '
            'printf("%f\\n", sin((double)n)); return argv == 0; }\n')
        (project / "cpp.cpp").write_text(
            '#include <iostream>\n#include <vector>\n#include <stdexcept>\n'
            'int main() { try { throw std::runtime_error("42"); } '
            'catch (const std::exception& e) { std::cout << e.what() << std::vector<int>{42}[0]; } }\n')
        common = [compiler, "--config", str(resources / "bin/ohos.cfg"), f"--ld-path={linker}",
                  "-Wno-unused-command-line-argument", "-I", str(project / "include")]
        objects = {}
        for name in ("main.c", "helper.cpp", "plain.c", "cpp.cpp"):
            cpp = name.endswith(".cpp")
            output = project / (name + ".o")
            command = common + (["--driver-mode=g++"] if cpp else [])
            subprocess.run(command + ["-std=c++20" if cpp else "-std=c17", "-fPIC", "-c",
                                      str(project / name), "-o", str(output)], check=True)
            objects[name] = str(output)
        machine = 183 if archive.read("toolchain.json").find(b"arm64-v8a") >= 0 else 62
        for name, units, cpp in (("c17", ["plain.c"], False), ("cpp20", ["cpp.cpp"], True),
                                 ("mixed-exceptions", ["main.c", "helper.cpp"], True)):
            output = project / (name + ".so")
            command = common + (["--driver-mode=g++"] if cpp else [])
            subprocess.run(command + ["-shared", "-Wl,-z,defs",
                                      "-Wl,-z,max-page-size=16384,-z,common-page-size=16384"]
                           + [objects[unit] for unit in units] + ["-lm", "-o", str(output)], check=True)
            info = inspect_elf(output.read_bytes(), machine, False, name)
            require(info["minimumLoadAlignment"] >= 16384, f"Generated output is not 16 KiB aligned: {name}")
            print(f"PASS cross-link: {name}, dependencies {info['neededLibraries']}")
        # A real unresolved symbol must fail under the same bridge linker flags.
        failed = subprocess.run(common + ["-shared", "-Wl,-z,defs", objects["main.c"],
                                           "-lm", "-o", str(project / "invalid.so")],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        require(failed.returncode != 0 and "answer" in failed.stderr, "Undefined-symbol failure gate did not fail")
        print("PASS cross-link: unresolved symbol rejected")
    return {"compiler": version, "linker": linker_version, "executionVerified": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=pathlib.Path, default=pathlib.Path("."))
    parser.add_argument("--architecture", choices=("arm64-v8a", "x86_64"), default="arm64-v8a")
    parser.add_argument("--hap", type=pathlib.Path)
    parser.add_argument("--validation-compiler")
    parser.add_argument("--validation-linker")
    args = parser.parse_args()
    archive_path = args.project_root / f"ohos/entry/src/main/resources/rawfile/qfli_toolchain/ohos-{args.architecture}.zip"
    archive_bytes = archive_path.read_bytes()
    archive_hash = hashlib.sha256(archive_bytes).hexdigest()
    require(archive_path.with_suffix(".zip.sha256").read_text().strip() == archive_hash, "Resource ZIP SHA256 mismatch")
    native = args.project_root / f"ohos/entry/libs/{args.architecture}"
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        manifest = validate_resources(archive)
        require(manifest["architecture"] == args.architecture, "Resource ABI differs from requested ABI")
        report = {"resourceSha256": archive_hash, "resourceEntries": len(archive.namelist()),
                  "native": validate_native(manifest, lambda name: (native / name).read_bytes()),
                  "appExecutionVerified": False}
        runtime = archive.read(f"lib/{manifest['targetTriple']}/libc++_shared.so")
        require(hashlib.sha256(runtime).hexdigest() == manifest["runtimeMetadata"]["sha256"], "Link/runtime libc++ mismatch")
        if args.hap:
            with zipfile.ZipFile(args.hap) as hap:
                entry = hap.getinfo(f"resources/rawfile/qfli_toolchain/ohos-{args.architecture}.zip")
                require(entry.compress_type == zipfile.ZIP_STORED, "Resource ZIP must be stored for getRawFd streaming")
                require(hashlib.sha256(hap.read(entry)).hexdigest() == archive_hash, "HAP contains a stale resource ZIP")
                report["hapNative"] = validate_native(manifest, lambda name: hap.read(f"libs/{args.architecture}/{name}"))
        if args.validation_compiler or args.validation_linker:
            require(args.validation_compiler and args.validation_linker, "Specify both validation compiler and linker")
            report["crossLink"] = cross_link(archive, args.validation_compiler, args.validation_linker)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
