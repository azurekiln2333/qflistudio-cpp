import copy
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parents[3]
script = root / 'native/toolchain/package-ohos-portable.ps1'
original = root / 'ohos/entry/src/main/resources/rawfile/qfli_toolchain/ohos-wasi.zip'
before = hashlib.sha256(original.read_bytes()).hexdigest()
work = Path(tempfile.mkdtemp(prefix='ohos-package-negative-', dir=root / 'native/build'))
base = json.loads((root / 'native/toolchain/portable-dependencies.json').read_text())
required = [
    'share/wasi-sysroot/include/wasm32-wasip1/stdio.h',
    'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/vector',
    'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/stdexcept',
    'share/wasi-sysroot/lib/wasm32-wasip1/crt1-command.o',
    'share/wasi-sysroot/lib/wasm32-wasip1/libc.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++abi.a',
    'share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a',
    'lib/clang/22/include/stddef.h',
    'lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a',
]
for case, expected in [
    ('hash', 'archive SHA256 mismatch'),
    ('missing', 'WASI SDK 33 resource is missing'),
    ('traversal', 'Unsafe resource path'),
    ('link', 'Unexpected SDK resource link or special file'),
]:
    project = work / case
    data = project / 'deps'
    data.mkdir(parents=True)
    manifest = copy.deepcopy(base)
    for key, spec in manifest.items():
        archive = data / spec['archive']
        with tarfile.open(archive, 'w:gz') as output:
            if key == 'wasiSdk':
                names = required[:-1] if case == 'missing' else required
                for name in names:
                    entry = tarfile.TarInfo(spec['directory'] + '/' + name)
                    content = name.encode()
                    entry.size = len(content)
                    output.addfile(entry, io.BytesIO(content))
                if case in ('traversal', 'link'):
                    suffix = 'share/wasi-sysroot/include/wasm32-wasip1/../escape'
                    entry = tarfile.TarInfo(spec['directory'] + '/' + suffix)
                    if case == 'link':
                        entry.type = tarfile.SYMTYPE
                        entry.linkname = '/outside/workspace'
                        output.addfile(entry)
                    else:
                        entry.size = 4
                        output.addfile(entry, io.BytesIO(b'fail'))
        spec['sha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
    if case == 'hash':
        manifest['wasiSdk']['sha256'] = '0' * 64
    manifest_path = project / 'native/toolchain/portable-dependencies.json'
    manifest_path.parent.mkdir(parents=True)
    manifest_path.write_text(json.dumps(manifest))
    destination = project / 'output.zip'
    destination.write_bytes(b'existing reviewable package')
    result = subprocess.run(['pwsh', '-NoProfile', '-File', str(script), '-ProjectRoot', str(project),
                             '-DependencyDirectory', str(data), '-OutputArchive', str(destination)],
                            capture_output=True, text=True, encoding='utf-8', errors='replace')
    assert result.returncode != 0, (case, result.stdout, result.stderr)
    assert expected in result.stdout + result.stderr, (case, result.stdout, result.stderr)
    assert destination.read_bytes() == b'existing reviewable package', case
    assert not list(project.glob('output.zip.*.tmp')), case
    print('PASS', case, '- rejects before replacing the existing package')
assert hashlib.sha256(original.read_bytes()).hexdigest() == before
print('PASS original signed-HAP resource input unchanged:', before)
print('Artifacts:', work)
