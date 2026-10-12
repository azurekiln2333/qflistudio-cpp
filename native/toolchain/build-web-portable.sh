#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
deps=${QFLI_PORTABLE_DEPS:-"$repo/native/build/portable-deps"}
emsdk=${QFLI_EMSDK:-"$repo/native/build/emsdk-4.0.23"}
build=${QFLI_WEB_BUILD:-"$repo/native/build/compiler-web-make"}
host=${QFLI_LLVM_HOST_TOOLS:-"$repo/native/build/compiler-linux/_deps/llvm22-build/bin"}
sdk="$deps/wasi-sdk-33.0-x86_64-linux"
llvm="$deps/llvm-project-4434dabb69916856b824f68a64b029c67175e532"

for path in "$emsdk/emsdk_env.sh" "$sdk/share/wasi-sysroot/include/wasm32-wasip1/stdio.h" \
  "$host/llvm-tblgen" "$host/clang-tblgen" "$llvm/llvm/CMakeLists.txt"; do
  test -f "$path" || { printf 'Missing browser build prerequisite: %s\n' "$path" >&2; exit 1; }
done
# The fixed emsdk release owns its tool download hashes in emsdk_manifest.json.
source "$emsdk/emsdk_env.sh"
emcc --version | head -1 | grep -F '4.0.23' >/dev/null || {
  printf 'This build requires Emscripten 4.0.23.\n' >&2; exit 1;
}
emcmake cmake -S "$repo/native/web" -B "$build" -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-fwasm-exceptions \
  -DFETCHCONTENT_SOURCE_DIR_LLVM22="$llvm" \
  -DLLVM_NATIVE_TOOL_DIR="$host" -DLLVM_TABLEGEN="$host/llvm-tblgen" \
  -DCLANG_TABLEGEN="$host/clang-tblgen" -DQFLI_WASI_SDK="$sdk" \
  -DLLVM_ENABLE_THREADS=OFF -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF
cmake --build "$build" --target qfli_compiler_web --parallel "${QFLI_WEB_JOBS:-1}"

mkdir -p "$repo/web/toolchain"
for name in qfli-compiler.js qfli-compiler.wasm qfli-compiler.data; do
  test -s "$build/$name"
  cp "$build/$name" "$repo/web/toolchain/$name"
done
cd "$repo/native/web"
npm ci --ignore-scripts
npm run build
sha256sum "$repo/web/toolchain/"qfli-compiler.*
