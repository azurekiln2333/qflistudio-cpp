#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
wasi_sdk=${WASI_SDK:-"$repo_root/native/build/portable-deps/wasi-sdk-33.0-x86_64-linux"}
probe=${WASM_PROBE:-"$repo_root/native/build/portable-linux-eh/qfli_wasm_probe"}
project="$repo_root/test/fixtures/portable_wasm/sleep"
mkdir -p "$repo_root/native/build/portable-sleep-review"
work=$(mktemp -d "$repo_root/native/build/portable-sleep-review/run.XXXXXX")
"$wasi_sdk/bin/clang" -std=c17 "$project/main.c" -o "$work/program.wasm"

run() {
    local expected=$1 input=$2
    shift 2
    local code=0
    timeout 3 "$probe" "$@" "$work/program.wasm" "$project" \
        <"$input" >"$work/actual.stdout" 2>"$work/actual.stderr" || code=$?
    printf 'Sleep fixture exit: %s (expected %s)\n' "$code" "$expected"
    [[ "$code" == "$expected" ]]
    [[ ! -s "$work/actual.stderr" ]]
}

if [[ ${1:-} == --expect-timeout ]]; then
    run 124 /dev/null --cancel
    printf 'ready\n' >"$work/expected.stdout"
    diff -u "$work/expected.stdout" "$work/actual.stdout"
    printf '%s\n' 'Reproduced: cancellation cannot interrupt the 30-second sleep.'
    exit 0
fi

run 0 "$project/input.txt"
printf 'ready\nslept\n' >"$work/expected.stdout"
diff -u "$work/expected.stdout" "$work/actual.stdout"
run 0 "$project/input.txt" --repeat
printf 'ready\nslept\nready\nslept\n' >"$work/expected.stdout"
diff -u "$work/expected.stdout" "$work/actual.stdout"
run 130 /dev/null --cancel
printf 'ready\n' >"$work/expected.stdout"
diff -u "$work/expected.stdout" "$work/actual.stdout"
run 130 /dev/null --cancel-before
[[ ! -s "$work/actual.stdout" ]]
printf '%s\n' 'PASS sleep: normal deadlines, repeated runs, cancel and pre-cancel.'
