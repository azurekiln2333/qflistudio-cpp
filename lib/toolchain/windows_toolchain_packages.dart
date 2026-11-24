import 'package:path/path.dart' as p;

/// The two Windows toolchains that the one-click setup installs.
///
/// Each archive is pinned by address, size and SHA-256, so the application
/// downloads exactly the file that this project tested. The values come from
/// our own download of the release (trust on first use): the GitHub release
/// page states no checksum for LLVM-MinGW, and the `.sha256` file of WinLibs
/// matched the SHA-256 of our download.
///
/// The archives are pinned to a release, not to `latest`: a moved release must
/// fail the verification instead of installing an untested compiler.

/// One pinned archive and what it contains.
class WindowsToolchainPackage {
  const WindowsToolchainPackage({
    required this.optionId,
    required this.title,
    required this.summary,
    required this.url,
    required this.bytes,
    required this.sha256,
    required this.archiveRoot,
    required this.compilerFile,
  });

  /// Option id of the environment page, for example `windows-llvm-mingw`.
  final String optionId;

  final String title;

  final String summary;

  /// Exact release address. Redirects to another host are expected.
  final String url;

  /// Size of the archive in bytes.
  final int bytes;

  /// Lower-case hex SHA-256 of the archive.
  final String sha256;

  /// Top-level directory of the archive, without a trailing slash. A zip that
  /// puts its files at the top level has an empty value.
  final String archiveRoot;

  /// Compiler that a successful install must find under `<root>/bin`.
  final String compilerFile;

  /// Toolchain root after the rename: the archive root under [target].
  String rootUnder(String target) =>
      archiveRoot.isEmpty ? target : p.join(target, archiveRoot);
}

/// LLVM-MinGW for x86_64 Windows with UCRT.
///
/// Self-contained: Clang, LLD, libc++, the mingw-w64 headers and libraries.
/// It needs no Visual Studio and no administrator rights.
const WindowsToolchainPackage llvmMinGwPackage = WindowsToolchainPackage(
  optionId: 'windows-llvm-mingw',
  title: 'Clang（LLVM-MinGW）',
  summary: '下载 LLVM-MinGW 压缩包，安装到应用数据目录，不修改系统 PATH。',
  url:
      'https://github.com/mstorsjo/llvm-mingw/releases/download/20250305/'
      'llvm-mingw-20250305-ucrt-x86_64.zip',
  bytes: 151580565,
  sha256: 'd955112db27ebbefec0b1fc77d4fcfe7b51ed767912e74e4e00b4a63e9d3ac97',
  archiveRoot: 'llvm-mingw-20250305-ucrt-x86_64',
  compilerFile: 'gcc.exe',
);

/// GNU GCC for x86_64 Windows with UCRT.
///
/// A plain zip of WinLibs without LLVM: `%SystemRoot%\System32\tar.exe`
/// (bsdtar) unpacks it, and the result holds `gcc.exe`, `g++.exe` and the
/// runtime DLLs in one `mingw64/bin` directory. The WinLibs release supplies
/// a `.sha256` file, and its value equals the SHA-256 below.
const WindowsToolchainPackage winLibsGccPackage = WindowsToolchainPackage(
  optionId: 'windows-gcc-winlibs',
  title: 'GCC（WinLibs）',
  summary: '下载 WinLibs GCC 压缩包，安装到应用数据目录，不修改系统 PATH。',
  url:
      'https://github.com/brechtsanders/winlibs_mingw/releases/download/'
      '15.2.0posix-13.0.0-ucrt-r2/'
      'winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r2.zip',
  bytes: 264007421,
  sha256: '3b86551fb163859f805145e5c1b0d4a48324654b99863bef7da5af6d9fc9d813',
  archiveRoot: 'mingw64',
  compilerFile: 'gcc.exe',
);

/// Windows options in the order that the page lists them.
const List<WindowsToolchainPackage> windowsToolchainPackages = [
  llvmMinGwPackage,
  winLibsGccPackage,
];
