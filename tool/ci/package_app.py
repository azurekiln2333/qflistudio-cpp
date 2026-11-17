"""Package and verify application builds for the CI download artifacts."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APP_NAME = 'QFLIForge'
APP_ID = 'com.azurekiln.qfli.forge'
BINARY_NAME = 'qfli_c'
DEB_PACKAGE = 'qfli-forge'
HOMEPAGE = 'https://github.com/azurekiln2333/qflistudio-cpp'

DEFAULT_INPUTS = {
    'android': 'build/app/outputs/flutter-apk/app-release.apk',
    'windows': 'build/windows/x64/runner/Release',
    'linux': 'build/linux/x64/release/bundle',
    'macos': f'build/macos/Build/Products/Release/{APP_NAME}.app',
    'ios': 'build/ios/archive/Runner.xcarchive',
}
ARCHITECTURES = {'windows': 'x64', 'linux': 'x64', 'macos': 'universal', 'ios': 'arm64'}
SIGNING = {
    'android': 'ephemeral debug key',
    'windows': 'unsigned',
    'linux': 'unsigned',
    'macos': 'ad hoc',
    'ios': 'unsigned',
}
ANDROID_ABIS = ['arm64-v8a', 'x86_64']
ANDROID_LIBRARIES = [
    'libflutter.so', 'libapp.so', 'libqfli_clang.so', 'libqfli-ld.lld-.so',
    'libqfli_executor.so', 'libc++_shared.so',
]
WINDOWS_REQUIRED = [
    f'{BINARY_NAME}.exe', 'flutter_windows.dll', 'data/app.so',
    'data/flutter_assets/AssetManifest.bin',
]
INSTALLER_FILES = {'LICENSE.txt', 'unins000.exe', 'unins000.dat'}
SILENT = ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART']
LINUX_REQUIRED = [BINARY_NAME, 'lib/libflutter_linux_gtk.so', 'lib/libapp.so']
DEB_DEPENDS = 'libgtk-3-0t64 | libgtk-3-0, libstdc++6'
DEB_MAINTAINER = f'{APP_NAME} CI <noreply@github.com>'
CONTROL_FIELDS = ['Package', 'Version', 'Architecture', 'Maintainer', 'Depends', 'Homepage']
# Sizes that the hicolor icon theme declares for application icons.
HICOLOR_SIZES = {16, 22, 24, 32, 36, 48, 64, 72, 96, 128, 192, 256, 512}
IOS_APP = 'Payload/Runner.app/'
IOS_REQUIRED = [
    'Runner', 'Info.plist', 'Frameworks/App.framework/App',
    'Frameworks/Flutter.framework/Flutter', 'forge-wasi-sdk/toolchain.json',
]

_UNTESTED = 'Device or UI execution was not tested.'
_HOST_COMPILER = 'The application needs a host clang or gcc on PATH to compile programs.'
SIGNING_NOTES = {
    'android': [
        'Signing: ephemeral debug key.',
        'Each CI run creates a new key. An update over an earlier CI build fails: uninstall first.',
        'Not for store upload.',
        _UNTESTED,
    ],
    'windows': [
        'Signing: unsigned.',
        'Windows SmartScreen can warn before the installer starts.',
        _HOST_COMPILER,
        _UNTESTED,
    ],
    'linux': [
        'Signing: unsigned.',
        'The package was built and checked on Ubuntu 24.04.',
        _HOST_COMPILER,
        _UNTESTED,
    ],
    'macos': [
        'Signing: ad hoc.',
        'Not notarized. Gatekeeper asks on first start.',
        _HOST_COMPILER,
        _UNTESTED,
    ],
    'ios': [
        'Signing: unsigned.',
        'Sign with an Apple identity and profile before installation.',
        _UNTESTED,
    ],
}


class PackageError(Exception):
    """A missing build input or a failed package check."""


# Pure functions (unit tested in test_ci_helpers.py).

def application_version(pubspec_text):
    match = re.search(r'^version:\s*(\S+)\s*$', pubspec_text, re.MULTILINE)
    if not match:
        raise PackageError('pubspec.yaml has no application version')
    return match.group(1)


def _version_parts(version):
    match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', version)
    if not match:
        raise PackageError(f'Application version is not numeric: {version}')
    return match.groups()


def debian_version(version):
    """Map a pubspec version such as 1.2.3+4 to the Debian form 1.2.3-4."""
    _version_parts(version)
    return version.replace('+', '-')


def windows_file_version(version):
    """Map a pubspec version such as 1.2.3+4 to the numeric form 1.2.3.4."""
    return '.'.join(part or '0' for part in _version_parts(version))


def signing_note(platform):
    return '\n'.join(SIGNING_NOTES[platform]) + '\n'


def check_apk_names(names, abi):
    """Check the entry names of an APK. Return the names of the passed checks."""
    names = set(names)
    abis = {name.split('/')[1] for name in names if name.startswith('lib/') and name.count('/') >= 2}
    if abis != {abi}:
        raise PackageError(f'APK lib/ must hold exactly {abi}, found {sorted(abis)}')
    missing = [library for library in ANDROID_LIBRARIES if f'lib/{abi}/{library}' not in names]
    if missing:
        raise PackageError(f'APK lacks lib/{abi} libraries: {missing}')
    asset = f'assets/qfli_toolchain/{abi}.zip'
    if asset not in names:
        raise PackageError(f'APK lacks {asset}')
    return ['apk-single-abi', 'apk-flutter-libraries', 'apk-native-toolchain-libraries',
            'apk-toolchain-asset']


def check_ipa_names(names):
    """Check the entry names of an IPA. Return the names of the passed checks."""
    names = set(names)
    outside = sorted(name for name in names if not name.startswith('Payload/'))
    if outside:
        raise PackageError(f'IPA has entries outside Payload/: {outside[:10]}')
    missing = [required for required in IOS_REQUIRED if IOS_APP + required not in names]
    if missing:
        raise PackageError(f'IPA lacks Runner.app entries: {missing}')
    if IOS_APP + 'embedded.mobileprovision' in names:
        raise PackageError('IPA is labelled unsigned but holds embedded.mobileprovision')
    return ['ipa-payload-only', 'ipa-application-executable', 'ipa-flutter-frameworks',
            'ipa-wasi-sdk-resources', 'ipa-no-provisioning-profile']


def check_xcarchive_names(names, top):
    """Check that the archive ZIP holds the application under its parent folder."""
    required = f'{top}/Products/Applications/Runner.app/Runner'
    if required not in set(names):
        raise PackageError(f'Archive ZIP lacks {required}')
    return ['xcarchive-zip-application']


def expected_installed_files(source_files):
    """Return the relative files that the Windows installer must write."""
    return set(source_files) | INSTALLER_FILES


def check_installed_files(source_files, installed_files):
    expected = expected_installed_files(source_files)
    installed = set(installed_files)
    if installed != expected:
        raise PackageError(
            f'Installed files differ: missing {sorted(expected - installed)[:10]}, '
            f'unexpected {sorted(installed - expected)[:10]}')
    return len(installed)


def check_archive_names(names, top, source_files):
    """Check that an archive holds exactly the source files under one top folder."""
    expected = {f'{top}/{name}' for name in source_files}
    actual = set(names)
    if actual != expected:
        raise PackageError(
            f'Archive content differs: missing {sorted(expected - actual)[:10]}, '
            f'unexpected {sorted(actual - expected)[:10]}')
    return len(actual)


def check_macos_archs(lipo_output):
    archs = set(lipo_output.split())
    if not {'arm64', 'x86_64'} <= archs:
        raise PackageError(f'Application is not universal: lipo reports {sorted(archs)}')
    return sorted(archs)


def check_ldd_output(binary, output):
    if 'not found' in output:
        raise PackageError(f'{binary} has unresolved shared libraries:\n{output}')


def png_size(data):
    """Read the pixel size from the IHDR chunk of a PNG file."""
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise PackageError('Application icon is not a PNG file')
    return struct.unpack('>II', data[16:24])


def icon_install_path(width, height):
    """Return the package path of the icon. The icon is never resized."""
    if width == height and width in HICOLOR_SIZES:
        return f'usr/share/icons/hicolor/{width}x{height}/apps/{APP_ID}.png'
    return f'usr/share/pixmaps/{APP_ID}.png'


def control_file(version, installed_kib=None):
    """Return DEBIAN/control for a pubspec version."""
    lines = [
        f'Package: {DEB_PACKAGE}',
        f'Version: {debian_version(version)}',
        'Architecture: amd64',
        f'Maintainer: {DEB_MAINTAINER}',
    ]
    if installed_kib is not None:
        lines.append(f'Installed-Size: {installed_kib}')
    lines += [
        f'Depends: {DEB_DEPENDS}',
        'Section: devel',
        'Priority: optional',
        f'Homepage: {HOMEPAGE}',
        f'Description: {APP_NAME} C and C++ IDE',
        ' Editor, terminal and lessons for C and C++ programs.',
        ' The application calls a host clang or gcc to compile programs.',
    ]
    return '\n'.join(lines) + '\n'


def parse_control_fields(text):
    """Parse the `Name: value` lines of a control file or of dpkg-deb --field."""
    fields = {}
    for line in text.splitlines():
        name, separator, value = line.partition(':')
        if separator and not line.startswith(' '):
            fields[name] = value.strip()
    return fields


def check_control_fields(fields, version):
    expected = {
        'Package': DEB_PACKAGE,
        'Version': debian_version(version),
        'Architecture': 'amd64',
        'Maintainer': DEB_MAINTAINER,
        'Depends': DEB_DEPENDS,
        'Homepage': HOMEPAGE,
    }
    actual = {name: fields.get(name) for name in expected}
    if actual != expected:
        raise PackageError(f'Unexpected package fields: {actual}, expected {expected}')


def desktop_entry():
    return (
        '[Desktop Entry]\n'
        'Type=Application\n'
        f'Name={APP_NAME}\n'
        'Comment=C and C++ IDE\n'
        f'Exec={DEB_PACKAGE}\n'
        f'Icon={APP_ID}\n'
        'Terminal=false\n'
        'Categories=Development;IDE;\n'
    )


def provenance(environment, platform, architecture, version, packages, validation, native_input=None):
    """Build the provenance record. `environment` is a mapping such as os.environ."""
    server = environment.get('GITHUB_SERVER_URL')
    repository = environment.get('GITHUB_REPOSITORY')
    run_id = environment.get('GITHUB_RUN_ID')
    run_url = f'{server}/{repository}/actions/runs/{run_id}' if server and repository and run_id else None
    return {
        'applicationCommit': environment.get('GITHUB_SHA'),
        'repository': repository,
        'runId': run_id,
        'runUrl': run_url,
        'coreCommit': environment.get('CORE_REVISION'),
        'flutterCommit': environment.get('FLUTTER_REVISION'),
        'platform': platform,
        'architecture': architecture,
        'applicationVersion': version,
        'signing': SIGNING[platform],
        'nativeInput': native_input,
        'packages': list(packages),
        'validation': list(validation),
        'deviceRuntimeVerified': False,
    }


def checksum_lines(packages):
    return ''.join(f'{package["sha256"]}  {package["file"]}\n' for package in packages)


# File and process helpers.

def run(command, **options):
    command = [str(part) for part in command]
    print('+ ' + ' '.join(command), flush=True)
    return subprocess.run(command, check=True, **options)


def output_of(command):
    command = [str(part) for part in command]
    print('+ ' + ' '.join(command), flush=True)
    return subprocess.check_output(command, text=True)


@contextlib.contextmanager
def workspace():
    directory = tempfile.mkdtemp(prefix='qfli-package-', dir=os.environ.get('RUNNER_TEMP'))
    try:
        yield Path(directory)
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def write_text(path, text):
    # Write bytes: text mode on Windows would store CRLF in the checksum file.
    Path(path).write_bytes(text.encode('utf-8'))


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def files_under(root):
    """Return the relative names of the files and links below a directory."""
    return {path.relative_to(root).as_posix() for path in Path(root).rglob('*')
            if path.is_symlink() or path.is_file()}


def require_files(root, relatives):
    for relative in relatives:
        if not (root / relative).is_file():
            raise PackageError(f'Incomplete application build: {root / relative}')


def write_records(output, platform, architecture, version, targets, validation, native_input=None):
    """Write SHA256SUMS, SIGNING.txt, provenance.json and LICENSE beside the package files."""
    packages = [
        {'file': target.name, 'sha256': sha256(target), 'size': target.stat().st_size}
        for target in targets
    ]
    record = provenance(os.environ, platform, architecture, version, packages, validation, native_input)
    write_text(output / 'SHA256SUMS', checksum_lines(packages))
    write_text(output / 'SIGNING.txt', signing_note(platform))
    write_text(output / 'provenance.json', json.dumps(record, indent=2) + '\n')
    shutil.copyfile(ROOT / 'LICENSE', output / 'LICENSE')
    print(json.dumps(record, indent=2))
    return record


# Android.

def package_android(source, output, abi):
    if not source.is_file():
        raise PackageError(f'Application build is missing: {source}')
    try:
        with zipfile.ZipFile(source) as archive:
            validation = check_apk_names(archive.namelist(), abi)
    except zipfile.BadZipFile as error:
        raise PackageError(f'Application build is not an APK: {source}: {error}') from error
    target = output / f'qfli-forge-android-{abi}-test-signed.apk'
    shutil.copyfile(source, target)
    return [target], validation


# Windows.

def find_iscc():
    """Find ISCC.exe in the Inno Setup 6 directories, then on PATH."""
    candidates = []
    for variable in ['ProgramFiles(x86)', 'ProgramFiles']:
        if os.environ.get(variable):
            candidates.append(Path(os.environ[variable]) / 'Inno Setup 6' / 'ISCC.exe')
    candidates.append(shutil.which('ISCC'))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    raise PackageError('Inno Setup 6 (ISCC.exe) is not installed on this runner')


def build_windows_setup(source, output, version):
    target = output / 'qfli-forge-windows-x64-setup.exe'
    target.unlink(missing_ok=True)
    # Start ISCC from Python: Git Bash rewrites arguments such as /DName as paths.
    run([
        find_iscc(), '/Q',
        f'/DAppVersion={version}',
        f'/DFileVersion={windows_file_version(version)}',
        f'/DBundleDir={source}',
        f'/DOutputDir={output}',
        f'/DOutputBaseFilename={target.stem}',
        f'/DLicenseFile={ROOT / "LICENSE"}',
        ROOT / 'tool/ci/windows_installer.iss',
    ])
    if not target.is_file():
        raise PackageError(f'Inno Setup did not write {target}')
    return target


def verify_windows_setup(setup, source):
    """Install silently, compare the file list and uninstall."""
    with workspace() as directory:
        install = directory / 'app'
        log = directory / 'install.log'
        try:
            run([setup, *SILENT, f'/DIR={install}', f'/LOG={log}'], timeout=1800)
        except subprocess.SubprocessError:
            if log.is_file():
                print('\n'.join(log.read_text(errors='replace').splitlines()[-60:]))
            raise
        check_installed_files(files_under(source), files_under(install))
        executable = install / f'{BINARY_NAME}.exe'
        run([install / 'unins000.exe', *SILENT], timeout=1800)
        # The uninstaller continues in a temporary copy of itself.
        deadline = time.monotonic() + 300
        while executable.exists() and time.monotonic() < deadline:
            time.sleep(2)
        if executable.exists():
            raise PackageError(f'Uninstall left {executable}')
    return ['installer-silent-install', 'installer-file-list', 'installer-silent-uninstall']


def build_windows_zip(source, output):
    target = output / 'qfli-forge-windows-x64.zip'
    target.unlink(missing_ok=True)
    files = sorted(files_under(source))
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in files:
            archive.write(source / relative, f'{APP_NAME}/{relative}')
    with zipfile.ZipFile(target) as archive:
        if archive.testzip() is not None:
            raise PackageError(f'{target.name} has a damaged entry')
        check_archive_names(archive.namelist(), APP_NAME, files)
    return target


def package_windows(source, output, version):
    if not source.is_dir():
        raise PackageError(f'Application build is missing: {source}')
    require_files(source, WINDOWS_REQUIRED)
    setup = build_windows_setup(source, output, version)
    validation = ['windows-build-files', *verify_windows_setup(setup, source)]
    archive = build_windows_zip(source, output)
    return [setup, archive], [*validation, 'portable-zip-file-list']


# Linux.

def build_deb(source, output, version):
    """Build the Debian package. Return the package and its icon path."""
    target = output / 'qfli-forge-linux-x64.deb'
    target.unlink(missing_ok=True)
    icon_source = ROOT / 'assets/app_icon.png'
    with icon_source.open('rb') as stream:
        icon_path = icon_install_path(*png_size(stream.read(24)))
    with workspace() as work:
        root = work / 'root'
        application = root / 'opt' / DEB_PACKAGE
        shutil.copytree(source, application, symlinks=True)
        launcher = root / 'usr/bin' / DEB_PACKAGE
        launcher.parent.mkdir(parents=True)
        launcher.symlink_to(f'/opt/{DEB_PACKAGE}/{BINARY_NAME}')
        entry = root / 'usr/share/applications' / f'{APP_ID}.desktop'
        entry.parent.mkdir(parents=True)
        write_text(entry, desktop_entry())
        icon = root / icon_path
        icon.parent.mkdir(parents=True)
        shutil.copyfile(icon_source, icon)
        copyright_file = root / 'usr/share/doc' / DEB_PACKAGE / 'copyright'
        copyright_file.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'LICENSE', copyright_file)
        size = sum(path.lstat().st_size for path in root.rglob('*') if not path.is_dir())
        for path in [root, *root.rglob('*')]:
            if path.is_dir() and not path.is_symlink():
                path.chmod(0o755)
        (root / 'DEBIAN').mkdir(mode=0o755)
        write_text(root / 'DEBIAN/control', control_file(version, -(-size // 1024)))
        run(['dpkg-deb', '--root-owner-group', '-Zxz', '--build', root, target])
    return target, icon_path


def ldd(binary, strict):
    """Check that the dynamic loader finds every library of one ELF file."""
    result = subprocess.run(['ldd', str(binary)], text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    print(f'+ ldd {binary}\n{result.stdout}', flush=True)
    check_ldd_output(binary, result.stdout)
    # ldd can return nonzero for a library without dependencies, such as a snapshot.
    if strict and result.returncode != 0:
        raise PackageError(f'ldd failed for {binary}:\n{result.stdout}')


def verify_deb(package, version, icon_path):
    """Install through apt, check the installed files and remove the package."""
    fields = output_of(['dpkg-deb', '--field', package, *CONTROL_FIELDS])
    check_control_fields(parse_control_fields(fields), version)
    application = Path('/opt') / DEB_PACKAGE
    run(['sudo', 'apt-get', 'install', '-y', '--no-install-recommends', package.resolve()])
    try:
        launcher = Path('/usr/bin') / DEB_PACKAGE
        if not launcher.is_symlink() or launcher.resolve(strict=True) != application / BINARY_NAME:
            raise PackageError(f'Launcher {launcher} does not link to {application / BINARY_NAME}')
        for installed in [f'/usr/share/applications/{APP_ID}.desktop', f'/{icon_path}']:
            if not Path(installed).is_file():
                raise PackageError(f'Package did not install {installed}')
        ldd(application / BINARY_NAME, strict=True)
        for library in sorted((application / 'lib').glob('*.so')):
            ldd(library, strict=False)
    finally:
        run(['sudo', 'apt-get', 'remove', '-y', DEB_PACKAGE])
    if application.exists():
        raise PackageError(f'Package removal left {application}')
    return ['deb-package-fields', 'deb-apt-install', 'deb-launcher-link', 'deb-desktop-entry',
            'deb-icon', 'deb-shared-library-resolution', 'deb-apt-remove']


def _root_owned(member):
    # Member filter of TarFile.add (not an extraction filter).
    member.uid = member.gid = 0
    member.uname = member.gname = 'root'
    return member


def build_linux_tar(source, output):
    target = output / 'qfli-forge-linux-x64.tar.gz'
    target.unlink(missing_ok=True)
    with tarfile.open(target, 'w:gz') as archive:
        archive.add(source, arcname=DEB_PACKAGE, filter=_root_owned)
    with tarfile.open(target) as archive:
        names = [member.name for member in archive.getmembers() if not member.isdir()]
    check_archive_names(names, DEB_PACKAGE, files_under(source))
    return target


def package_linux(source, output, version):
    if not source.is_dir():
        raise PackageError(f'Application build is missing: {source}')
    require_files(source, LINUX_REQUIRED)
    if not os.access(source / BINARY_NAME, os.X_OK):
        raise PackageError(f'Launcher is not executable: {source / BINARY_NAME}')
    if not (source / 'data/flutter_assets').is_dir():
        raise PackageError(f'Incomplete application build: {source / "data/flutter_assets"}')
    package, icon_path = build_deb(source, output, version)
    validation = ['linux-bundle-files', *verify_deb(package, version, icon_path)]
    archive = build_linux_tar(source, output)
    return [package, archive], [*validation, 'tar-file-list']


# macOS.

def verify_macos_app(app):
    check_macos_archs(output_of(['lipo', '-archs', app / 'Contents/MacOS' / APP_NAME]))
    run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', app])


def package_macos(app, output):
    if not (app / 'Contents/MacOS' / APP_NAME).is_file():
        raise PackageError(f'Incomplete application build: {app}')
    verify_macos_app(app)
    target = output / f'{APP_NAME}-macos-universal.dmg'
    with workspace() as directory:
        staging = directory / 'image'
        staging.mkdir()
        run(['ditto', app, staging / f'{APP_NAME}.app'])
        (staging / 'Applications').symlink_to('/Applications')
        # Hosted runners intermittently report "Resource busy" during creation.
        for attempt in range(1, 4):
            try:
                run(['hdiutil', 'create', '-volname', APP_NAME, '-srcfolder', staging,
                     '-fs', 'HFS+', '-ov', '-format', 'UDZO', target])
                break
            except subprocess.CalledProcessError:
                if attempt == 3:
                    raise
                time.sleep(15 * attempt)
        run(['hdiutil', 'verify', target])
        mount = directory / 'mount'
        mount.mkdir()
        run(['hdiutil', 'attach', target, '-nobrowse', '-readonly', '-mountpoint', mount])
        try:
            mounted = mount / f'{APP_NAME}.app'
            if not mounted.is_dir():
                raise PackageError(f'The image has no {APP_NAME}.app')
            link = mount / 'Applications'
            if not link.is_symlink() or os.readlink(link) != '/Applications':
                raise PackageError('The image has no /Applications link')
            verify_macos_app(mounted)
        finally:
            for attempt in range(1, 4):
                try:
                    run(['hdiutil', 'detach', mount, *(['-force'] if attempt == 3 else [])])
                    break
                except subprocess.CalledProcessError:
                    if attempt == 3:
                        raise
                    time.sleep(5)
    return [target], ['application-universal-architectures', 'application-codesign-verification',
                      'image-verify', 'image-application', 'image-applications-link',
                      'mounted-universal-architectures', 'mounted-codesign-verification']


# iOS.

def package_ios(archive, output):
    app = archive / 'Products/Applications/Runner.app'
    if not app.is_dir():
        raise PackageError(f'Incomplete application build: {app}')
    require_files(app, IOS_REQUIRED)
    if (app / 'embedded.mobileprovision').exists():
        raise PackageError('Runner.app is labelled unsigned but holds embedded.mobileprovision')
    run(['lipo', app / 'Runner', '-verify_arch', 'arm64'])
    validation = ['application-files', 'application-no-provisioning-profile', 'application-arm64']
    archive_zip = output / f'{APP_NAME}-ios-arm64-unsigned.xcarchive.zip'
    package = output / f'{APP_NAME}-ios-arm64-unsigned.ipa'
    archive_zip.unlink(missing_ok=True)
    package.unlink(missing_ok=True)
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', archive, archive_zip])
    with zipfile.ZipFile(archive_zip) as stream:
        validation += check_xcarchive_names(stream.namelist(), archive.name)
    with workspace() as directory:
        payload = directory / 'Payload'
        payload.mkdir()
        run(['ditto', app, payload / 'Runner.app'])
        # ditto stores extended attributes in __MACOSX entries beside Payload.
        subprocess.run(['xattr', '-cr', str(payload)], check=False)
        run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', payload, package])
    with zipfile.ZipFile(package) as stream:
        validation += check_ipa_names(stream.namelist())
    return [archive_zip, package], validation


def read_native_record(path):
    if not path.is_file():
        raise PackageError(f'Native input record is missing: {path}')
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except ValueError as error:
        raise PackageError(f'Native input record is not valid JSON: {path}: {error}') from error


def package(args):
    native_input = read_native_record(args.native_record) if args.native_record else None
    version = application_version((ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))
    source = (args.input or ROOT / DEFAULT_INPUTS[args.platform]).resolve()
    if not source.exists():
        raise PackageError(f'Application build is missing: {source}')
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()
    if args.platform == 'android':
        architecture = args.abi
        targets, validation = package_android(source, output, args.abi)
    else:
        architecture = ARCHITECTURES[args.platform]
        if args.platform == 'windows':
            targets, validation = package_windows(source, output, version)
        elif args.platform == 'linux':
            targets, validation = package_linux(source, output, version)
        elif args.platform == 'macos':
            targets, validation = package_macos(source, output)
        else:
            targets, validation = package_ios(source, output)
    write_records(output, args.platform, architecture, version, targets, validation, native_input)


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='platform', required=True)
    for platform, default in DEFAULT_INPUTS.items():
        command = commands.add_parser(platform)
        command.add_argument('--output', required=True, type=Path,
                             help='Directory for the package files and records')
        command.add_argument('--input', type=Path, help=f'Application build (default: {default})')
        command.add_argument('--native-record', type=Path,
                             help='Record that fetch_native_artifact.py wrote')
        if platform == 'android':
            command.add_argument('--abi', required=True, choices=ANDROID_ABIS)
    args = parser.parse_args(arguments)
    try:
        package(args)
    except PackageError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    except subprocess.SubprocessError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
