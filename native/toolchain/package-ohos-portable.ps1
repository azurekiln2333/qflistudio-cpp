# Package verified WASI SDK data for the signed in-process LLVM/Wasm interpreter.
# No host executables or generated native executable code are included.
[CmdletBinding()]
param(
    [string]$DependencyDirectory = (Join-Path $PSScriptRoot '../build/portable-deps'),
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '../..'),
    [string]$OutputArchive,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$DependencyDirectory = [IO.Path]::GetFullPath($DependencyDirectory)
if (-not $OutputArchive) {
    $OutputArchive = Join-Path $ProjectRoot 'ohos/entry/src/main/resources/rawfile/qfli_toolchain/ohos-wasi.zip'
}
$OutputArchive = [IO.Path]::GetFullPath($OutputArchive)

# Read data directly from SHA-checked archives, rather than trusting previously
# extracted directories that could have been edited since their initial unpack.
$program = @'
import hashlib, json, os, pathlib, sys, tarfile, uuid, zipfile

root, dependencies, output = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((root / 'native/toolchain/portable-dependencies.json').read_text(encoding='utf-8'))
required = [
    'share/wasi-sysroot/include/wasm32-wasip1/stdio.h',
    'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/vector',
    'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/stdexcept',
    'share/wasi-sysroot/lib/wasm32-wasip1/crt1-command.o',
    'share/wasi-sysroot/lib/wasm32-wasip1/libc.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++abi.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/libsetjmp.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/libwasi-emulated-process-clocks.a',
    'lib/clang/22/include/stddef.h',
    'lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a',
    'share/wasi-sysroot/include/wasm32-wasip1-threads/stdio.h',
    'share/wasi-sysroot/include/wasm32-wasip1-threads/pthread.h',
    'share/wasi-sysroot/include/wasm32-wasip1-threads/eh/c++/v1/vector',
    'share/wasi-sysroot/include/wasm32-wasip1-threads/eh/c++/v1/stdexcept',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/crt1-command.o',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/libc.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/libpthread.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++abi.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libunwind.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/libsetjmp.a',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/libwasi-emulated-process-clocks.a',
    'lib/clang/22/lib/wasm32-unknown-wasip1-threads/libclang_rt.builtins.a',
]
prefixes = (
    'share/wasi-sysroot/include/wasm32-wasip1/',
    'share/wasi-sysroot/lib/wasm32-wasip1/',
    'share/wasi-sysroot/include/wasm32-wasip1-threads/',
    'share/wasi-sysroot/lib/wasm32-wasip1-threads/',
    'lib/clang/22/include/',
    'lib/clang/22/lib/wasm32-unknown-wasip1/',
    'lib/clang/22/lib/wasm32-unknown-wasip1-threads/',
)
licenses = {
    'llvm22': [('LICENSE.TXT', 'LLVM.txt'), ('libcxx/LICENSE.TXT', 'libcxx.txt'),
               ('libcxxabi/LICENSE.TXT', 'libcxxabi.txt')],
    'wasmedge': [('LICENSE', 'WasmEdge.txt')],
    'fmt': [('LICENSE', 'fmt.txt')],
    'spdlog': [('LICENSE', 'spdlog.txt')],
}
archives = {}
for key, spec in manifest.items():
    archive = dependencies / spec['archive']
    with archive.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != spec['sha256']:
        raise RuntimeError(f'{key} archive SHA256 mismatch: {archive}')
    archives[key] = archive

output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_name(output.name + '.' + uuid.uuid4().hex + '.tmp')
records = {}
try:
    with zipfile.ZipFile(temporary, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as package:
        def add_stream(name, stream):
            if name.startswith('/') or '\\' in name or ':' in name or '..' in name.split('/'):
                raise RuntimeError(f'Unsafe resource path: {name}')
            if name in records:
                raise RuntimeError(f'Duplicate resource: {name}')
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            digest, size = hashlib.sha256(), 0
            with package.open(entry, 'w') as destination:
                while data := stream.read(1024 * 1024):
                    digest.update(data)
                    size += len(data)
                    destination.write(data)
            records[name] = {'path': name, 'sha256': digest.hexdigest(), 'size': size}

        sdk_prefix = manifest['wasiSdk']['directory'] + '/'
        with tarfile.open(archives['wasiSdk'], 'r|gz') as source:
            for entry in source:
                if not entry.name.startswith(sdk_prefix):
                    continue
                name = entry.name[len(sdk_prefix):]
                if not name.startswith(prefixes) or '/noeh/' in name or '/llvm-lto/' in name:
                    continue
                if entry.isdir():
                    continue
                if not entry.isfile():
                    raise RuntimeError(f'Unexpected SDK resource link or special file: {entry.name}')
                with source.extractfile(entry) as stream:
                    add_stream(name, stream)
        for name in required:
            if name not in records:
                raise RuntimeError(f'WASI SDK 33 resource is missing: {name}')

        for key, requested in licenses.items():
            pending = dict(requested)
            prefix = manifest[key]['directory'] + '/'
            with tarfile.open(archives[key], 'r|gz') as source:
                for entry in source:
                    relative = entry.name[len(prefix):] if entry.name.startswith(prefix) else ''
                    if relative in pending and entry.isfile():
                        with source.extractfile(entry) as stream:
                            add_stream('licenses/' + pending.pop(relative), stream)
                        if not pending:
                            break
            if pending:
                raise RuntimeError(f'Missing {key} license files: {list(pending)}')

        patches = []
        for path in sorted((root / 'native/portable/patches').glob('*.patch')):
            patches.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        inventory = ''.join(f'{name}\0{records[name]["sha256"]}\n' for name in sorted(records))
        toolchain = {
            'formatVersion': 2, 'llvmVersion': manifest['llvm22']['version'],
            'llvmCommit': manifest['llvm22']['commit'], 'wasiSdkVersion': manifest['wasiSdk']['version'],
            'runtimeCommit': manifest['wasmedge']['commit'], 'runtimePatches': patches,
            'targetTriple': 'wasm32-unknown-wasip1', 'runtime': 'wasmedge-interpreter',
            'supportedTargets': ['wasm32-unknown-wasip1', 'wasm32-unknown-wasip1-threads'],
            'threading': 'wasi-threads', 'maxWorkerThreads': 32,
            'execution': 'interpreter', 'jit': False, 'dependencies': manifest,
            'resourceFileCount': len(records),
            'resourceTreeSha256': hashlib.sha256(inventory.encode()).hexdigest(),
            'resources': [records[name] for name in required],
        }
        package.writestr('toolchain.json', json.dumps(toolchain, indent=2) + '\n')
    with zipfile.ZipFile(temporary) as package:
        invalid = package.testzip()
        if invalid:
            raise RuntimeError(f'ZIP CRC verification failed: {invalid}')
        if any(name.startswith('bin/') or '\\' in name for name in package.namelist()):
            raise RuntimeError('The data package must not contain host executables or backslash paths')
    os.replace(temporary, output)
finally:
    temporary.unlink(missing_ok=True)
with output.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
output.with_name(output.name + '.sha256').write_text(digest + '\n', encoding='ascii')
print(f'Packaged LLVM {toolchain["llvmVersion"]} / WASI SDK {toolchain["wasiSdkVersion"]}, interpreter, JIT disabled')
print(f'Resources: {len(records)} files; ZIP: {output} ({output.stat().st_size / 1048576:.1f} MiB)')
print(f'SHA256: {digest}')
'@
& $Python -c $program $ProjectRoot $DependencyDirectory $OutputArchive
if ($LASTEXITCODE -ne 0) { throw "Portable OHOS packaging failed with exit code $LASTEXITCODE" }
