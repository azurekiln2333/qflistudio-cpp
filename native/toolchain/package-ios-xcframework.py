#!/usr/bin/env python3
"""Record an iOS slice, or assemble three verified slices on a macOS host."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


SLICES = {'iphoneos-arm64': ('iphoneos', 'arm64'),
          'iphonesimulator-arm64': ('iphonesimulator', 'arm64'),
          'iphonesimulator-x86_64': ('iphonesimulator', 'x86_64')}


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def files(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Package must not contain symbolic links: {path}')
        if path.is_file():
            result[path.relative_to(root).as_posix()] = sha256(path)
    if not result:
        raise ValueError(f'Package directory is empty: {root}')
    return result


def tree_sha256(root):
    return hashlib.sha256(json.dumps(files(root), sort_keys=True).encode()).hexdigest()


def command(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()


def verify_arches(library, expected):
    actual = set(command('xcrun', 'lipo', '-archs', library).split())
    if actual != set(expected):
        raise ValueError(f'{library} architectures {actual} do not match {expected}')


def record(package, requested, repo):
    selected = [requested] if requested in SLICES else [
        name for name, (platform, _) in SLICES.items() if (package / platform).is_dir()]
    if not selected:
        raise ValueError('No iOS static slices were built')
    libraries = {}
    for platform in sorted({SLICES[name][0] for name in selected}):
        relative = f'{platform}/libqfli_portable.a'
        verify_arches(package / relative, [SLICES[name][1] for name in selected
                                          if SLICES[name][0] == platform])
        libraries[relative] = sha256(package / relative)
    for name in selected:
        if not (package / 'validation' / name / 'link-check.txt').is_file():
            raise ValueError(f'Missing native link validation: {name}')
    manifest = {
        'platform': 'ios', 'slices': selected, 'libraries': libraries,
        'sourceCommit': command('git', '-C', repo, 'rev-parse', 'HEAD'),
        'sourceDirty': bool(command('git', '-C', repo, 'status', '--porcelain', '--untracked-files=no')),
        'runId': os.environ.get('GITHUB_RUN_ID'),
        'xcode': command('xcodebuild', '-version'),
        'sdkVersions': {platform: command('xcrun', '--sdk', platform, '--show-sdk-version')
                        for platform in ('iphoneos', 'iphonesimulator')},
        'deploymentTarget': '13.0',
        'resourcesSha256': tree_sha256(package / 'resources'),
        'headersSha256': tree_sha256(package / 'include'),
        'dependencies': json.loads((repo / 'native/toolchain/portable-dependencies.json').read_text()),
        'adapterSources': {str(path.relative_to(repo)).replace('\\', '/'): sha256(path)
                           for path in (repo / 'native/compiler/compiler.cpp',
                                        repo / 'native/compiler/compiler_analysis.inc',
                                        repo / 'native/compiler/include/qfli_code_analysis.h',
                                        repo / 'native/portable/wasm_runtime.cpp')},
        'runtimePatches': {path.name: sha256(path) for path in
                           sorted((repo / 'native/portable/patches').glob('*.patch'))},
        'nativeLinkVerified': True, 'appExecutionVerified': False,
    }
    (package / 'manifests').mkdir(exist_ok=True)
    (package / 'manifests/slice.json').write_text(json.dumps(manifest, indent=2) + '\n')


def assemble(directories, output):
    if output.exists():
        raise ValueError(f'Refusing to overwrite an existing package: {output}')
    records = {}
    packages = {}
    contract = None
    for directory in directories:
        item = json.loads((directory / 'manifests/slice.json').read_text())
        if len(item.get('slices', [])) != 1 or item['slices'][0] not in SLICES:
            raise ValueError(f'Expected one recognized iOS slice in {directory}')
        name = item['slices'][0]
        if name in records:
            raise ValueError(f'Duplicate iOS slice: {name}')
        platform, arch = SLICES[name]
        relative = f'{platform}/libqfli_portable.a'
        if (item['libraries'].get(relative) != sha256(directory / relative)
                or item['resourcesSha256'] != tree_sha256(directory / 'resources')
                or item['headersSha256'] != tree_sha256(directory / 'include')):
            raise ValueError(f'iOS slice checksum mismatch: {name}')
        if item.get('nativeLinkVerified') is not True or item.get('appExecutionVerified') is not False:
            raise ValueError(f'Unexpected validation claim: {name}')
        verify_arches(directory / relative, [arch])
        identity = {key: item[key] for key in (
            'sourceCommit', 'sourceDirty', 'runId', 'xcode', 'sdkVersions',
            'deploymentTarget', 'resourcesSha256', 'headersSha256',
            'dependencies', 'adapterSources', 'runtimePatches')}
        if contract is not None and identity != contract:
            raise ValueError('iOS slices must have the same commit, SDK, dependencies and patches')
        contract = identity
        records[name], packages[name] = item, directory
    if set(records) != set(SLICES):
        raise ValueError(f'Required iOS slices: {sorted(SLICES)}; received: {sorted(records)}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ios-assembly-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'package'
        stage.mkdir()
        first = packages['iphoneos-arm64']
        for name in ('include', 'resources'):
            shutil.copytree(first / name, stage / name)
        (stage / 'iphoneos').mkdir()
        (stage / 'iphonesimulator').mkdir()
        (stage / 'manifests/slices').mkdir(parents=True)
        shutil.copyfile(first / 'iphoneos/libqfli_portable.a', stage / 'iphoneos/libqfli_portable.a')
        command('xcrun', 'lipo', '-create',
                packages['iphonesimulator-arm64'] / 'iphonesimulator/libqfli_portable.a',
                packages['iphonesimulator-x86_64'] / 'iphonesimulator/libqfli_portable.a',
                '-output', stage / 'iphonesimulator/libqfli_portable.a')
        verify_arches(stage / 'iphoneos/libqfli_portable.a', ['arm64'])
        verify_arches(stage / 'iphonesimulator/libqfli_portable.a', ['arm64', 'x86_64'])
        command('xcodebuild', '-create-xcframework',
                '-library', stage / 'iphoneos/libqfli_portable.a', '-headers', stage / 'include',
                '-library', stage / 'iphonesimulator/libqfli_portable.a', '-headers', stage / 'include',
                '-output', stage / 'QfliPortable.xcframework')
        with (stage / 'QfliPortable.xcframework/Info.plist').open('rb') as source:
            framework = plistlib.load(source)
        actual = {(item['SupportedPlatform'], item.get('SupportedPlatformVariant', ''),
                   tuple(sorted(item['SupportedArchitectures'])))
                  for item in framework['AvailableLibraries']}
        expected = {('ios', '', ('arm64',)), ('ios', 'simulator', ('arm64', 'x86_64'))}
        if actual != expected:
            raise ValueError(f'Unexpected XCFramework platforms: {actual}')
        for name, item in records.items():
            (stage / 'manifests/slices' / f'{name}.json').write_text(json.dumps(item, indent=2) + '\n')
            shutil.copytree(packages[name] / 'validation' / name, stage / 'validation' / name)
        result = {'platform': 'ios', 'slices': sorted(records), **contract,
                  'libraries': {str(path.relative_to(stage)).replace('\\', '/'): sha256(path)
                                for path in stage.rglob('*.a')
                                if 'resources' not in path.relative_to(stage).parts},
                  'nativeLinkVerified': True, 'xcframeworkVerified': True,
                  'appExecutionVerified': False}
        (stage / 'manifests/assembly.json').write_text(json.dumps(result, indent=2) + '\n')
        (stage / 'README.txt').write_text(
            'Extract into native/build/ios-portable/package.\n'
            'From the repository root on your Mac, run:\n'
            'python3 native/toolchain/install-ios-package.py --package native/build/ios-portable/package\n'
            'This writes the local Flutter xcconfig. Do not use a CI runner absolute path.\n'
            'Contains device ARM64, simulator ARM64/x86_64, XCFramework and WASI resources.\n'
            'Native link validation passed. App/device execution is not verified.\n')
        stage.replace(output)
    print(json.dumps({'package': str(output), 'slices': sorted(records)}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest='command', required=True)
    build = subparsers.add_parser('record')
    build.add_argument('--package', type=Path, required=True)
    build.add_argument('--slice', required=True, choices=['all', *SLICES])
    build.add_argument('--repo', type=Path, required=True)
    merge = subparsers.add_parser('assemble')
    merge.add_argument('--slice-dir', type=Path, action='append', required=True)
    merge.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'record':
        record(args.package.resolve(), args.slice, args.repo.resolve())
    else:
        assemble([path.resolve() for path in args.slice_dir], args.output.resolve())


if __name__ == '__main__':
    main()
