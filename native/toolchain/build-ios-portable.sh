#!/bin/bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash native/toolchain/build-ios-portable.sh [options]' \
    '  --jobs N             Parallel build jobs (default: 2)' \
    '  --build-root PATH    Build/package directory (default: native/build/ios-portable)' \
    '  --device-only        Build iphoneos arm64 only' \
    '  --simulator-only     Build iphonesimulator arm64 and x86_64 only' \
    '  --help               Show this help'
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_root="$repo_root/native/build/ios-portable"
jobs=2
platforms=(iphoneos iphonesimulator)
while (($#)); do
  case "$1" in
    --jobs|--build-root)
      (($# >= 2)) || { usage >&2; exit 2; }
      if [[ "$1" == --jobs ]]; then jobs="$2"; else build_root="$2"; fi
      shift 2 ;;
    --device-only) platforms=(iphoneos); shift ;;
    --simulator-only) platforms=(iphonesimulator); shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo 'Jobs must be a positive integer' >&2; exit 2; }
[[ "$(uname -s)" == Darwin ]] || { echo 'iOS builds require macOS and Xcode; no build performed.' >&2; exit 1; }
for tool in cmake ninja xcrun python3 curl shasum tar plutil git; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
plutil -lint "$repo_root/ios/Runner.xcodeproj/project.pbxproj"
xcrun --sdk iphoneos --show-sdk-path >/dev/null
xcrun --sdk iphonesimulator --show-sdk-path >/dev/null
mkdir -p "$build_root"
build_root="$(cd "$build_root" && pwd)"
case "$build_root" in
  *$'\n'*|*'"'*|*'$'*|*'#'*) echo 'Build path contains unsupported xcconfig characters' >&2; exit 2 ;;
esac
manifest="$repo_root/native/toolchain/portable-dependencies.json"
manifest_value() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]][sys.argv[3]])' \
    "$manifest" "$1" "$2"
}

# Source directories are checked against hashes recorded immediately after extraction.
# A changed tree requires a different build root; never overwrite local source edits.
source_digest() {
  python3 -c '
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
for path in sorted(root.rglob("*")):
    digest.update(str(path.relative_to(root)).encode("utf-8") + b"\0")
    if path.is_symlink():
        digest.update(b"L" + str(path.readlink()).encode("utf-8"))
    elif path.is_file():
        digest.update(b"F")
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
    else:
        digest.update(b"D")
print(digest.hexdigest())' "$1"
}

prepare_dependency() {
  local key="$1" archive expected actual directory marker tree_hash refresh_digest=0
  archive="$build_root/downloads/$(manifest_value "$key" archive)"
  expected="$(manifest_value "$key" sha256)"
  directory="$build_root/sources/$(manifest_value "$key" directory)"
  marker="$build_root/sources/$key.tree-sha256"
  mkdir -p "$build_root/downloads" "$build_root/sources"
  if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 --output "$archive.part" "$(manifest_value "$key" url)"
    mv "$archive.part" "$archive"
  fi
  actual="$(shasum -a 256 "$archive")"
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || { echo "Dependency checksum mismatch: $archive" >&2; exit 1; }
  if [[ -e "$directory" ]]; then
    [[ -f "$marker" ]] || { echo "Unverified source directory: $directory" >&2; exit 1; }
    tree_hash="$(source_digest "$directory")"
    [[ "$tree_hash" == "$(<"$marker")" ]] || {
      echo "Source files changed: $directory. Use a separate build root." >&2; exit 1;
    }
  else
    tar -xf "$archive" -C "$build_root/sources"
    [[ -d "$directory" ]] || { echo "Archive lacks expected source directory: $directory" >&2; exit 1; }
    refresh_digest=1
  fi
  if [[ "$key" == wasmedge ]]; then
    cmake "-DQFLI_WASMEDGE_SOURCE=$directory" \
      -P "$repo_root/native/portable/apply-wasmedge-patch.cmake"
    refresh_digest=1
  fi
  if [[ "$refresh_digest" == 1 ]]; then
    source_digest "$directory" > "$marker.part"
    mv "$marker.part" "$marker"
  fi
}
for key in wasiSdk llvm22 wasmedge fmt spdlog; do prepare_dependency "$key"; done
llvm_source="$build_root/sources/$(manifest_value llvm22 directory)"
wasi_sdk="$build_root/sources/$(manifest_value wasiSdk directory)"
wasmedge_source="$build_root/sources/$(manifest_value wasmedge directory)"
fmt_source="$build_root/sources/$(manifest_value fmt directory)"
spdlog_source="$build_root/sources/$(manifest_value spdlog directory)"

host="$build_root/host"
cmake -S "$repo_root/native/compiler" -B "$host" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DFETCHCONTENT_SOURCE_DIR_LLVM22="$llvm_source" \
  -DQFLI_BUILD_COMPILER_TESTS=OFF -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF
cmake --build "$host" --target llvm-tblgen clang-tblgen --parallel "$jobs"
host_bin="$host/_deps/llvm22-build/bin"
[[ -x "$host_bin/llvm-tblgen" && -x "$host_bin/clang-tblgen" ]] || {
  echo "Missing native TableGen executables: $host_bin" >&2; exit 1;
}
"$host_bin/llvm-tblgen" --version
"$host_bin/clang-tblgen" --version

final_package="$build_root/package"
package="$(mktemp -d "$build_root/package.XXXXXX")"
mkdir -p "$package/include" "$package/resources/sdk/share" "$package/resources/sdk/lib" "$package/resources/sdk/licenses"
cp "$repo_root/native/compiler/include/qfli_compiler.h" "$package/include/"
cp "$repo_root/native/portable/include/qfli_wasm.h" "$package/include/"
# These resources are platform-independent Wasm data. No SDK host executable ships.
/usr/bin/ditto "$wasi_sdk/share/wasi-sysroot" "$package/resources/sdk/share/wasi-sysroot"
/usr/bin/ditto "$wasi_sdk/lib/clang/22" "$package/resources/sdk/lib/clang/22"
cp "$llvm_source/LICENSE.TXT" "$package/resources/sdk/licenses/LLVM.txt"
cp "$llvm_source/libcxx/LICENSE.TXT" "$package/resources/sdk/licenses/libcxx.txt"
cp "$llvm_source/libcxxabi/LICENSE.TXT" "$package/resources/sdk/licenses/libcxxabi.txt"
cp "$wasmedge_source/LICENSE" "$package/resources/sdk/licenses/WasmEdge.txt"
cp "$fmt_source/LICENSE" "$package/resources/sdk/licenses/fmt.txt"
cp "$spdlog_source/LICENSE" "$package/resources/sdk/licenses/spdlog.txt"
python3 -c '
import hashlib, json, pathlib, sys
deps = json.load(open(sys.argv[1], encoding="utf-8"))
patch_directory = pathlib.Path(sys.argv[2])
patches = []
for name in ("wasmedge-interruptible-poll.patch", "wasmedge-static-archive.patch"):
    patch = patch_directory / name
    patches.append({"file": name, "sha256": hashlib.sha256(patch.read_bytes()).hexdigest()})
json.dump({"format": 1, "wasiSdkVersion": deps["wasiSdk"]["version"],
           "llvmCommit": deps["llvm22"]["commit"],
           "runtimeCommit": deps["wasmedge"]["commit"],
           "runtimePatches": patches,
           "execution": "interpreter", "jit": False, "dependencies": deps},
          sys.stdout, indent=2)
print()' "$manifest" "$repo_root/native/portable/patches" \
  > "$package/resources/sdk/toolchain.json"

for platform in "${platforms[@]}"; do
  if [[ "$platform" == iphoneos ]]; then arches=(arm64); else arches=(arm64 x86_64); fi
  sdk_path="$(xcrun --sdk "$platform" --show-sdk-path)"
  compiler="$(xcrun --sdk "$platform" --find clang)"
  compiler_cpp="$(xcrun --sdk "$platform" --find clang++)"
  libtool="$(xcrun --sdk "$platform" --find libtool)"
  merged=()
  for arch in "${arches[@]}"; do
    directory="$build_root/$platform-$arch"
    mkdir -p "$directory"
    common=(
      -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=iOS
      "-DCMAKE_OSX_SYSROOT=$sdk_path" "-DCMAKE_OSX_ARCHITECTURES=$arch"
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
      "-DCMAKE_C_COMPILER=$compiler" "-DCMAKE_CXX_COMPILER=$compiler_cpp"
      "-DCMAKE_AR=$libtool" -DCMAKE_POSITION_INDEPENDENT_CODE=ON
      -DBUILD_SHARED_LIBS=OFF
    )
    cmake -S "$repo_root/native/compiler" -B "$directory/compiler" "${common[@]}" \
      "-DFETCHCONTENT_SOURCE_DIR_LLVM22=$llvm_source" \
      "-DLLVM_TABLEGEN=$host_bin/llvm-tblgen" "-DCLANG_TABLEGEN=$host_bin/clang-tblgen" \
      "-DLLVM_NATIVE_TOOL_DIR=$host_bin" -DLLVM_HOST_TRIPLE="$arch-apple-darwin" \
      -DLLVM_BUILD_LLVM_DYLIB=OFF -DLLVM_LINK_LLVM_DYLIB=OFF \
      -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_BACKTRACES=OFF -DLLVM_ENABLE_LIBEDIT=OFF \
      -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DQFLI_BUILD_COMPILER_TESTS=OFF
    cmake --build "$directory/compiler" --target qfli_compiler --parallel "$jobs"
    cmake -S "$repo_root/native/portable" -B "$directory/runtime" "${common[@]}" \
      "-DFETCHCONTENT_SOURCE_DIR_WASMEDGE=$wasmedge_source" \
      "-DFETCHCONTENT_SOURCE_DIR_FMT=$fmt_source" \
      "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=$spdlog_source" \
      -DCMAKE_DISABLE_FIND_PACKAGE_fmt=ON -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
      -DWASMEDGE_USE_LLVM=OFF -DWASMEDGE_BUILD_SHARED_LIB=OFF \
      -DWASMEDGE_BUILD_STATIC_LIB=ON -DQFLI_BUILD_WASM_TESTS=OFF
    cmake --build "$directory/runtime" --target qfli_wasm --parallel "$jobs"
    grep -q '^WASMEDGE_USE_LLVM:BOOL=OFF$' "$directory/runtime/CMakeCache.txt" || {
      echo 'Wasm interpreter must have LLVM/JIT disabled' >&2; exit 1;
    }
    libraries=("$directory/compiler/libqfli_compiler.a"
      "$directory/compiler/_deps/llvm22-build/lib/"*.a
      "$directory/runtime/libqfli_wasm.a"
      "$directory/runtime/_deps/wasmedge-build/lib/api/libwasmedge.a")
    for library in "${libraries[@]}"; do
      [[ -f "$library" ]] || { echo "Missing static dependency: $library" >&2; exit 1; }
      xcrun lipo "$library" -verify_arch "$arch"
    done
    "$libtool" -static -o "$directory/libqfli_portable.a" "${libraries[@]}"
    xcrun nm -g "$directory/libqfli_portable.a" > "$directory/exported-symbols.txt"
    for symbol in qfli_compiler_create qfli_compiler_compile qfli_compiler_cancel \
                  qfli_wasm_create qfli_wasm_run qfli_wasm_cancel; do
      grep -q " T _$symbol$" "$directory/exported-symbols.txt" || {
        echo "Missing native export: $symbol" >&2; exit 1;
      }
    done
    merged+=("$directory/libqfli_portable.a")
  done
  mkdir -p "$package/$platform"
  xcrun lipo -create "${merged[@]}" -output "$package/$platform/libqfli_portable.a"
done

# Enable native code only after every requested static slice and resource was built.
if [[ -e "$final_package" ]]; then
  previous="$(mktemp -d "$build_root/package-previous.XXXXXX")"
  rmdir "$previous"
  mv "$final_package" "$previous"
  mv "$package" "$final_package"
  rm -rf -- "$previous"
else
  mv "$package" "$final_package"
fi
package="$final_package"
config="$repo_root/ios/Flutter/NativeRuntime.generated.xcconfig"
printf '%s\n' \
  '// Generated by native/toolchain/build-ios-portable.sh.' \
  "QFLI_RUNTIME_PACKAGE = $package" \
  'QFLI_PORTABLE_ENABLED = 1' \
  'GCC_PREPROCESSOR_DEFINITIONS = $(inherited) QFLI_PORTABLE_RUNTIME=1' \
  'LIBRARY_SEARCH_PATHS = $(inherited) "$(QFLI_RUNTIME_PACKAGE)/$(PLATFORM_NAME)"' \
  'OTHER_LDFLAGS = $(inherited) -lqfli_portable -lc++ -framework Foundation' > "$config"
printf 'iOS native package: %s\nXcode configuration: %s\n' "$package" "$config"
printf '%s\n' 'Build complete. iOS application and signed-device execution require separate verification.'
