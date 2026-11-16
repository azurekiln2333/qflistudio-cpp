#!/usr/bin/env python3
"""Cross-link OHOS fixtures and the actual application bridge without running them."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(arguments):
    print('+ ' + ' '.join(map(str, arguments)), flush=True)
    subprocess.run(list(map(str, arguments)), check=True)


def inspect_elf(path, readobj):
    raw = subprocess.check_output([readobj, '--elf-output-style=JSON', '--file-headers',
                                   '--program-headers', '--needed-libs', str(path)], text=True)
    record = json.loads(raw)[0]
    # LLVM 18 emits a file key around this record; newer versions may omit it.
    if 'FileSummary' not in record:
        record = next(iter(record.values()))
    machine = record['ElfHeader']['Machine']
    if machine.get('Value', machine.get('RawValue')) != 183:
        raise ValueError(f'Expected an ARM64 ELF: {path}')
    loads = [item['ProgramHeader'] for item in record['ProgramHeaders']
             if item['ProgramHeader']['Type'].get('Value', item['ProgramHeader']['Type'].get('RawValue')) == 1]
    if not loads or any(item['Alignment'] < 16384 or
                        (item['VirtualAddress'] - item['Offset']) % 16384 for item in loads):
        raise ValueError(f'ELF is not aligned to 16 KiB: {path}')
    allowed = {'libc.so', 'libc++_shared.so', 'libace_napi.z.so', 'libhilog_ndk.z.so'}
    if set(record['NeededLibraries']) - allowed:
        raise ValueError(f'Unexpected ELF dependencies: {record["NeededLibraries"]}')
    return {'sha256': sha256(path), 'bytes': path.stat().st_size,
            'architecture': 'aarch64', 'neededLibraries': record['NeededLibraries'],
            'loadAlignments': [item['Alignment'] for item in loads]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--package', type=Path, help='Also link the complete app bridge against these archives')
    parser.add_argument('--compiler', default='/usr/bin/clang-15')
    parser.add_argument('--readobj', default='llvm-readobj-18')
    parser.add_argument('--linker', default='/usr/bin/ld.lld-18')
    args = parser.parse_args()
    resources, output = args.resources.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    common = ['--config', str(resources / 'bin/ohos.cfg'), '-Qunused-arguments', '-fPIC']
    cpp = ['--driver-mode=g++', '-std=c++17', '-nostdinc++', '-stdlib=libc++']
    link = [f'--ld-path={args.linker}', '-Wl,-z,defs',
            '-Wl,-z,max-page-size=16384,-z,common-page-size=16384', '-lm']
    fixture = ROOT / 'native/toolchain/tests/fixture'
    run([args.compiler, *common, '--driver-mode=gcc', '-std=c17', '-I', fixture / 'include',
         '-c', fixture / 'answer.c', '-o', output / 'answer.o'])
    run([args.compiler, *common, *cpp, '-I', fixture / 'include', '-c', fixture / 'main.cpp',
         '-o', output / 'main.o'])
    fixture_output = output / 'mixed-c-cpp.so'
    run([args.compiler, *common, *cpp, *link, '-shared', output / 'answer.o',
         output / 'main.o', '-o', fixture_output])
    fixture_metadata = inspect_elf(fixture_output, args.readobj)
    bridge = ROOT / 'ohos/entry/src/main/cpp/qfli_ohos_portable.cpp'
    bridge_object = output / 'qfli_ohos_portable.o'
    run([args.compiler, *common, *cpp, '-fexceptions', '-frtti', '-fvisibility=hidden',
         '-c', bridge, '-o', bridge_object])
    report = {'fixtureCrossLinked': True, 'fixture': fixture_metadata,
              'bridgeCompiled': True, 'bridgeSourceSha256': sha256(bridge),
              'bridgeLinked': False, 'appExecutionVerified': False,
              'compilerVersion': subprocess.check_output([args.compiler, '--version'], text=True).strip()}
    if args.package:
        libraries = args.package.resolve() / 'lib/arm64-v8a'
        bridge_output = output / 'libqfli_ohos_runner.so'
        run([args.compiler, *common, *cpp, *link, '-shared', '-Wl,--exclude-libs,ALL',
             bridge_object, '-Wl,--start-group', libraries / 'libqfli_compiler.a',
             libraries / 'libqfli_wasm.a', '-Wl,--end-group', '-lace_napi.z', '-lhilog_ndk.z',
             '-ldl', '-lm', '-o', bridge_output])
        report['bridgeLinked'] = True
        report['bridge'] = inspect_elf(bridge_output, args.readobj)
    (output / 'native-validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
