import hashlib
import json
import os
import pathlib
import re
import subprocess
import tarfile
import tempfile

repo = pathlib.Path('/mnt/d/MyNewProjects/qfli_c')
test = pathlib.Path(tempfile.mkdtemp(prefix='ohos-memory-patch-', dir=repo / 'native/build'))
deps = json.loads((repo / 'native/toolchain/portable-dependencies.json').read_text())
record = deps['wasmedge']
archive = repo / 'native/build/portable-deps' / record['archive']
assert hashlib.sha256(archive.read_bytes()).hexdigest() == record['sha256']
patchdir = repo / 'native/portable/patches'
files = set()
for patch in patchdir.glob('*.patch'):
    files.update(re.findall(r'^--- a/(.+)$', patch.read_text(), flags=re.MULTILINE))
with tarfile.open(archive, 'r:gz') as source:
    for name in files:
        item = source.extractfile(record['directory'] + '/' + name)
        assert item, name
        dest = test / record['directory'] / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(item.read())
root = test / record['directory']
script = repo / 'native/portable/apply-wasmedge-patch.cmake'
command = ['cmake', '-DQFLI_WASMEDGE_SOURCE=' + str(root), '-P', str(script)]
subprocess.run(command, check=True)
before = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
subprocess.run(command, check=True)
after = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
assert before == after
print('PASS fresh application and idempotent reapplication', flush=True)

# An unrelated difference in a changed hunk must fail instead of being hidden.
memory = root / 'include/runtime/instance/memory.h'
memory.write_text(memory.read_text().replace('uint64_t *OldPageCount = nullptr', 'uint64_t *UnknownPageCount = nullptr'))
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
assert result.returncode and b'source does not match wasmedge-shared-memory-growth.patch' in result.stderr, result.stderr
print('PASS changed source rejection', flush=True)

# Run a copied applicator against a changed patch, preserving repository bytes.
scriptcopy = test / 'applicator'
scriptcopy.mkdir()
(scriptcopy / 'patches').mkdir()
(scriptcopy / script.name).write_bytes(script.read_bytes())
for patch in patchdir.glob('*.patch'):
    data = patch.read_bytes()
    if patch.name == 'wasmedge-shared-memory-growth.patch':
        data += b'\n'
    (scriptcopy / 'patches' / patch.name).write_bytes(data)
result = subprocess.run(['cmake', '-DQFLI_WASMEDGE_SOURCE=' + str(root), '-P', str(scriptcopy / script.name)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
assert result.returncode and b'SHA256 mismatch' in result.stderr, result.stderr
print('PASS changed patch rejection', flush=True)
print(test)
