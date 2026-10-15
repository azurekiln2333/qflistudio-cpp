#!/usr/bin/env python3
"""Verify pinned OHOS portable resources and their exact signed-HAP contents.

Artifact checks never establish that application compilation/execution passed.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import struct
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def required_resources():
    names = {'lib/clang/22/include/stddef.h'}
    for target in ('wasm32-wasip1', 'wasm32-wasip1-threads'):
        headers = 'share/wasi-sysroot/include/' + target + '/'
        libraries = 'share/wasi-sysroot/lib/' + target + '/'
        names.update(headers + name for name in
                     ('stdio.h', 'eh/c++/v1/vector', 'eh/c++/v1/stdexcept'))
        names.update(libraries + name for name in
                     ('crt1-command.o', 'libc.a', 'libsetjmp.a',
                      'libwasi-emulated-process-clocks.a', 'eh/libc++.a',
                      'eh/libc++abi.a', 'eh/libunwind.a'))
        names.add('lib/clang/22/lib/' + target.replace('wasm32-', 'wasm32-unknown-') +
                  '/libclang_rt.builtins.a')
    names.add('share/wasi-sysroot/include/wasm32-wasip1-threads/pthread.h')
    names.add('share/wasi-sysroot/lib/wasm32-wasip1-threads/libpthread.a')
    return names


def validate_resources(data, dependencies, patches):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), 'Duplicate resource ZIP entries')
        inventory = {}
        for entry in archive.infolist():
            name = entry.filename
            path = PurePosixPath(name)
            require(not path.is_absolute() and '..' not in path.parts and
                    '\\' not in name and ':' not in name and not entry.is_dir(),
                    f'Unsafe/nonportable resource: {name}')
            require((entry.external_attr >> 16) & 0o170000 in (0, 0o100000),
                    f'Resource is not a regular file: {name}')
            require(name == 'toolchain.json' or name.startswith((
                'share/wasi-sysroot/', 'lib/clang/22/', 'licenses/')),
                f'Unexpected resource or host executable: {name}')
            require('/noeh/' not in name and '/llvm-lto/' not in name,
                    f'Unexpected alternate runtime resource: {name}')
            contents = archive.read(entry)
            require(not contents.startswith(b'\x7fELF'), f'Native ELF in writable SDK resources: {name}')
            if name != 'toolchain.json':
                inventory[name] = (sha256(contents), len(contents))
        manifest = json.loads(archive.read('toolchain.json'))
        require(manifest['formatVersion'] == 2 and
                manifest['llvmVersion'] == dependencies['llvm22']['version'] and
                manifest['llvmCommit'] == dependencies['llvm22']['commit'] and
                manifest['wasiSdkVersion'] == dependencies['wasiSdk']['version'] and
                manifest['runtimeCommit'] == dependencies['wasmedge']['commit'],
                'Portable dependency pins differ from the repository')
        require(manifest['dependencies'] == dependencies, 'Dependency archive hashes differ')
        require(manifest['runtimePatches'] == patches, 'Runtime patch hashes differ')
        require(manifest['targetTriple'] == 'wasm32-unknown-wasip1' and
                manifest['runtime'] == 'wasmedge-interpreter' and
                manifest['execution'] == 'interpreter' and manifest['jit'] is False,
                'Expected WASI interpreter with JIT disabled')
        require(manifest['supportedTargets'] == ['wasm32-unknown-wasip1',
                                                'wasm32-unknown-wasip1-threads'] and
                manifest['threading'] == 'wasi-threads' and
                manifest['maxWorkerThreads'] == 32,
                'Expected the verified WASI threads contract')
        require(manifest['resourceFileCount'] == len(inventory), 'Resource inventory count differs')
        tree = ''.join(f'{name}\0{inventory[name][0]}\n' for name in sorted(inventory))
        require(sha256(tree.encode()) == manifest['resourceTreeSha256'], 'Resource tree hash mismatch')
        resources = manifest['resources']
        require(len(resources) == len(required_resources()) and
                {item['path'] for item in resources} == required_resources(),
                'Required SDK resource list differs from the runtime contract')
        for item in resources:
            require(inventory.get(item['path']) == (item['sha256'], item['size']),
                    f'Required SDK resource digest mismatch: {item["path"]}')
        for name in ('licenses/LLVM.txt', 'licenses/libcxx.txt', 'licenses/libcxxabi.txt',
                     'licenses/WasmEdge.txt', 'licenses/fmt.txt', 'licenses/spdlog.txt'):
            require(name in inventory, f'Missing dependency license: {name}')
        return {'sha256': sha256(data), 'resourceFiles': len(inventory),
                'llvmVersion': manifest['llvmVersion'], 'execution': manifest['execution']}


def validate_runner(data):
    require(data[:6] == b'\x7fELF\x02\x01', 'Runner must be ELF64 little endian')
    header = struct.unpack_from('<HHIQQQIHHHHHH', data, 16)
    require(header[0] == 3 and header[1] == 183, 'Runner must be an AArch64 shared library')
    programs = [struct.unpack_from('<IIQQQQQQ', data, header[4] + i * header[8])
                for i in range(header[9])]
    require(not any(item[0] == 3 for item in programs), 'Runner must not be a PIE executable')
    loads = [item for item in programs if item[0] == 1]
    require(loads and all(item[7] >= 16384 for item in loads), 'Runner requires 16 KiB LOAD alignment')
    require(all(item[1] & 3 != 3 for item in loads), 'Runner has writable executable memory segments')
    dynamic = next(item for item in programs if item[0] == 2)
    tags = [struct.unpack_from('<qQ', data, dynamic[2] + offset)
            for offset in range(0, dynamic[5], 16)]
    require(not any(tag == 22 or tag == 30 and value & 4 for tag, value in tags),
            'Runner must not require text relocations')
    address = next(value for tag, value in tags if tag == 5)
    segment = next(item for item in loads if item[3] <= address < item[3] + item[5])
    strings = segment[2] + address - segment[3]
    needed = []
    for tag, value in tags:
        if tag == 1:
            start = strings + value
            needed.append(data[start:data.index(b'\0', start)].decode())
    require(set(needed) <= {'libc.so', 'libc++_shared.so', 'libace_napi.z.so', 'libhilog_ndk.z.so'},
            f'Unexpected runner dependencies: {needed}')
    require(b'qfli_ohos_portable_events\0' in data, 'HAP contains the old process-execution bridge')
    return {'sha256': sha256(data), 'neededLibraries': needed, 'minimumLoadAlignment': 16384}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=Path('.'))
    parser.add_argument('--hap', type=Path)
    options = parser.parse_args()
    root = options.project_root.resolve()
    dependencies = json.loads((root / 'native/toolchain/portable-dependencies.json').read_text())
    patches = [{'file': path.name, 'sha256': sha256(path.read_bytes())}
               for path in sorted((root / 'native/portable/patches').glob('*.patch'))]
    relative = 'qfli_toolchain/ohos-wasi.zip'
    resource = root / 'ohos/entry/src/main/resources/rawfile' / relative
    data = resource.read_bytes()
    require(resource.with_suffix('.zip.sha256').read_text().strip() == sha256(data),
            'Resource ZIP SHA256 sidecar mismatch')
    report = {'resources': validate_resources(data, dependencies, patches),
              'appExecutionVerified': False}
    if options.hap:
        with zipfile.ZipFile(options.hap) as hap:
            path = 'resources/rawfile/' + relative
            require(hap.getinfo(path).compress_type == zipfile.ZIP_STORED,
                    'HAP must store resource ZIP uncompressed for raw-FD access')
            require(hap.read(path) == data, 'Final HAP SDK differs from verified resource archive')
            require(hap.read(path + '.sha256').decode().strip() == sha256(data),
                    'Final HAP SDK sidecar differs')
            for name in hap.namelist():
                require(not name.endswith(('libqfli_clang.so', 'libqfli-ld.lld-.so',
                                           'libqfli_executor.so', 'ohos-arm64-v8a.zip')),
                        f'Final HAP still includes an unused native process toolchain: {name}')
                require(not name.startswith(('libs/x86_64/', 'libs/armeabi-v7a/')),
                        f'Unverified runtime ABI in HAP: {name}')
            report['runner'] = validate_runner(hap.read('libs/arm64-v8a/libqfli_ohos_runner.so'))
        report['hapSha256'] = sha256(options.hap.read_bytes())
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
