#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash native/toolchain/build-android-llvm-linux.sh --ndk PATH [options]
  --ndk PATH         Android NDK 27.0.12077973 directory
  --abi ABI          arm64-v8a (default) or x86_64
  --jobs N           Parallel compiler jobs, 1-32 (default: 2)
  --build-root PATH  Build directory (default: native/build/android-linux-ABI)
  --source PATH      Reuse a clean LLVM 15.0.7 checkout, or clone to this path
  --help             Show this help

Requires Linux x86_64, Clang 15, CMake, Ninja, Git, Python 3 and PowerShell 7.
Builds the compiler/linker and packages validated Android native inputs under
BUILD_ROOT/package. It does not build an APK or execute an Android device.
USAGE
}

fail() { printf '%s\n' "$*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
abi=arm64-v8a
jobs=2
build_root=""
source=""
ndk=""
llvm_tag=llvmorg-15.0.7
llvm_commit=8dfdcc7b7bf66834a761bd8de445840ef68e4d1a
ndk_version=27.0.12077973
api=21

while (($#)); do
  case "$1" in
    --ndk|--abi|--jobs|--build-root|--source)
      (($# >= 2)) || { usage >&2; exit 2; }
      case "$1" in
        --ndk) ndk="$2" ;;
        --abi) abi="$2" ;;
        --jobs) jobs="$2" ;;
        --build-root) build_root="$2" ;;
        --source) source="$2" ;;
      esac
      shift 2 ;;
    --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ "$abi" == arm64-v8a || "$abi" == x86_64 ]] || fail 'ABI must be arm64-v8a or x86_64'
[[ "$jobs" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]] || fail 'Jobs must be an integer from 1 to 32'
[[ -n "$ndk" ]] || { usage >&2; exit 2; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail 'Use a Linux x86_64 host'
for tool in cmake ninja git python3 pwsh; do
  command -v "$tool" >/dev/null || fail "Missing build tool: $tool"
done
for tool in /usr/bin/clang-15 /usr/bin/clang++-15; do
  [[ -x "$tool" ]] || fail "Missing build tool: $tool"
done
[[ -d "$ndk" ]] || fail "Missing NDK directory: $ndk"
ndk="$(cd "$ndk" && pwd)"
toolchain="$ndk/build/cmake/android.toolchain.cmake"
[[ -f "$toolchain" ]] || fail "Missing NDK toolchain: $toolchain"
python3 - "$ndk/source.properties" "$ndk_version" <<'PY'
import pathlib, re, sys
properties = pathlib.Path(sys.argv[1]).read_text()
revision = re.search(r'^Pkg.Revision\s*=\s*(\S+)\s*$', properties, re.M)
if revision is None or revision[1] != sys.argv[2]:
    raise SystemExit('NDK revision must be ' + sys.argv[2])
PY

build_root="${build_root:-$repo_root/native/build/android-linux-$abi}"
mkdir -p "$build_root"
build_root="$(cd "$build_root" && pwd)"
source="${source:-$build_root/llvm-project}"
if [[ ! -e "$source" ]]; then
  mkdir -p "$(dirname "$source")"
  git clone --depth 1 --single-branch --branch "$llvm_tag" \
    https://github.com/llvm/llvm-project.git "$source"
fi
[[ -d "$source" ]] || fail "Source is not a directory: $source"
source="$(cd "$source" && pwd)"
head="$(git -C "$source" rev-parse HEAD)"
[[ "$head" == "$llvm_commit" ]] || fail "LLVM source must be $llvm_tag at $llvm_commit (found $head)"
git -C "$source" diff --quiet HEAD -- || fail "LLVM source has tracked changes: $source"

host="$build_root/host"
target="$build_root/target-$abi"
package="$build_root/package"
for path in "$package/resources/$abi" "$package/jniLibs/$abi" "$package/assets/qfli_toolchain/$abi.zip"; do
  [[ ! -e "$path" ]] || fail "Package output exists; choose another build root: $path"
done

# Reject stale caches before CMake can silently mix sources, SDKs or ABIs.
verify_cache() {
  local cache="$1"
  shift
  [[ ! -f "$cache" ]] || python3 - "$cache" "$@" <<'PY'
import pathlib, sys
cache = pathlib.Path(sys.argv[1])
values = {}
for line in cache.read_text().splitlines():
    if '=' in line and not line.startswith(('#', '//')):
        key, value = line.split('=', 1)
        values[key.split(':', 1)[0]] = value
for item in sys.argv[2:]:
    key, expected = item.split('=', 1)
    actual = values.get(key)
    if key in ('CMAKE_HOME_DIRECTORY', 'CMAKE_TOOLCHAIN_FILE', 'CMAKE_C_COMPILER', 'CMAKE_CXX_COMPILER'):
        matches = actual is not None and pathlib.Path(actual).resolve() == pathlib.Path(expected).resolve()
    else:
        matches = actual == expected
    if not matches:
        raise SystemExit(f'{cache}: expected {key}={expected}, found {actual!r}; choose another build root')
PY
}
verify_cache "$host/CMakeCache.txt" "CMAKE_HOME_DIRECTORY=$source/llvm" \
  'CMAKE_C_COMPILER=/usr/bin/clang-15' 'CMAKE_CXX_COMPILER=/usr/bin/clang++-15'
verify_cache "$target/CMakeCache.txt" "CMAKE_HOME_DIRECTORY=$source/llvm" \
  "ANDROID_ABI=$abi" "ANDROID_PLATFORM=android-$api" "CMAKE_TOOLCHAIN_FILE=$toolchain"

common=(
  -G Ninja -DCMAKE_BUILD_TYPE=Release
  '-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG' '-DCMAKE_CXX_FLAGS_RELEASE=-O2 -DNDEBUG'
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF
  -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_ASSERTIONS=OFF
  -DLLVM_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_DOCS=OFF -DLLVM_PARALLEL_LINK_JOBS=1
)
# Modern host standard-library headers require this include for LLVM 15.
# A compiler flag preserves the pinned upstream checkout unchanged.
cmake -S "$source/llvm" -B "$host" "${common[@]}" \
  -DCMAKE_C_COMPILER=/usr/bin/clang-15 -DCMAKE_CXX_COMPILER=/usr/bin/clang++-15 \
  '-DCMAKE_CXX_FLAGS=-include cstdint' -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD=X86
cmake --build "$host" --target llvm-tblgen clang-tblgen --parallel "$jobs"
for name in llvm-tblgen clang-tblgen; do
  [[ -x "$host/bin/$name" ]] || fail "Missing host TableGen tool: $host/bin/$name"
  "$host/bin/$name" --version | python3 -c '
import re, sys
version = sys.stdin.read()
print(version, end="")
if not re.search(r"LLVM version 15\.0\.7(?:\r?\n|$)", version):
    raise SystemExit("Host TableGen must report LLVM 15.0.7")'
done

if [[ "$abi" == arm64-v8a ]]; then backend=AArch64; triple=aarch64-linux-android;
else backend=X86; triple=x86_64-linux-android; fi
cmake -S "$source/llvm" -B "$target" "${common[@]}" \
  "-DCMAKE_TOOLCHAIN_FILE=$toolchain" "-DANDROID_ABI=$abi" "-DANDROID_PLATFORM=android-$api" \
  -DANDROID_STL=c++_static -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
  '-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=16384,-z,common-page-size=16384' \
  '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384,-z,common-page-size=16384' \
  '-DLLVM_ENABLE_PROJECTS=clang;lld' "-DLLVM_TARGETS_TO_BUILD=$backend" \
  "-DLLVM_HOST_TRIPLE=$triple" "-DLLVM_DEFAULT_TARGET_TRIPLE=$triple$api" \
  "-DLLVM_TABLEGEN=$host/bin/llvm-tblgen" "-DCLANG_TABLEGEN=$host/bin/clang-tblgen" \
  -DLLVM_ENABLE_PIC=ON -DCLANG_ENABLE_STATIC_ANALYZER=OFF -DCLANG_ENABLE_ARCMT=OFF
verify_cache "$target/CMakeCache.txt" 'CMAKE_PROJECT_VERSION=15.0.7' \
  'C_SUPPORTS_FPIC=1' 'CXX_SUPPORTS_FPIC=1' 'LLVM_ENABLE_PROJECTS=clang;lld'
cmake --build "$target" --target clang-resource-headers --parallel "$jobs"
cmake --build "$target" --target clang lld --parallel "$jobs"
git -C "$source" diff --quiet HEAD -- || fail "Build changed the pinned LLVM source: $source"

pwsh -NoLogo -NoProfile -File "$repo_root/native/toolchain/package-android-llvm.ps1" \
  -NdkDirectory "$ndk" -NdkVersion "$ndk_version" -TargetBuildDirectory "$target" \
  -TargetArchitecture "$abi" -ApiLevel "$api" -SourceDirectory "$source" \
  -OutputDirectory "$package" -ValidationCompiler /usr/bin/clang-15
printf 'Android %s native package: %s\n' "$abi" "$package"
