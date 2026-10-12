#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
wasi_sdk=${WASI_SDK:-"$repo_root/native/build/portable-deps/wasi-sdk-33.0-x86_64-linux"}
probe=${WASM_PROBE:-"$repo_root/native/build/portable-linux-eh/qfli_wasm_probe"}
compiler_probe=${COMPILER_PROBE:-}
desktop_fixtures="$repo_root/test/fixtures/desktop_native"
portable_fixtures="$repo_root/test/fixtures/portable_wasm"

[[ -x "$wasi_sdk/bin/clang" && -x "$wasi_sdk/bin/clang++" && -x "$probe" ]]
"$wasi_sdk/bin/clang" --version
mkdir -p "$repo_root/native/build/portable-fixtures"
work=$(mktemp -d "$repo_root/native/build/portable-fixtures/run with spaces.XXXXXX")
printf 'Fixture artifacts: %s\n' "$work"

build_case() {
    local name=$1 fixture="$desktop_fixtures/$1"
    local project="$work/$name" language standard source object
    local linker="$wasi_sdk/bin/clang"
    local index=0
    local -a sources objects includes
    if [[ -d "$portable_fixtures/$name" ]]; then
        fixture="$portable_fixtures/$name"
    elif [[ "$name" == mixed_case ]]; then
        fixture="$desktop_fixtures/mixed_c_main"
    fi
    cp -R -- "$fixture" "$project"
    if [[ "$name" == mixed_case ]]; then
        mv -- "$project/main.c" "$project/rename-main"
        mv -- "$project/rename-main" "$project/main.C"
        mv -- "$project/helper.cpp" "$project/rename-helper"
        mv -- "$project/rename-helper" "$project/helper.CPP"
    fi
    mkdir -p "$project/.qfli/build"
    includes=(-I "$project")
    [[ ! -d "$project/include" ]] || includes+=(-I "$project/include")
    mapfile -d '' sources < <(
        find "$project" -type f \
            \( -iname '*.c' -o -iname '*.cpp' -o -iname '*.cc' -o -iname '*.cxx' \) \
            -print0 | sort -z
    )
    objects=()
    if [[ -n "$compiler_probe" ]]; then
        "$compiler_probe" "$wasi_sdk" "$project" "$project/.qfli/build"
        return
    fi
    for source in "${sources[@]}"; do
        language=c
        standard=c17
        if [[ ${source,,} != *.c ]]; then
            language=c++
            standard=c++20
            linker="$wasi_sdk/bin/clang++"
        fi
        object="$project/.qfli/build/unit_$index.o"
        "$wasi_sdk/bin/clang" -x "$language" "-std=$standard" \
            -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false \
            "${includes[@]}" -c "$source" -o "$object"
        objects+=("$object")
        index=$((index + 1))
    done
    "$linker" -fwasm-exceptions \
        "${objects[@]}" -lunwind -lm -o "$project/.qfli/build/program.wasm"
}

run_case() {
    local name=$1 expected_code=$2 expected_stdout=$3 expected_stderr=$4
    shift 4
    local project="$work/$name" input=${CASE_INPUT:-/dev/null} code=0
    if [[ -z ${CASE_INPUT:-} && -f "$project/input.txt" ]]; then input="$project/input.txt"; fi
    timeout "${RUN_TIMEOUT:-30}" "$probe" "$@" "$project/.qfli/build/program.wasm" "$project" \
        <"$input" >"$project/actual.stdout" 2>"$project/actual.stderr" || code=$?
    [[ "$code" == "$expected_code" ]] || {
        printf '%s: expected exit %s, got %s\n' "$name" "$expected_code" "$code" >&2
        cat "$project/actual.stderr" >&2
        exit 1
    }
    printf '%s' "$expected_stdout" >"$project/expected.stdout"
    printf '%s' "$expected_stderr" >"$project/expected.stderr"
    diff -u "$project/expected.stdout" "$project/actual.stdout"
    diff -u "$project/expected.stderr" "$project/actual.stderr"
    printf 'PASS %s: exit %s; output and caller FDs preserved\n' "$name" "$code"
}

for fixture in mixed_c_main mixed_case math io nonzero exceptions files memory trap cancel sleep; do
    build_case "$fixture"
done
run_case mixed_c_main 0 $'42\n' ''
run_case mixed_case 0 $'42\n' ''
run_case math 0 $'4.000000\n' ''
run_case io 0 $'input=42\n' $'input accepted\n'
run_case nonzero 7 $'before exit\n' $'intentional failure\n'
run_case nonzero 7 $'before exit\nbefore exit\n' \
    $'intentional failure\nintentional failure\n' --repeat
run_case exceptions 0 \
    $'exception preserved; destructors=2\nstdlib exception caught\n' ''
run_case exceptions 0 \
    $'exception preserved; destructors=2\nstdlib exception caught\nexception preserved; destructors=2\nstdlib exception caught\n' \
    '' --repeat
run_case files 0 $'file=42\n' ''
diff -u "$work/files/data/input.txt" "$work/files/output.txt"
run_case memory 0 $'memory bounded\n' ''
run_case cancel 130 $'ready\n' '' --cancel
run_case cancel 130 '' '' --cancel-before
run_case sleep 0 $'ready\nslept\n' ''
run_case sleep 0 $'ready\nslept\nready\nslept\n' '' --repeat
CASE_INPUT=/dev/null RUN_TIMEOUT=3 run_case sleep 130 $'ready\n' '' --cancel
CASE_INPUT=/dev/null RUN_TIMEOUT=3 run_case sleep 130 '' '' --cancel-before

for fixture in trap cancel; do
    project="$work/$fixture"
    options=()
    [[ "$fixture" != cancel ]] || options=(--fuel)
    code=0
    timeout 30 "$probe" "${options[@]}" "$project/.qfli/build/program.wasm" "$project" \
        </dev/null >"$project/actual.stdout" 2>"$project/actual.stderr" || code=$?
    [[ "$code" == 125 && -s "$project/actual.stderr" ]]
    if [[ "$fixture" == trap ]]; then
        grep -q 'unreachable' "$project/actual.stderr"
    else
        grep -q 'cost limit exceeded' "$project/actual.stderr"
    fi
    printf 'PASS %s: bounded runtime failure, status 125 with diagnostics\n' "$fixture"
done

project="$work/link_error"
cp -R -- "$desktop_fixtures/link_error" "$project"
code=0
"$wasi_sdk/bin/clang" "$project/main.c" -o "$project/program.wasm" \
    >"$project/actual.stdout" 2>"$project/actual.stderr" || code=$?
[[ "$code" != 0 && ! -f "$project/program.wasm" ]]
grep -q missing_symbol "$project/actual.stderr"
printf '%s\n' 'PASS link_error: diagnostics, no executable module'
if [[ -n "$compiler_probe" ]]; then
    project="$work/mixed_c_main"
    output="$project/.qfli/build"
    "$compiler_probe" --repeat "$wasi_sdk" "$project" "$output"
    "$compiler_probe" --sequence "$wasi_sdk" \
        "$project" "$output" 0 \
        "$work/link_error" "$output" 1 \
        "$project" "$output" 0 \
        2>"$work/compiler-recovery.stderr"
    grep -q missing_symbol "$work/compiler-recovery.stderr"
    printf '%s\n' 'PASS compiler repeat/recovery: no stale module, linker reusable'
    mkdir -p "$work/syntax_error"
    printf 'int main(void) { invalid syntax; }\n' >"$work/syntax_error/main.c"
    "$compiler_probe" --sequence "$wasi_sdk" \
        "$work/syntax_error" "$output" 1 \
        "$project" "$output" 0 2>"$work/compiler-syntax.stderr"
    grep -q 'error:' "$work/compiler-syntax.stderr"
    printf '%s\n' 'PASS compiler syntax recovery: diagnostics and fresh module'
    mkdir -p "$work/compile_cancel"
    awk 'BEGIN { for(i=0;i<200000;i++) print "int value_" i "=" i ";"; print "int main(void){return 0;}"; }' \
        >"$work/compile_cancel/main.c"
    for option in --cancel-recover --cancel-before-recover; do
        timeout 30 "$compiler_probe" "$option" "$wasi_sdk" \
            "$work/compile_cancel" "$output" "$project"
        printf 'PASS compiler %s: cancel 130, clean output, same-process recovery\n' "$option"
    done
fi
printf '%s\n' 'All 19 portable Wasm checks and requested compiler lifecycle checks passed (Apple app not exercised).'
