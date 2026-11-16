#!/usr/bin/env python3
"""Adapt an unmodified native SDK to the host Clang 15 OHOS cross layout."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inventory(root):
    return {path.relative_to(root).as_posix(): sha256(path)
            for path in sorted(root.rglob('*')) if path.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-sdk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sdk, output = args.native_sdk.resolve(), args.output.resolve()
    metadata = json.loads((sdk / 'oh-uni-package.json').read_text())
    if metadata.get('path') != 'native':
        raise SystemExit('Expected a native OHOS SDK')
    compiler_resources = sdk / 'llvm/lib/clang/15.0.4'
    if not (compiler_resources / 'include/stddef.h').is_file():
        raise SystemExit('This host Clang 15 adapter requires SDK Clang 15.0.4 resources')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ohos-cross-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'resources'
        sdk_triple, target = 'aarch64-linux-ohos', 'aarch64-unknown-linux-ohos'
        copies = {
            'sysroot/usr/include': sdk / 'sysroot/usr/include',
            f'sysroot/usr/lib/{sdk_triple}': sdk / f'sysroot/usr/lib/{sdk_triple}',
            'include/c++/v1': sdk / 'llvm/include/libcxx-ohos/include/c++/v1',
            'lib/clang/15.0.4/include': compiler_resources / 'include',
            f'lib/clang/15.0.4/lib/{target}': compiler_resources / f'lib/{sdk_triple}',
            f'lib/{target}': sdk / f'llvm/lib/{sdk_triple}',
        }
        for relative, source in copies.items():
            if not source.is_dir():
                raise SystemExit(f'Missing native SDK directory: {source}')
            shutil.copytree(source, stage / relative)
        for relative, source in {'licenses/OHOS-Native-SDK.txt': sdk / 'NOTICE.txt',
                                 'licenses/OHOS-LLVM.txt': sdk / 'llvm/NOTICE'}.items():
            (stage / relative).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, stage / relative)
        (stage / 'bin').mkdir()
        config = [f'--target={target}', '-D__OHOS__=1', '-D__OHOS_FAMILY__=1', '-D__MUSL__=1',
                  '--sysroot=<CFGDIR>/../sysroot', '-resource-dir=<CFGDIR>/../lib/clang/15.0.4',
                  f'-isystem <CFGDIR>/../sysroot/usr/include/{sdk_triple}',
                  '-isystem <CFGDIR>/../include/c++/v1',
                  f'-B<CFGDIR>/../sysroot/usr/lib/{sdk_triple}',
                  f'-L<CFGDIR>/../sysroot/usr/lib/{sdk_triple}', f'-L<CFGDIR>/../lib/{target}',
                  '--rtlib=compiler-rt', '--unwindlib=libunwind', '-stdlib=libc++',
                  '--ld-path=/usr/bin/ld.lld-18', '-Wl,--dynamic-linker,/lib/ld-musl-aarch64.so.1']
        (stage / 'bin/ohos.cfg').write_text('\n'.join(config) + '\n')
        manifest = {'formatVersion': 2, 'inputKind': 'native-sdk', 'targetTriple': target,
                    'architecture': 'arm64-v8a', 'nativeSdk': metadata,
                    'compilerResourceVersion': '15.0.4', 'files': inventory(stage)}
        provenance = sdk / 'qfli-sdk-provenance.json'
        if provenance.is_file():
            manifest['publicSdkArchive'] = json.loads(provenance.read_text())
        (stage / 'toolchain.json').write_text(json.dumps(manifest, indent=2) + '\n')
        if output.exists():
            if inventory(stage) != inventory(output):
                raise SystemExit('SDK input or staged resources changed; choose a fresh build root')
        else:
            stage.rename(output)
    print(f'OHOS host cross resources: {output}')


if __name__ == '__main__':
    main()
