#!/usr/bin/env python3
"""Export validated native packages without intermediate build directories."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def copy_file(source, destination):
    if not source.is_file() or source.is_symlink():
        raise ValueError(f'Missing regular package file: {source}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def check_zip(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip():
            raise ValueError(f'ZIP CRC validation failed: {path}')
        return json.loads(archive.read('toolchain.json'))


def stage_android(package, stage, abi):
    sdk = package / 'assets/qfli_toolchain' / f'{abi}.zip'
    manifest = check_zip(sdk)
    if (manifest['architecture'] != abi or manifest['llvmVersion'] != '15.0.7'
            or manifest['ndkVersion'] != '27.0.12077973'):
        raise ValueError('Android package versions or architecture do not match')
    if sdk.with_suffix('.zip.sha256').read_text().split()[0] != sha256(sdk):
        raise ValueError('Android resource ZIP checksum mismatch')
    for name in ('libqfli_clang.so', 'libqfli-ld.lld-.so',
                 'libqfli_executor.so', 'libc++_shared.so'):
        relative = Path('jniLibs') / abi / name
        if sha256(package / relative) != manifest['binaryMetadata'][name]['sha256']:
            raise ValueError(f'Android binary checksum mismatch: {name}')
        copy_file(package / relative, stage / relative)
    for source in (sdk, sdk.with_suffix('.zip.sha256')):
        copy_file(source, stage / source.relative_to(package))
    validation = package / 'validation' / abi
    expected = set(manifest['validation']['fixturesCrossLinked']) | {
        'invalid-source.txt', 'unresolved-symbol.txt'}
    for name in expected:
        copy_file(validation / name, stage / 'validation' / abi / name)
    copy_file(package / 'resources' / abi / 'toolchain.json',
              stage / 'manifests' / f'{abi}.json')
    # Each ABI can be extracted into the same directory without overwriting
    # the other ABI's files, manifests, or checksum list.
    (stage / 'README.txt').write_text(
        'Extract this archive into native/build/android-package.\n'
        'The Android Gradle build consumes jniLibs/ and assets/.\n'
        'This is a native dependency package, not an APK.\n'
        'Fixture cross-linking passed; device execution is not verified.\n',
        encoding='utf-8')
    return {'architecture': abi, 'llvmVersion': '15.0.7',
            'ndkVersion': '27.0.12077973', 'deviceExecutionVerified': False}


def stage_ohos_resources(package, stage, verification):
    sdk = package / 'ohos-wasi.zip'
    manifest = check_zip(sdk)
    report = json.loads(verification.read_text(encoding='utf-8'))
    digest = sha256(sdk)
    if (sdk.with_suffix('.zip.sha256').read_text().strip() != digest
            or report['resources']['sha256'] != digest):
        raise ValueError('OHOS resource validation does not match this ZIP')
    if report['appExecutionVerified'] is not False:
        raise ValueError('Resource verification must not claim app execution')
    for source in (sdk, sdk.with_suffix('.zip.sha256')):
        copy_file(source, stage / source.name)
    copy_file(verification, stage / 'verification.json')
    copy_file(ROOT / 'native/toolchain/portable-dependencies.json',
              stage / 'portable-dependencies.json')
    (stage / 'README.txt').write_text(
        'Copy ohos-wasi.zip and ohos-wasi.zip.sha256 into\n'
        'ohos/entry/src/main/resources/rawfile/qfli_toolchain/.\n'
        'This package contains WASI resources only. It does not contain\n'
        'OHOS compiler/runtime archives, the native bridge, or a HAP.\n'
        'App execution is not verified by this resource build.\n',
        encoding='utf-8')
    return {'llvmVersion': manifest['llvmVersion'], 'dataOnly': True,
            'appExecutionVerified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('android', 'ohos-resources'))
    parser.add_argument('--abi', choices=('arm64-v8a', 'x86_64'))
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--verification', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.platform == 'android' and not args.abi:
        parser.error('--abi is required for Android')
    if args.platform == 'ohos-resources' and not args.verification:
        parser.error('--verification is required for OHOS resources')
    name = (f'qfli-native-android-{args.abi}' if args.platform == 'android'
            else 'qfli-ohos-wasi-resources')
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output / f'{name}.tar.gz'
    if output.exists():
        raise ValueError(f'Refusing to overwrite existing artifact: {output}')
    with tempfile.TemporaryDirectory(prefix='ci-package-', dir=args.output.parent) as temporary:
        stage = Path(temporary)
        if args.platform == 'android':
            details = stage_android(args.package, stage, args.abi)
        else:
            details = stage_ohos_resources(args.package, stage, args.verification)
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        dirty = bool(subprocess.check_output(
            ['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True))
        run = os.environ.get('GITHUB_RUN_ID')
        repository = os.environ.get('GITHUB_REPOSITORY')
        record = {'platform': args.platform, 'sourceCommit': commit, 'sourceDirty': dirty,
                  'runId': run, 'runAttempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
                  'runUrl': (f'https://github.com/{repository}/actions/runs/{run}'
                             if repository and run else None),
                  'packagerSha256': sha256(Path(__file__)), **details}
        manifest_path = (stage / 'manifests' / f'build-{args.abi}.json'
                         if args.platform == 'android' else stage / 'build-manifest.json')
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        checksum_name = f'SHA256SUMS-{args.abi}' if args.platform == 'android' else 'SHA256SUMS'
        inventory = ''.join(f'{sha256(path)}  {path.relative_to(stage).as_posix()}\n'
                            for path in sorted(stage.rglob('*')) if path.is_file())
        (stage / checksum_name).write_text(inventory, encoding='ascii')
        with tarfile.open(output, 'w:gz') as archive:
            for path in sorted(stage.iterdir()):
                archive.add(path, arcname=path.name)
    output.with_suffix('.gz.sha256').write_text(f'{sha256(output)}  {output.name}\n', encoding='ascii')
    print(json.dumps({'artifact': str(output), 'bytes': output.stat().st_size,
                      'sha256': sha256(output), **record}, indent=2))


if __name__ == '__main__':
    main()
