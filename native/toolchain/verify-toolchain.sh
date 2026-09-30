#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: sh verify-toolchain.sh TOOLCHAIN_DIRECTORY [--compile-only]" >&2
    exit 2
fi
compile_only=false
if [ "$#" -eq 2 ]; then
    if [ "$2" != '--compile-only' ]; then
        echo "Unknown option: $2" >&2
        exit 2
    fi
    compile_only=true
fi
toolchain=$(cd "$1" && pwd)
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fixture="$script_directory/tests/fixture"
build=$(mktemp -d "${TMPDIR:-/tmp}/qfli-toolchain-check.XXXXXX")
compiler=${CLANG:-"$toolchain/bin/clang"}
for runtime in "$toolchain"/lib/*-unknown-linux-ohos; do
    if [ -d "$runtime" ]; then
        export LD_LIBRARY_PATH="$runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
done

compile() {
    if [ -n "${LLD:-}" ]; then
        "$compiler" --config "$toolchain/bin/ohos.cfg" "--ld-path=$LLD" \
            -Wno-unused-command-line-argument "$@"
    else
        "$compiler" --config "$toolchain/bin/ohos.cfg" \
            -Wno-unused-command-line-argument "$@"
    fi
}

compile -std=c17 -I"$fixture/include" -c "$fixture/answer.c" -o "$build/answer.o"
compile -std=c17 -I"$fixture/include" -c "$fixture/main.c" -o "$build/main-c.o"
compile "$build/main-c.o" "$build/answer.o" -o "$build/program-c"
compile --driver-mode=g++ -std=c++20 -I"$fixture/include" \
    -c "$fixture/main.cpp" -o "$build/main-cpp.o"
compile --driver-mode=g++ "$build/main-cpp.o" "$build/answer.o" -o "$build/program-cpp"

if [ "$compile_only" = false ]; then
    for program in "$build/program-c" "$build/program-cpp"; do
        actual=$("$program")
        if [ "$actual" != '42' ]; then
            echo "Unexpected output from $program: $actual" >&2
            exit 1
        fi
    done
    echo 'C and C++ compilation, mixed linking, and execution passed.'
else
    echo 'C and C++ cross compilation and mixed linking passed.'
fi
echo "Verification artifacts: $build"
