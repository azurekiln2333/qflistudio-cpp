"""Check the pure functions and the file-only paths of package_app.py."""

from __future__ import annotations

import contextlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))

import package_app  # noqa: E402
from package_app import PackageError  # noqa: E402


def apk_names(abi, extra=()):
    names = [f'lib/{abi}/{library}' for library in package_app.ANDROID_LIBRARIES]
    return [*names, f'assets/qfli_toolchain/{abi}.zip', 'AndroidManifest.xml',
            'classes.dex', 'assets/flutter_assets/AssetManifest.bin', *extra]


def ipa_names(extra=()):
    names = [package_app.IOS_APP + required for required in package_app.IOS_REQUIRED]
    return ['Payload/', 'Payload/Runner.app/', *names, *extra]


class VersionTest(unittest.TestCase):
    def test_application_version_reads_the_version_line(self):
        text = 'name: qfli_c\ndescription: "version: no"\nversion: 1.0.0+1\nenvironment:\n'
        self.assertEqual(package_app.application_version(text), '1.0.0+1')

    def test_application_version_requires_a_version_line(self):
        with self.assertRaises(PackageError):
            package_app.application_version('name: qfli_c\n')

    def test_repository_pubspec_has_a_numeric_version(self):
        text = (package_app.ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        version = package_app.application_version(text)
        self.assertRegex(package_app.debian_version(version), r'^\d+\.\d+\.\d+(-\d+)?$')
        self.assertRegex(package_app.windows_file_version(version), r'^\d+\.\d+\.\d+\.\d+$')

    def test_debian_version(self):
        self.assertEqual(package_app.debian_version('1.0.0+1'), '1.0.0-1')
        self.assertEqual(package_app.debian_version('2.3.4'), '2.3.4')
        with self.assertRaises(PackageError):
            package_app.debian_version('1.0.0-beta')

    def test_windows_file_version(self):
        self.assertEqual(package_app.windows_file_version('1.2.3+4'), '1.2.3.4')
        self.assertEqual(package_app.windows_file_version('1.2.3'), '1.2.3.0')


class ApkTest(unittest.TestCase):
    def test_complete_apk_passes_for_each_abi(self):
        for abi in package_app.ANDROID_ABIS:
            validation = package_app.check_apk_names(apk_names(abi), abi)
            self.assertIn('apk-single-abi', validation)
            self.assertIn('apk-toolchain-asset', validation)

    def test_second_abi_is_rejected(self):
        names = apk_names('arm64-v8a', ['lib/x86_64/libflutter.so'])
        with self.assertRaisesRegex(PackageError, 'exactly arm64-v8a'):
            package_app.check_apk_names(names, 'arm64-v8a')

    def test_other_abi_is_rejected(self):
        with self.assertRaisesRegex(PackageError, 'exactly x86_64'):
            package_app.check_apk_names(apk_names('arm64-v8a'), 'x86_64')

    def test_each_library_is_required(self):
        for library in package_app.ANDROID_LIBRARIES:
            names = [name for name in apk_names('x86_64') if not name.endswith('/' + library)]
            with self.assertRaisesRegex(PackageError, 'lacks lib/x86_64'):
                package_app.check_apk_names(names, 'x86_64')

    def test_toolchain_asset_is_required(self):
        names = [name for name in apk_names('x86_64') if not name.startswith('assets/qfli_toolchain/')]
        with self.assertRaisesRegex(PackageError, 'assets/qfli_toolchain/x86_64.zip'):
            package_app.check_apk_names(names, 'x86_64')


class IosTest(unittest.TestCase):
    def test_complete_ipa_passes(self):
        self.assertIn('ipa-wasi-sdk-resources', package_app.check_ipa_names(ipa_names()))

    def test_entry_outside_payload_is_rejected(self):
        with self.assertRaisesRegex(PackageError, 'outside Payload'):
            package_app.check_ipa_names(ipa_names(['__MACOSX/Payload/._Runner.app']))

    def test_each_application_file_is_required(self):
        for required in package_app.IOS_REQUIRED:
            names = [name for name in ipa_names() if name != package_app.IOS_APP + required]
            with self.assertRaisesRegex(PackageError, 'lacks Runner.app'):
                package_app.check_ipa_names(names)

    def test_provisioning_profile_is_rejected(self):
        names = ipa_names([package_app.IOS_APP + 'embedded.mobileprovision'])
        with self.assertRaisesRegex(PackageError, 'embedded.mobileprovision'):
            package_app.check_ipa_names(names)

    def test_archive_zip_needs_the_application(self):
        names = ['Runner.xcarchive/Info.plist',
                 'Runner.xcarchive/Products/Applications/Runner.app/Runner']
        self.assertEqual(
            package_app.check_xcarchive_names(names, 'Runner.xcarchive'), ['xcarchive-zip-application'])
        with self.assertRaisesRegex(PackageError, 'Archive ZIP lacks'):
            package_app.check_xcarchive_names(names[:1], 'Runner.xcarchive')


class FileListTest(unittest.TestCase):
    SOURCE = ['qfli_c.exe', 'flutter_windows.dll', 'data/app.so']
    INSTALLED = [*SOURCE, 'LICENSE.txt', 'unins000.exe', 'unins000.dat']

    def test_expected_installed_files_adds_the_installer_files(self):
        self.assertEqual(package_app.expected_installed_files(self.SOURCE), set(self.INSTALLED))

    def test_matching_installation_passes(self):
        self.assertEqual(package_app.check_installed_files(self.SOURCE, self.INSTALLED), 6)

    def test_missing_and_unexpected_files_are_rejected(self):
        with self.assertRaisesRegex(PackageError, r"missing \['data/app.so'\]"):
            package_app.check_installed_files(
                self.SOURCE, [name for name in self.INSTALLED if name != 'data/app.so'])
        with self.assertRaisesRegex(PackageError, r"unexpected \['extra.dll'\]"):
            package_app.check_installed_files(self.SOURCE, [*self.INSTALLED, 'extra.dll'])
        with self.assertRaisesRegex(PackageError, r"missing \['unins000.dat'\]"):
            package_app.check_installed_files(self.SOURCE, self.INSTALLED[:-1])

    def test_archive_names_need_one_top_folder(self):
        names = [f'QFLIForge/{name}' for name in self.SOURCE]
        self.assertEqual(package_app.check_archive_names(names, 'QFLIForge', self.SOURCE), 3)
        with self.assertRaises(PackageError):
            package_app.check_archive_names(self.SOURCE, 'QFLIForge', self.SOURCE)
        with self.assertRaises(PackageError):
            package_app.check_archive_names(names[:-1], 'QFLIForge', self.SOURCE)


class LinuxTest(unittest.TestCase):
    def test_control_file(self):
        text = package_app.control_file('1.0.0+1', 1234)
        fields = package_app.parse_control_fields(text)
        self.assertEqual(fields['Package'], 'qfli-forge')
        self.assertEqual(fields['Version'], '1.0.0-1')
        self.assertEqual(fields['Architecture'], 'amd64')
        self.assertEqual(fields['Maintainer'], 'QFLIForge CI <noreply@github.com>')
        self.assertEqual(fields['Depends'], 'libgtk-3-0t64 | libgtk-3-0, libstdc++6')
        self.assertEqual(fields['Homepage'], 'https://github.com/azurekiln2333/qflistudio-cpp')
        self.assertEqual(fields['Installed-Size'], '1234')
        self.assertTrue(fields['Description'].startswith('QFLIForge'))
        self.assertTrue(text.endswith('\n'))
        self.assertNotIn('\n\n', text)
        self.assertNotIn('Installed-Size', package_app.control_file('1.0.0+1'))
        package_app.check_control_fields(fields, '1.0.0+1')

    def test_control_fields_reject_another_version(self):
        fields = package_app.parse_control_fields(package_app.control_file('1.0.0+1'))
        with self.assertRaisesRegex(PackageError, 'Unexpected package fields'):
            package_app.check_control_fields(fields, '1.0.1+1')

    def test_desktop_entry(self):
        lines = package_app.desktop_entry().splitlines()
        self.assertEqual(lines[0], '[Desktop Entry]')
        self.assertIn('Type=Application', lines)
        self.assertIn('Name=QFLIForge', lines)
        self.assertIn('Exec=qfli-forge', lines)
        self.assertIn('Icon=com.azurekiln.qfli.forge', lines)

    def test_icon_path_follows_the_real_size(self):
        header = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 512, 512)
        self.assertEqual(package_app.png_size(header), (512, 512))
        self.assertEqual(
            package_app.icon_install_path(512, 512),
            'usr/share/icons/hicolor/512x512/apps/com.azurekiln.qfli.forge.png')
        for width, height in [(1024, 1024), (512, 256), (473, 476)]:
            self.assertEqual(
                package_app.icon_install_path(width, height),
                'usr/share/pixmaps/com.azurekiln.qfli.forge.png')
        with self.assertRaises(PackageError):
            package_app.png_size(b'GIF89a' + bytes(24))

    def test_repository_icon_has_an_install_path(self):
        with (package_app.ROOT / 'assets/app_icon.png').open('rb') as stream:
            path = package_app.icon_install_path(*package_app.png_size(stream.read(24)))
        self.assertTrue(path.endswith('/com.azurekiln.qfli.forge.png'))

    def test_ldd_output(self):
        package_app.check_ldd_output('qfli_c', '\tlibgtk-3.so.0 => /lib/libgtk-3.so.0 (0x1)\n')
        with self.assertRaisesRegex(PackageError, 'unresolved'):
            package_app.check_ldd_output('qfli_c', '\tlibgtk-3.so.0 => not found\n')


class MacosTest(unittest.TestCase):
    def test_universal_application_passes(self):
        self.assertEqual(package_app.check_macos_archs('x86_64 arm64\n'), ['arm64', 'x86_64'])

    def test_single_architecture_is_rejected(self):
        with self.assertRaisesRegex(PackageError, 'not universal'):
            package_app.check_macos_archs('arm64\n')


class RecordTest(unittest.TestCase):
    PACKAGES = [
        {'file': 'a.deb', 'sha256': 'a' * 64, 'size': 1},
        {'file': 'b.tar.gz', 'sha256': 'b' * 64, 'size': 2},
    ]

    def test_checksum_lines(self):
        self.assertEqual(
            package_app.checksum_lines(self.PACKAGES),
            'a' * 64 + '  a.deb\n' + 'b' * 64 + '  b.tar.gz\n')

    def test_provenance_with_runner_environment(self):
        environment = {
            'GITHUB_SHA': 'c' * 40, 'GITHUB_REPOSITORY': 'azurekiln2333/qflistudio-cpp',
            'GITHUB_RUN_ID': '42', 'GITHUB_SERVER_URL': 'https://github.com',
            'CORE_REVISION': 'd' * 40, 'FLUTTER_REVISION': 'e' * 40,
        }
        record = package_app.provenance(
            environment, 'linux', 'x64', '1.0.0+1', self.PACKAGES, ['tar-file-list'])
        self.assertEqual(list(record), [
            'applicationCommit', 'repository', 'runId', 'runUrl', 'coreCommit', 'flutterCommit',
            'platform', 'architecture', 'applicationVersion', 'signing', 'nativeInput',
            'packages', 'validation', 'deviceRuntimeVerified'])
        self.assertEqual(record['applicationCommit'], 'c' * 40)
        self.assertEqual(
            record['runUrl'], 'https://github.com/azurekiln2333/qflistudio-cpp/actions/runs/42')
        self.assertEqual(record['coreCommit'], 'd' * 40)
        self.assertEqual(record['flutterCommit'], 'e' * 40)
        self.assertEqual(record['applicationVersion'], '1.0.0+1')
        self.assertEqual(record['signing'], 'unsigned')
        self.assertIsNone(record['nativeInput'])
        self.assertEqual(record['packages'], self.PACKAGES)
        self.assertEqual(record['validation'], ['tar-file-list'])
        self.assertIs(record['deviceRuntimeVerified'], False)

    def test_provenance_without_environment(self):
        record = package_app.provenance({}, 'android', 'x86_64', '1.0.0+1', [], [], {'runId': 7})
        for field in ['applicationCommit', 'repository', 'runId', 'runUrl', 'coreCommit', 'flutterCommit']:
            self.assertIsNone(record[field])
        self.assertEqual(record['signing'], 'ephemeral debug key')
        self.assertEqual(record['nativeInput'], {'runId': 7})

    def test_signing_values(self):
        self.assertEqual(package_app.SIGNING, {
            'android': 'ephemeral debug key', 'windows': 'unsigned', 'linux': 'unsigned',
            'macos': 'ad hoc', 'ios': 'unsigned'})

    def test_signing_notes(self):
        for platform, signing in package_app.SIGNING.items():
            note = package_app.signing_note(platform)
            self.assertIn(signing, note)
            self.assertIn('Device or UI execution was not tested.', note)
            self.assertEqual('clang or gcc' in note, platform in ('windows', 'linux', 'macos'))
        self.assertIn('uninstall first', package_app.signing_note('android'))
        self.assertIn('Not for store upload', package_app.signing_note('android'))
        self.assertIn('Not notarized', package_app.signing_note('macos'))
        self.assertIn('Apple identity and profile', package_app.signing_note('ios'))


class DesktopArchiveTest(unittest.TestCase):
    """Build the portable archives from a fake application build."""

    FILES = ['data/flutter_assets/AssetManifest.bin', 'lib/libapp.so', 'qfli_c']

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.source = root / 'build'
        for relative in self.FILES:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(relative.encode())
        self.output = root / 'out'
        self.output.mkdir()

    def test_windows_zip_holds_the_build_under_one_folder(self):
        target = package_app.build_windows_zip(self.source, self.output)
        self.assertEqual(target, self.output / 'qfli-forge-windows-x64.zip')
        with zipfile.ZipFile(target) as archive:
            self.assertEqual(archive.namelist(), [f'QFLIForge/{name}' for name in self.FILES])
            self.assertEqual(archive.read('QFLIForge/qfli_c'), b'qfli_c')

    def test_linux_tar_holds_the_bundle_under_one_folder(self):
        target = package_app.build_linux_tar(self.source, self.output)
        self.assertEqual(target, self.output / 'qfli-forge-linux-x64.tar.gz')
        with tarfile.open(target) as archive:
            members = archive.getmembers()
            content = archive.extractfile('qfli-forge/lib/libapp.so').read()
        self.assertEqual(
            sorted(member.name for member in members if member.isfile()),
            [f'qfli-forge/{name}' for name in self.FILES])
        self.assertEqual({(member.uid, member.gid, member.uname) for member in members}, {(0, 0, 'root')})
        self.assertEqual(content, b'lib/libapp.so')

    def test_portable_file_list_ignores_the_completion_marker(self):
        source = set(self.FILES)
        extracted = source | {package_app.PORTABLE_MARKER}
        self.assertEqual(package_app.check_portable_file_list(source, extracted - {package_app.PORTABLE_MARKER}), len(source))

    def test_portable_build_id_requires_a_valid_commit_and_run(self):
        self.assertEqual(
            package_app.portable_build_id('a' * 40, '44123456789'),
            'aaaaaaaaaaaa-44123456789',
        )
        for commit, run_id in [('', '1'), ('a' * 39, '1'), ('g' * 40, '1'), ('a' * 40, 'bad/run')]:
            with self.assertRaises(PackageError):
                package_app.portable_build_id(commit, run_id)

    def test_portable_file_list_reports_missing_and_unexpected_files(self):
        with self.assertRaisesRegex(PackageError, r'missing .*b\.txt'):
            package_app.check_portable_file_list(['a.txt', 'b.txt'], ['a.txt'])
        with self.assertRaisesRegex(PackageError, r'unexpected .*extra\.txt'):
            package_app.check_portable_file_list(['a.txt'], ['a.txt', 'extra.txt'])

    def test_linux_icons_are_discovered_in_declared_order(self):
        root = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__('shutil').rmtree(root, ignore_errors=True))
        icon_dir = root / package_app.LINUX_ICON_DIR
        icon_dir.mkdir(parents=True)
        for size in package_app.LINUX_ICON_SIZES:
            header = (
                b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR'
                + struct.pack('>II', size, size)
            )
            (icon_dir / f'app_icon_{size}.png').write_bytes(header)
        icons = package_app.linux_icon_files(root)
        self.assertEqual([size for size, _ in icons], package_app.LINUX_ICON_SIZES)
        self.assertEqual(package_app.check_linux_icon_sizes(root), [f'linux-icon-{size}' for size in package_app.LINUX_ICON_SIZES])
        layout = package_app.appdir_layout(icons)
        self.assertEqual(layout[0], (package_app.APPDIR_LAUNCHER, None))
        self.assertIn(package_app.APPDIR_ICON, package_app.appdir_icon_names(icons))
        self.assertIn(
            f'usr/share/icons/hicolor/{package_app.APPDIR_ICON_SIZE}x{package_app.APPDIR_ICON_SIZE}/apps/{package_app.APP_ID}.png',
            package_app.appdir_icon_names(icons),
        )


class WindowsPortableTest(unittest.TestCase):
    """Check the NSIS contract without running a compiler or application."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.source = root / 'build with spaces'
        for relative in package_app.WINDOWS_REQUIRED:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(relative.encode())
        self.output = root / 'output with spaces'
        self.output.mkdir()
        self.target = self.output / 'qfli-forge-windows-x64-portable.exe'
        self.application = self.output / 'qfli-forge-windows-x64-portable'
        self.compiler = root / 'NSIS tools' / 'makensis.exe'
        self.build_id = 'd34c2062a7a3-45592127359'

    def test_portable_compiler_receives_the_numeric_application_version(self):
        for version, numeric in [('1.0.0+1', '1.0.0.1'),
                                 ('1.2.3+4', '1.2.3.4'), ('1.2.3', '1.2.3.0')]:
            with self.subTest(version=version):
                def compile_launcher(command):
                    self.assertEqual(command, [
                        self.compiler, '/V2', '/NOCD',
                        f'/DBuildId={self.build_id}',
                        f'/DFileVersion={numeric}',
                        f'/DApplicationDir={self.application}',
                        f'/DOutputFile={self.target}',
                        f'/DIconFile={package_app.ROOT / "windows/runner/resources/app_icon.ico"}',
                        package_app.ROOT / 'tool/ci/windows_portable.nsi',
                    ])
                    self.assertEqual(package_app.files_under(self.application),
                                     set(package_app.WINDOWS_REQUIRED))
                    self.target.write_bytes(b'fake launcher')

                with mock.patch.object(package_app, 'find_makensis', return_value=self.compiler), \
                        mock.patch.object(package_app, 'run', side_effect=compile_launcher) as run:
                    target = package_app.build_windows_portable(
                        self.source, self.output, version, self.build_id)
                run.assert_called_once()
                self.assertEqual(target, self.target)
                self.assertFalse(self.application.exists())

    def test_windows_packaging_passes_the_version_to_the_portable_compiler(self):
        setup = self.output / 'qfli-forge-windows-x64-setup.exe'
        with mock.patch.object(package_app, 'build_windows_setup', return_value=setup) as build_setup, \
                mock.patch.object(package_app, 'verify_windows_setup', return_value=['setup-check']), \
                mock.patch.object(package_app, 'build_windows_portable',
                                  return_value=self.target) as build_portable, \
                mock.patch.object(package_app, 'verify_windows_portable',
                                  return_value=['portable-check']) as verify_portable:
            targets, validation = package_app.package_windows(
                self.source, self.output, '1.2.3+4', self.build_id)
        build_setup.assert_called_once_with(self.source, self.output, '1.2.3+4')
        build_portable.assert_called_once_with(
            self.source, self.output, '1.2.3+4', self.build_id)
        verify_portable.assert_called_once_with(self.target, self.source, mock.ANY)
        self.assertEqual(targets, [setup, self.output / 'qfli-forge-windows-x64.zip', self.target])
        self.assertEqual(validation, [
            'windows-build-files', 'setup-check', 'portable-zip-file-list', 'portable-check'])

    def test_portable_compiler_failure_removes_staging_and_stale_output(self):
        self.target.write_bytes(b'stale launcher')
        with mock.patch.object(package_app, 'find_makensis', return_value=self.compiler), \
                mock.patch.object(package_app, 'run',
                                  side_effect=subprocess.CalledProcessError(1, ['makensis.exe'])):
            with self.assertRaises(subprocess.CalledProcessError):
                package_app.build_windows_portable(
                    self.source, self.output, '1.2.3+4', self.build_id)
        self.assertFalse(self.application.exists())
        self.assertFalse(self.target.exists())

    def test_portable_compiler_must_write_the_output(self):
        with mock.patch.object(package_app, 'find_makensis', return_value=self.compiler), \
                mock.patch.object(package_app, 'run'):
            with self.assertRaisesRegex(PackageError, 'NSIS did not write'):
                package_app.build_windows_portable(
                    self.source, self.output, '1.2.3+4', self.build_id)
        self.assertFalse(self.application.exists())

    def test_portable_extraction_uses_a_positional_directory_and_repeats(self):
        extraction = self.output / 'extract with spaces'
        target = extraction / package_app.APP_NAME
        command = [self.target, '/EXTRACTONLY', str(target)]

        def extract_launcher(arguments, **options):
            self.assertEqual(arguments, command)
            destination = Path(arguments[2])
            for relative in package_app.files_under(self.source):
                path = destination / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((self.source / relative).read_bytes())
            (destination / package_app.PORTABLE_MARKER).write_text(self.build_id, encoding='utf-8')

        with mock.patch.object(package_app, 'run', side_effect=extract_launcher) as run:
            validation = package_app.verify_windows_portable(self.target, self.source, extraction)
        self.assertEqual(run.call_args_list, [
            mock.call(command, timeout=1800), mock.call(command, timeout=600)])
        self.assertEqual(package_app.files_under(target),
                         set(package_app.WINDOWS_REQUIRED) | {package_app.PORTABLE_MARKER})
        self.assertEqual(validation, [
            'portable-extract-only', 'portable-file-list', 'portable-marker',
            'portable-repeat-extraction'])

    def test_portable_extraction_rejects_missing_and_unexpected_files(self):
        for index, defect in enumerate(['missing', 'unexpected']):
            with self.subTest(defect=defect):
                extraction = self.output / f'extract {index}'
                target = extraction / package_app.APP_NAME

                def extract_launcher(arguments, **options):
                    target.mkdir(parents=True)
                    for relative in package_app.WINDOWS_REQUIRED:
                        path = target / relative
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_bytes(b'fake application file')
                    (target / package_app.PORTABLE_MARKER).write_text(self.build_id, encoding='utf-8')
                    if defect == 'missing':
                        (target / 'qfli_c.exe').unlink()
                    else:
                        (target / 'unexpected.dll').write_bytes(b'extra file')

                with mock.patch.object(package_app, 'run', side_effect=extract_launcher) as run:
                    with self.assertRaisesRegex(PackageError, 'Extracted files differ'):
                        package_app.verify_windows_portable(self.target, self.source, extraction)
                run.assert_called_once()

    def test_portable_extraction_requires_the_completion_marker(self):
        extraction = self.output / 'extract without marker'
        target = extraction / package_app.APP_NAME

        def extract_launcher(arguments, **options):
            for relative in package_app.WINDOWS_REQUIRED:
                path = target / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fake application file')

        with mock.patch.object(package_app, 'run', side_effect=extract_launcher) as run:
            with self.assertRaisesRegex(PackageError, 'The extraction wrote no'):
                package_app.verify_windows_portable(self.target, self.source, extraction)
        run.assert_called_once()

    def test_portable_extraction_propagates_launcher_failure(self):
        with mock.patch.object(package_app, 'run',
                               side_effect=subprocess.CalledProcessError(1, [str(self.target)])) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                package_app.verify_windows_portable(
                    self.target, self.source, self.output / 'failed extraction')
        run.assert_called_once()

    def test_portable_script_parses_the_extraction_directory_without_trimming_it_again(self):
        script = (package_app.ROOT / 'tool/ci/windows_portable.nsi').read_text(encoding='utf-8')
        extract_branch = script.split('Function .onInit\n', 1)[1].split(
            '  ; The switch is absent', 1)[0]
        self.assertIn('${GetOptions} $R0 "/EXTRACTONLY" $Target', extract_branch)
        self.assertIn('''    ${If} $Target == ""
      StrCpy $Target "$EXEDIR\\${AppName}"
    ${EndIf}''', extract_branch)
        self.assertNotIn('UnquoteResult', script)
        self.assertNotIn('StrCpy $R1', extract_branch)
        self.assertNotIn('StrCpy $Target "$Target"', extract_branch)
        self.assertIn('!insertmacro ExtractApplication', extract_branch)
        self.assertIn('Quit', extract_branch)
        self.assertNotIn('Call StartApplication', extract_branch)

    def test_portable_script_uses_native_nsis_required_definitions(self):
        script = (package_app.ROOT / 'tool/ci/windows_portable.nsi').read_text(encoding='utf-8')
        self.assertNotRegex(script, r'(?m)^\s*#\s*(?:ifndef|ifdef|define|endif|error)\b')
        for name in ['BuildId', 'ApplicationDir', 'OutputFile', 'IconFile', 'FileVersion']:
            self.assertIn(f'!ifndef {name}\n  !error "{name} is required"\n!endif', script)
        self.assertIn('VIProductVersion "${FileVersion}"', script)
        self.assertIn('VIAddVersionKey /LANG=1033 "FileVersion" "${FileVersion}"', script)


class AndroidCommandTest(unittest.TestCase):
    """Run the android command on a fake APK, without Flutter."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / 'dist' / 'app'

    def write_apk(self, names):
        apk = self.root / 'app-release.apk'
        with zipfile.ZipFile(apk, 'w') as archive:
            for name in names:
                archive.writestr(name, name.encode())
        return apk

    def run_command(self, *arguments, environment=None):
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, environment or {}), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            status = package_app.main([str(argument) for argument in arguments])
        return status, stderr.getvalue()

    def test_android_command_writes_the_package_and_records(self):
        apk = self.write_apk(apk_names('arm64-v8a'))
        native = self.root / 'native-input.json'
        native.write_text(
            json.dumps({'name': 'qfli-native-android-arm64-v8a', 'runId': 44001588302}),
            encoding='utf-8')
        status, stderr = self.run_command(
            'android', '--abi', 'arm64-v8a', '--input', apk, '--output', self.output,
            '--native-record', native,
            environment={'GITHUB_SHA': 'f' * 40, 'GITHUB_RUN_ID': '9',
                         'GITHUB_REPOSITORY': 'azurekiln2333/qflistudio-cpp',
                         'GITHUB_SERVER_URL': 'https://github.com'})
        self.assertEqual((status, stderr), (0, ''))
        package = 'qfli-forge-android-arm64-v8a-test-signed.apk'
        self.assertEqual(
            sorted(path.name for path in self.output.iterdir()),
            sorted([package, 'LICENSE', 'SHA256SUMS', 'SIGNING.txt', 'provenance.json']))
        self.assertEqual((self.output / package).read_bytes(), apk.read_bytes())
        self.assertEqual(
            (self.output / 'LICENSE').read_bytes(), (package_app.ROOT / 'LICENSE').read_bytes())
        digest = package_app.sha256(apk)
        self.assertEqual((self.output / 'SHA256SUMS').read_bytes(), f'{digest}  {package}\n'.encode())
        signing = (self.output / 'SIGNING.txt').read_bytes()
        self.assertIn(b'ephemeral debug key', signing)
        self.assertNotIn(b'\r', signing)
        record = json.loads((self.output / 'provenance.json').read_text(encoding='utf-8'))
        self.assertEqual(record['platform'], 'android')
        self.assertEqual(record['architecture'], 'arm64-v8a')
        self.assertEqual(record['applicationCommit'], 'f' * 40)
        self.assertEqual(
            record['runUrl'], 'https://github.com/azurekiln2333/qflistudio-cpp/actions/runs/9')
        self.assertEqual(record['nativeInput']['runId'], 44001588302)
        self.assertEqual(
            record['packages'], [{'file': package, 'sha256': digest, 'size': apk.stat().st_size}])
        self.assertIn('apk-native-toolchain-libraries', record['validation'])
        self.assertIs(record['deviceRuntimeVerified'], False)

    def test_android_command_rejects_an_incomplete_apk(self):
        names = [name for name in apk_names('x86_64') if not name.endswith('libqfli_clang.so')]
        status, stderr = self.run_command(
            'android', '--abi', 'x86_64', '--input', self.write_apk(names), '--output', self.output)
        self.assertEqual(status, 1)
        self.assertIn('libqfli_clang.so', stderr)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_android_command_rejects_a_file_that_is_not_an_apk(self):
        apk = self.root / 'app-release.apk'
        apk.write_bytes(b'not a zip archive')
        status, stderr = self.run_command(
            'android', '--abi', 'x86_64', '--input', apk, '--output', self.output)
        self.assertEqual(status, 1)
        self.assertIn('is not an APK', stderr)

    def test_missing_input_fails(self):
        status, stderr = self.run_command(
            'android', '--abi', 'x86_64', '--input', self.root / 'absent.apk', '--output', self.output)
        self.assertEqual(status, 1)
        self.assertIn('Application build is missing', stderr)

    def test_missing_or_damaged_native_record_fails(self):
        apk = self.write_apk(apk_names('x86_64'))
        record = self.root / 'native-input.json'
        status, stderr = self.run_command(
            'android', '--abi', 'x86_64', '--input', apk, '--output', self.output,
            '--native-record', record)
        self.assertEqual(status, 1)
        self.assertIn('Native input record is missing', stderr)
        record.write_text('{', encoding='utf-8')
        status, stderr = self.run_command(
            'android', '--abi', 'x86_64', '--input', apk, '--output', self.output,
            '--native-record', record)
        self.assertEqual(status, 1)
        self.assertIn('not valid JSON', stderr)


if __name__ == '__main__':
    unittest.main()
