import hashlib
import io
import json
import os
import pathlib
import re
import shutil
import subprocess
import tarfile
import tempfile

repo = pathlib.Path('/mnt/d/MyNewProjects/qfli_c')
test = pathlib.Path(tempfile.mkdtemp(prefix='ohos-source-preflight-', dir=repo / 'native/build'))
downloads, build, resources, project = [test / name for name in ('downloads', 'build', 'resources', 'project')]
for path in (downloads, build, resources, project / 'native/toolchain', project / 'native/portable'):
    path.mkdir(parents=True)
shutil.copytree(repo / 'native/portable/patches', project / 'native/portable/patches')
shutil.copyfile(repo / 'native/portable/apply-wasmedge-patch.cmake', project / 'native/portable/apply-wasmedge-patch.cmake')
realdeps = json.loads((repo / 'native/toolchain/portable-dependencies.json').read_text())
files = {}
for patch in (repo / 'native/portable/patches').glob('*.patch'):
    for name in re.findall(r'^--- a/(.+)$', patch.read_text(), re.MULTILINE):
        files[name] = None
with tarfile.open(repo / 'native/build/portable-deps' / realdeps['wasmedge']['archive']) as source:
    for name in files:
        files[name] = source.extractfile(realdeps['wasmedge']['directory'] + '/' + name).read()
deps = {}
for key in ('llvm22', 'wasmedge', 'fmt', 'spdlog'):
    dirname = key + '-source'
    archive = downloads / (key + '.tar.gz')
    entries = files if key == 'wasmedge' else {'README': b'verified test dependency\n'}
    with tarfile.open(archive, 'w:gz') as output:
        if key == 'llvm22':
            entries = {name + '/README': b'test\n' for name in ('llvm', 'clang', 'lld', 'cmake', 'third-party', 'runtimes')}
            entries['LICENSE.TXT'] = b'test license\n'
        for name, data in entries.items():
            info = tarfile.TarInfo(dirname + '/' + name)
            info.size = len(data)
            output.addfile(info, io.BytesIO(data))
    deps[key] = {'archive': archive.name, 'directory': dirname, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
manifest = project / 'native/toolchain/portable-dependencies.json'
manifest.write_text(json.dumps(deps))
sdk = {'llvmVersion': '15.0.7', 'targetTriple': 'aarch64-unknown-linux-ohos'}
for name, record in [('bin/clang', 'compilerMetadata'), ('bin/ld.lld', 'linkerMetadata'), ('lib/aarch64-unknown-linux-ohos/libc++_shared.so', 'runtimeMetadata')]:
    path = resources / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b'verified input ' + name.encode())
    sdk[record] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
for name in ('bin/ohos.cfg', 'sysroot/usr/include/stdio.h', 'include/c++/v1/vector', 'lib/clang/15.0.7/lib/aarch64-unknown-linux-ohos/libclang_rt.builtins.a'):
    path = resources / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('test input\n')
(resources / 'toolchain.json').write_text(json.dumps(sdk))
script = (repo / 'native/toolchain/build-ohos-portable.sh').read_text().split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
command = ['python3', '-c', script, str(manifest), str(downloads), str(build), str(resources), str(project)]
subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
first = (build / 'verified-inputs.json').read_bytes()
subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
assert first == (build / 'verified-inputs.json').read_bytes()
print('PASS clean source verification and repeated preflight', flush=True)

root = build / 'sources/wasmedge-source'
env = dict(os.environ, GIT_CEILING_DIRECTORIES=str(root.parent))
subprocess.run(['git', 'apply', '--reverse', str(project / 'native/portable/patches/wasmedge-shared-memory-growth.patch')], cwd=root, env=env, check=True)
namespace = {}
exec(script[script.index('def digest_tree(root):'):script.index("sources = build / 'sources'")], {'hashlib': hashlib}, namespace)
marker = build / 'sources/wasmedge.tree-sha256'
marker.write_text(namespace['digest_tree'](root) + '\n')
old = marker.read_text()
subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
assert marker.read_text() != old
assert marker.read_text().strip() == namespace['digest_tree'](root)
assert json.loads((build / 'verified-inputs.json').read_text())['sourceDigests']['wasmedge'] == marker.read_text().strip()
print('PASS verified older source receives new patch and matching digest', flush=True)
(root / 'include/runtime/instance/memory.h').write_text('unrelated user edit\n')
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
assert result.returncode and b'Source tree changed' in result.stderr
assert (root / 'include/runtime/instance/memory.h').read_text() == 'unrelated user edit\n'
print('PASS source drift rejected without changing user edit', flush=True)
print(test)
