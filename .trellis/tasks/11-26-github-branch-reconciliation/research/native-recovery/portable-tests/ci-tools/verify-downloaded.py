import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('folder', type=Path)
parser.add_argument('--commit', required=True)
parser.add_argument('--run', required=True)
args = parser.parse_args()
records = []
for archive in sorted(args.folder.glob('*.tar.gz')):
    with archive.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    assert digest == archive.with_suffix('.gz.sha256').read_text().split()[0], archive
    output = args.folder / 'unpacked'
    if output.exists():
        raise ValueError('Choose a new download directory for validation')
    with tarfile.open(archive) as source:
        for entry in source:
            path = PurePosixPath(entry.name)
            if path.is_absolute() or '..' in path.parts or ':' in entry.name or '\\' in entry.name:
                raise ValueError('Unsafe archive path: ' + entry.name)
            if not entry.isfile() and not entry.isdir():
                raise ValueError('Nonregular archive entry: ' + entry.name)
        source.extractall(output, filter='data')
    count = 0
    for inventory in output.glob('SHA256SUMS*'):
        for line in inventory.read_text().splitlines():
            expected, relative = line.split('  ', 1)
            path = output / relative
            with path.open('rb') as source:
                actual = hashlib.file_digest(source, 'sha256').hexdigest()
            assert actual == expected, relative
            count += 1
    assert count > 0
    manifests = list(output.glob('ci-build-manifest.json')) + list(output.glob('manifests/build-*.json'))
    assert len(manifests) == 1
    manifest = json.loads(manifests[0].read_text())
    assert manifest['sourceCommit'] == args.commit
    assert str(manifest['runId']) == args.run
    assert manifest['sourceDirty'] is False
    for sdk in output.rglob('*.zip'):
        with zipfile.ZipFile(sdk) as source:
            assert source.testzip() is None
            metadata = json.loads(source.read('toolchain.json'))
        if manifest['platform'] == 'android':
            abi = manifest['architecture']
            assert metadata['architecture'] == abi
            for name, spec in metadata['binaryMetadata'].items():
                path = output / 'jniLibs' / abi / name
                with path.open('rb') as source:
                    assert hashlib.file_digest(source, 'sha256').hexdigest() == spec['sha256']
            assert len(metadata['validation']['fixturesCrossLinked']) == 8
    if manifest['platform'] == 'ohos':
        report = json.loads((output / 'native/build/ohos-portable/package/validation/native-validation.json').read_text())
        assert report['bridgeLinked'] is True
        assert report['appExecutionVerified'] is False
    if manifest['platform'] == 'ios':
        report = json.loads((output / 'manifests/assembly.json').read_text())
        assert report['xcframeworkVerified'] is True
        assert report['nativeLinkVerified'] is True
        assert len(report['slices']) == 3
    records.append({'archive': archive.name, 'bytes': archive.stat().st_size,
                    'sha256': digest, 'inventoryFilesVerified': count,
                    'manifest': manifest, 'downloadVerified': True})
assert records
text = json.dumps(records, indent=2)
(args.folder / 'verification-local.json').write_text(text + '\n')
print(text)
