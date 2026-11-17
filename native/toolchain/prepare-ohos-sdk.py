#!/usr/bin/env python3
"""Fetch the pinned public OHOS SDK; retain ARM64 cross-build data only."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import tarfile
import tempfile
import zipfile


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--archive', type=Path,
                        help='Reuse a local copy of the exact pinned public archive')
    args = parser.parse_args()
    spec = json.loads(Path(__file__).with_name('ohos-sdk-dependency.json').read_text())
    output = args.output.resolve()
    if output.exists():
        raise SystemExit(f'Choose a fresh SDK output directory: {output}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ohos-sdk-', dir=output.parent) as temporary:
        temporary = Path(temporary)
        archive = args.archive or temporary / spec['archive']
        if args.archive is None:
            subprocess.run(['curl', '--fail', '--location', '--retry', '3',
                            '--connect-timeout', '30', '--max-time', '1800',
                            '--output', str(archive), spec['url']], check=True)
        if sha256(archive) != spec['sha256']:
            raise SystemExit('Public OHOS SDK archive checksum mismatch')
        native_zip = temporary / 'native.zip'
        with tarfile.open(archive, 'r|gz') as source:
            for member in source:
                if member.name == spec['nativeMember']:
                    if not member.isfile():
                        raise SystemExit('Native SDK member is not a regular file')
                    with source.extractfile(member) as stream, native_zip.open('wb') as target:
                        shutil.copyfileobj(stream, target)
                    break
            else:
                raise SystemExit('Public archive does not contain the pinned Linux native SDK')
        if sha256(native_zip) != spec['nativeSha256']:
            raise SystemExit('Native SDK ZIP checksum mismatch')
        stage = temporary / 'staged'
        prefixes = ('native/sysroot/', 'native/llvm/include/libcxx-ohos/',
                    'native/llvm/lib/aarch64-linux-ohos/',
                    'native/llvm/lib/clang/15.0.4/include/',
                    'native/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos/')
        exact = {'native/oh-uni-package.json', 'native/NOTICE.txt', 'native/llvm/NOTICE'}
        with zipfile.ZipFile(native_zip) as source:
            for member in source.infolist():
                if not member.filename.startswith(prefixes) and member.filename not in exact:
                    continue
                path = PurePosixPath(member.filename)
                if path.is_absolute() or '..' in path.parts or '\\' in member.filename or ':' in member.filename:
                    raise SystemExit(f'Unsafe SDK path: {member.filename}')
                if member.is_dir():
                    continue
                mode = member.external_attr >> 16
                if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                    raise SystemExit(f'SDK data must be a regular file: {member.filename}')
                destination = stage.joinpath(*path.parts)
                destination.parent.mkdir(parents=True, exist_ok=True)
                with source.open(member) as stream, destination.open('wb') as target:
                    shutil.copyfileobj(stream, target)
        metadata = json.loads((stage / 'native/oh-uni-package.json').read_text())
        if (metadata['version'] != spec['version'] or metadata['apiVersion'] != spec['apiVersion']):
            raise SystemExit('Extracted SDK version does not match the pinned input')
        (stage / 'native/qfli-sdk-provenance.json').write_text(json.dumps(spec, indent=2) + '\n')
        stage.rename(output)
    print(json.dumps({'nativeSdk': str(output / 'native'), **spec}, indent=2))


if __name__ == '__main__':
    main()
