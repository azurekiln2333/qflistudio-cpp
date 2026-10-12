#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixtures="$repo_root/test/fixtures/desktop_native"
c_driver=${CC:-cc}
cpp_driver=${CXX:-c++}

if [[ $(uname -s) != Linux ]]; then
    printf '%s\n' 'This verifier requires a Linux host.' >&2
    exit 1
fi
command -v "$c_driver" >/dev/null
command -v "$cpp_driver" >/dev/null

probe_dir=$(mktemp -d '/tmp/qfli_linux_native.XXXXXX')
case_program=''
program_pid=''
cleanup() {
    if [[ -n "$program_pid" ]]; then
        kill "$program_pid" 2>/dev/null || true
        wait "$program_pid" 2>/dev/null || true
    fi
    case "$probe_dir" in
        /tmp/qfli_linux_native.*) rm -rf -- "$probe_dir" ;;
        *) printf 'Unexpected temporary path: %s\n' "$probe_dir" >&2 ;;
    esac
}
trap cleanup EXIT

build_case() {
    local name=$1
    local project="$probe_dir/$name"
    local fixture_name="$name"
    local source object driver standard language
    local linker="$c_driver"
    local index=0
    local -a sources objects include_args
    if [[ "$name" == mixed_case ]]; then
        fixture_name=mixed_c_main
    fi
    cp -R -- "$fixtures/$fixture_name" "$project"
    if [[ "$name" == mixed_case ]]; then
        mv -- "$project/main.c" "$project/main.C"
        mv -- "$project/helper.cpp" "$project/helper.CPP"
    fi
    mkdir -p "$project/.qfli/build/forge"
    case_program="$project/.qfli/build/forge/program"
    include_args=(-I "$project")
    if [[ -d "$project/include" ]]; then
        include_args+=(-I "$project/include")
    fi
    mapfile -d '' sources < <(
        find "$project" -type f \
            \( -iname '*.c' -o -iname '*.cpp' -o -iname '*.cc' -o -iname '*.cxx' \) \
            -print0 | sort -z
    )
    objects=()
    for source in "${sources[@]}"; do
        driver="$c_driver"
        standard=c17
        language=c
        if [[ ${source,,} != *.c ]]; then
            driver="$cpp_driver"
            standard=c++20
            language=c++
            linker="$cpp_driver"
        fi
        object="$project/.qfli/build/forge/unit_$index.o"
        "$driver" -x "$language" "-std=$standard" "${include_args[@]}" -c "$source" -o "$object"
        objects+=("$object")
        index=$((index + 1))
    done

    if [[ "$name" == link_error ]]; then
        local code=0
        "$linker" "${objects[@]}" -lm -o "$case_program" \
            >"$project/link.stdout" 2>"$project/link.stderr" || code=$?
        if [[ "$code" == 0 || ! -s "$project/link.stderr" ]]; then
            printf '%s\n' 'Expected a link failure with diagnostics.' >&2
            exit 1
        fi
        if [[ $(<"$project/link.stderr") != *missing_symbol* ]]; then
            printf '%s\n' 'Link diagnostics did not identify missing_symbol.' >&2
            exit 1
        fi
        printf 'PASS link_error: linker status %s; program not launched\n' "$code"
        return
    fi
    "$linker" "${objects[@]}" -lm -o "$case_program"
}

run_case() {
    local name=$1 expected_code=$2 expected_stdout=$3 expected_stderr=$4
    local code=0
    build_case "$name"
    local project="$probe_dir/$name"
    local input=/dev/null
    if [[ -f "$project/input.txt" ]]; then
        input="$project/input.txt"
    fi
    (
        cd -- "$project"
        "$case_program" <"$input" >actual.stdout 2>actual.stderr
    ) || code=$?
    printf '%s' "$expected_stdout" >"$project/expected.stdout"
    printf '%s' "$expected_stderr" >"$project/expected.stderr"
    if [[ "$code" != "$expected_code" ]]; then
        printf '%s: expected exit %s, got %s\n' "$name" "$expected_code" "$code" >&2
        exit 1
    fi
    diff -u "$project/expected.stdout" "$project/actual.stdout"
    diff -u "$project/expected.stderr" "$project/actual.stderr"
    printf 'PASS %s: exit %s, stdout/stderr match\n' "$name" "$code"
}

printf '%s\n' 'Linux native compiler/program verification (Flutter app not exercised).'
"$c_driver" --version
"$cpp_driver" --version
run_case mixed_c_main 0 $'42\n' ''
run_case mixed_case 0 $'42\n' ''
run_case math 0 $'4.000000\n' ''
run_case io 0 $'input=42\n' $'input accepted\n'
run_case nonzero 7 $'before exit\n' $'intentional failure\n'
build_case link_error

build_case cancel
cancel_project="$probe_dir/cancel"
"$case_program" >"$cancel_project/actual.stdout" 2>"$cancel_project/actual.stderr" &
program_pid=$!
ready=false
for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -s "$cancel_project/actual.stdout" ]]; then
        ready=true
        break
    fi
    sleep 0.05
done
if [[ "$ready" != true ]]; then
    printf '%s\n' 'Cancel fixture did not reach its ready output.' >&2
    exit 1
fi
printf 'ready\n' >"$cancel_project/expected.stdout"
diff -u "$cancel_project/expected.stdout" "$cancel_project/actual.stdout"
kill -TERM "$program_pid"
signal_code=0
wait "$program_pid" || signal_code=$?
program_pid=''
if [[ "$signal_code" != 143 ]]; then
    printf 'Expected SIGTERM status 143, got %s\n' "$signal_code" >&2
    exit 1
fi
if [[ -s "$cancel_project/actual.stderr" ]]; then
    printf '%s\n' 'Cancel fixture unexpectedly wrote to stderr.' >&2
    exit 1
fi
printf '%s\n' 'PASS cancel: native SIGTERM status 143 (Dart adapter tested separately).'
printf '%s\n' 'All 7 Linux native fixture checks passed.'
