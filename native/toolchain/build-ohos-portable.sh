#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

usage() {
  cat <<'USAGE'
Usage: bash native/toolchain/build-ohos-portable.sh --ohos-resources PATH [options]
  --ohos-resources PATH  ARM64 package-llvm.ps1 resources (LLVM 15.0.7/OHOS SDK)
  --build-root PATH      Build directory (default: native/build/ohos-portable)
  --downloads PATH       Pinned dependency archives (default: native/build/portable-deps)
  --host-tools PATH      Existing LLVM 22.1.0 TableGen bin directory
  --jobs N               Parallel compiler jobs (default: 6)
  --configure-only       Verify inputs and configure without building target libraries
  --help                Show this help

Run on Linux or WSL with Clang 15, LLVM ar/ranlib, CMake, Make, Python and Git.
The output contains signed-app link inputs; it does not enable native execution
or JIT. WASI resource packaging is handled by package-ohos-portable.ps1.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_root="$repo_root/native/build/ohos-portable"
downloads="$repo_root/native/build/portable-deps"
resources=""
host_bin=""
jobs=6
configure_only=0
while (($#)); do
  case "$1" in
    --ohos-resources|--build-root|--downloads|--host-tools|--jobs)
      (($# >= 2)) || { usage >&2; exit 2; }
      case "$1" in
        --ohos-resources) resources="$2" ;;
        --build-root) build_root="$2" ;;
        --downloads) downloads="$2" ;;
        --host-tools) host_bin="$2" ;;
        --jobs) jobs="$2" ;;
      esac
      shift 2 ;;
    --configure-only) configure_only=1; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$resources" && "$jobs" =~ ^[1-9][0-9]*$ ]] || { usage >&2; exit 2; }
[[ "$(uname -s)" == Linux ]] || { echo 'Use Linux or WSL for this cross build.' >&2; exit 1; }
for tool in cmake make python3 git clang-15 clang++-15 llvm-ar-18 llvm-ranlib-18 llvm-nm-18 llvm-readobj-18 ld.lld tar; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
mkdir -p "$build_root"
build_root="$(cd "$build_root" && pwd)"
resources="$(cd "$resources" && pwd)"
downloads="$(cd "$downloads" && pwd)"
manifest="$repo_root/native/toolchain/portable-dependencies.json"

# Extract our own source trees from checksum-verified archives. Never patch a
# caller's dependency directory or silently accept subsequent source edits.
python3 - "$manifest" "$downloads" "$build_root" "$resources" "$repo_root" <<'PY'
import hashlib, json, pathlib, subprocess, sys
manifest, downloads, build, resources, repo = map(pathlib.Path, sys.argv[1:])
deps = json.loads(manifest.read_text())
sdk = json.loads((resources / 'toolchain.json').read_text())
if sdk.get('llvmVersion') != '15.0.7' or sdk.get('targetTriple') != 'aarch64-unknown-linux-ohos':
    raise SystemExit('Expected the pinned ARM64 OHOS LLVM 15.0.7 resource layout')
for name, record in [('bin/clang', 'compilerMetadata'), ('bin/ld.lld', 'linkerMetadata'),
                     ('lib/aarch64-unknown-linux-ohos/libc++_shared.so', 'runtimeMetadata')]:
    if hashlib.sha256((resources / name).read_bytes()).hexdigest() != sdk[record]['sha256']:
        raise SystemExit('OHOS resource manifest hash mismatch: ' + name)
for name in ('bin/ohos.cfg', 'sysroot/usr/include/stdio.h', 'include/c++/v1/vector',
             'lib/clang/15.0.7/lib/aarch64-unknown-linux-ohos/libclang_rt.builtins.a'):
    if not (resources / name).is_file():
        raise SystemExit('Missing OHOS SDK resource: ' + name)

def digest_tree(root):
    digest = hashlib.sha256()
    for path in sorted(root.rglob('*')):
        digest.update(str(path.relative_to(root)).encode() + b'\0')
        if path.is_symlink(): digest.update(b'L' + str(path.readlink()).encode())
        elif path.is_file():
            digest.update(b'F')
            with path.open('rb') as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b''): digest.update(chunk)
        else: digest.update(b'D')
    return digest.hexdigest()

sources = build / 'sources'
sources.mkdir(exist_ok=True)
for key in ('llvm22', 'wasmedge', 'fmt', 'spdlog'):
    item = deps[key]
    archive = downloads / item['archive']
    print('Verifying dependency archive: ' + str(archive), flush=True)
    digest = hashlib.sha256()
    with archive.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''): digest.update(chunk)
    if digest.hexdigest() != item['sha256']: raise SystemExit('Archive SHA256 mismatch: ' + str(archive))
    directory = sources / item['directory']
    marker = sources / (key + '.tree-sha256')
    if directory.exists():
        if not marker.is_file() or marker.read_text().strip() != digest_tree(directory):
            raise SystemExit('Source tree changed; choose another build root: ' + str(directory))
        if key != 'wasmedge':
            continue
    else:
        print('Extracting isolated ' + key + ' source tree', flush=True)
        extract = ['tar', '-xf', str(archive), '-C', str(sources)]
        if key == 'llvm22':
            # LLVM's archive also contains unrelated projects and 100,000+ test
            # fixtures. Retain the compiler/linker sources used by this build.
            extract += ['--exclude=*/test/*', '--exclude=*/tests/*', '--exclude=*/unittests/*',
                        '--exclude=*/utils/gn/*']
            extract += [item['directory'] + '/' + name for name in
                        ('llvm', 'clang', 'lld', 'cmake', 'third-party', 'runtimes', 'LICENSE.TXT')]
        subprocess.run(extract, check=True)
    if not directory.is_dir(): raise SystemExit('Unexpected archive source layout: ' + str(directory))
    if key == 'wasmedge':
        subprocess.run(['cmake', '-DQFLI_WASMEDGE_SOURCE=' + str(directory), '-P',
                        str(repo / 'native/portable/apply-wasmedge-patch.cmake')], check=True)
        patch = repo / 'native/portable/patches/wasmedge-ohos-musl.patch'
        if hashlib.sha256(patch.read_bytes()).hexdigest() != 'df211977a22e3060890b3c8fddd60b497dde3cf1625054d842941afd0ba34f5e':
            raise SystemExit('OHOS musl patch SHA256 mismatch')
        env = dict(__import__('os').environ, GIT_CEILING_DIRECTORIES=str(directory.parent))
        applied = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch)],
                                 cwd=directory, env=env, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL).returncode == 0
        if not applied:
            subprocess.run(['git', 'apply', '--check', str(patch)], cwd=directory, env=env, check=True)
            subprocess.run(['git', 'apply', str(patch)], cwd=directory, env=env, check=True)
    marker.write_text(digest_tree(directory) + '\n')
snapshot = {'dependencies': deps, 'ohosResources': str(resources), 'ohosManifest': sdk,
            'ohosResourcesSha256': digest_tree(resources),
            'sourceDigests': {k: (sources / (k + '.tree-sha256')).read_text().strip()
                              for k in ('llvm22', 'wasmedge', 'fmt', 'spdlog')}}
(build / 'verified-inputs.json').write_text(json.dumps(snapshot, indent=2) + '\n')
PY

dependency_dir() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["directory"])' "$manifest" "$1"
}
llvm_source="$build_root/sources/$(dependency_dir llvm22)"
wasmedge_source="$build_root/sources/$(dependency_dir wasmedge)"
fmt_source="$build_root/sources/$(dependency_dir fmt)"
spdlog_source="$build_root/sources/$(dependency_dir spdlog)"
if [[ -z "$host_bin" ]]; then
  cmake -S "$repo_root/native/compiler" -B "$build_root/host" -G 'Unix Makefiles' \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-15 -DCMAKE_CXX_COMPILER=clang++-15 \
    -DFETCHCONTENT_SOURCE_DIR_LLVM22="$llvm_source" -DQFLI_BUILD_COMPILER_TESTS=OFF
  cmake --build "$build_root/host" --target llvm-tblgen llvm-min-tblgen clang-tblgen --parallel "$jobs"
  host_bin="$build_root/host/_deps/llvm22-build/bin"
fi
host_bin="$(cd "$host_bin" && pwd)"
for tool in llvm-tblgen llvm-min-tblgen clang-tblgen; do
  [[ -x "$host_bin/$tool" ]] || { echo "Missing LLVM 22 host tool: $host_bin/$tool" >&2; exit 1; }
  "$host_bin/$tool" --version | python3 -c 'import sys; s=sys.stdin.read(); print(s,end=""); assert "22.1.0" in s'
done

# Host Clang emits OHOS ABI code using only the pinned SDK's headers, runtime
# and compiler-rt. Native LLVM 22 TableGen tools run on the Linux build host.
python3 - "$build_root/ohos-toolchain.cmake" "$resources" <<'PY'
import pathlib, sys
output, resources = map(pathlib.Path, sys.argv[1:])
def quoted(value): return '"' + str(value).replace('\\','\\\\').replace('"','\\"').replace('$','\\$') + '"'
flags = '--config "' + str(resources / 'bin/ohos.cfg') + '" -Qunused-arguments'
entries = {'CMAKE_SYSTEM_NAME': 'Linux', 'CMAKE_SYSTEM_PROCESSOR': 'aarch64',
           'CMAKE_C_COMPILER': '/usr/bin/clang-15', 'CMAKE_CXX_COMPILER': '/usr/bin/clang++-15',
           'CMAKE_C_COMPILER_TARGET': 'aarch64-unknown-linux-ohos',
           'CMAKE_CXX_COMPILER_TARGET': 'aarch64-unknown-linux-ohos',
           'CMAKE_AR': '/usr/bin/llvm-ar-18', 'CMAKE_RANLIB': '/usr/bin/llvm-ranlib-18',
           'CMAKE_SYSROOT': resources / 'sysroot', 'CMAKE_C_FLAGS_INIT': flags,
           'CMAKE_CXX_FLAGS_INIT': flags + ' -nostdinc++',
           'CMAKE_EXE_LINKER_FLAGS_INIT': '--ld-path=/usr/bin/ld.lld',
           'CMAKE_SHARED_LINKER_FLAGS_INIT': '--ld-path=/usr/bin/ld.lld',
           'CMAKE_FIND_ROOT_PATH': resources, 'CMAKE_FIND_ROOT_PATH_MODE_PROGRAM': 'NEVER',
           'CMAKE_FIND_ROOT_PATH_MODE_LIBRARY': 'ONLY', 'CMAKE_FIND_ROOT_PATH_MODE_INCLUDE': 'ONLY',
           'CMAKE_FIND_ROOT_PATH_MODE_PACKAGE': 'ONLY'}
output.write_text(''.join('set(' + key + ' ' + quoted(value) + ')\n' for key,value in entries.items()))
for name in ('compiler', 'runtime'):
    cache = output.parent / name / 'CMakeCache.txt'
    if not cache.is_file(): continue
    entries = dict(line.split('=', 1) for line in cache.read_text().splitlines()
                   if '=' in line and not line.startswith(('#', '//')))
    toolchain = next((value for key, value in entries.items() if key.startswith('CMAKE_TOOLCHAIN_FILE:')), '')
    if not toolchain or pathlib.Path(toolchain).resolve() != output.resolve():
        raise SystemExit('Existing target cache uses another toolchain; choose another build root: ' + str(cache))
    for key in ('CMAKE_C_FLAGS:STRING', 'CMAKE_CXX_FLAGS:STRING'):
        if str(resources / 'bin/ohos.cfg') not in entries.get(key, ''):
            raise SystemExit('Existing target cache uses another OHOS SDK: ' + str(cache))
PY
common=(-G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        "-DCMAKE_TOOLCHAIN_FILE=$build_root/ohos-toolchain.cmake")
cmake -S "$repo_root/native/compiler" -B "$build_root/compiler" "${common[@]}" \
  -DFETCHCONTENT_SOURCE_DIR_LLVM22="$llvm_source" \
  -DLLVM_TABLEGEN="$host_bin/llvm-tblgen" -DLLVM_MIN_TBLGEN="$host_bin/llvm-min-tblgen" \
  -DCLANG_TABLEGEN="$host_bin/clang-tblgen" -DLLVM_NATIVE_TOOL_DIR="$host_bin" \
  -DLLVM_HOST_TRIPLE=aarch64-unknown-linux-ohos -DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-unknown-wasip1 \
  -DLLVM_ENABLE_BACKTRACES=OFF -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=OFF -DLLVM_LINK_LLVM_DYLIB=OFF -DQFLI_BUILD_COMPILER_TESTS=OFF
cmake -S "$repo_root/native/portable" -B "$build_root/runtime" "${common[@]}" \
  -DFETCHCONTENT_SOURCE_DIR_WASMEDGE="$wasmedge_source" \
  -DFETCHCONTENT_SOURCE_DIR_FMT="$fmt_source" -DFETCHCONTENT_SOURCE_DIR_SPDLOG="$spdlog_source" \
  -DCMAKE_DISABLE_FIND_PACKAGE_fmt=ON -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
  -DWASMEDGE_USE_LLVM=OFF -DQFLI_BUILD_WASM_TESTS=OFF
if ((configure_only)); then exit 0; fi
cmake --build "$build_root/compiler" --target qfli_compiler --parallel "$jobs"
cmake --build "$build_root/runtime" --target qfli_wasm --parallel "$jobs"

python3 - "$build_root" "$repo_root" "$host_bin" <<'PY'
import hashlib, json, pathlib, shutil, subprocess, sys
build, repo, host = map(pathlib.Path, sys.argv[1:])
package = build / 'package'
libs = package / 'lib/arm64-v8a'
libs.mkdir(parents=True, exist_ok=True)
(package / 'include').mkdir(exist_ok=True)
for name, paths in {
    'compiler': [build / 'compiler/libqfli_compiler.a'] + sorted((build / 'compiler/_deps/llvm22-build/lib').glob('*.a')),
    'wasm': [build / 'runtime/libqfli_wasm.a', build / 'runtime/_deps/wasmedge-build/lib/api/libwasmedge.a']
}.items():
    if not all(path.is_file() for path in paths): raise SystemExit('Missing ' + name + ' static libraries')
    output = libs / ('libqfli_' + name + '.a')
    pending = output.with_suffix('.a.pending')
    # MRI retains identically named members from different LLVM libraries.
    script = 'CREATE "' + str(pending) + '"\n'
    script += ''.join('ADDLIB "' + str(path) + '"\n' for path in paths) + 'SAVE\nEND\n'
    subprocess.run(['llvm-ar-18', '-M'], input=script, text=True, check=True)
    subprocess.run(['llvm-ranlib-18', str(pending)], check=True)
    symbols = subprocess.check_output(['llvm-nm-18', '-g', '--defined-only', str(pending)], text=True)
    for suffix in ('create', 'compile', 'set_threads', 'cancel', 'destroy') if name == 'compiler' else ('create', 'run', 'error', 'cancel', 'destroy'):
        if ' T qfli_' + name + '_' + suffix + '\n' not in symbols:
            raise SystemExit('Missing exported C ABI symbol: ' + name + '_' + suffix)
    headers = subprocess.check_output(['llvm-readobj-18', '--file-headers', str(pending)], text=True)
    architectures = {line for line in headers.splitlines() if line.startswith('Arch:')}
    if architectures != {'Arch: aarch64'}:
        raise SystemExit('Package contains an unexpected object architecture: ' + str(architectures))
    pending.replace(output)
    print(str(output) + ': ' + str(output.stat().st_size) + ' bytes')
for source in ('native/compiler/include/qfli_compiler.h', 'native/portable/include/qfli_wasm.h'):
    shutil.copyfile(repo / source, package / 'include' / pathlib.Path(source).name)
metadata = json.loads((build / 'verified-inputs.json').read_text())
metadata.update({'architecture': 'arm64-v8a', 'target': 'wasm32-unknown-wasip1',
                 'execution': 'wasmedge-interpreter', 'jit': False,
                 'adapterSources': {source: hashlib.sha256((repo / source).read_bytes()).hexdigest()
                                    for source in ('native/compiler/compiler.cpp', 'native/portable/wasm_runtime.cpp')},
                 'runtimePatches': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in sorted((repo / 'native/portable/patches').glob('*.patch'))},
                 'hostTools': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (host / 'llvm-tblgen', host / 'llvm-min-tblgen', host / 'clang-tblgen')},
                 'libraries': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in libs.glob('*.a')}})
(package / 'build-manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
PY
printf 'OHOS portable static package: %s/package\n' "$build_root"
