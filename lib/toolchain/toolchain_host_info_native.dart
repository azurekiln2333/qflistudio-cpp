import 'dart:io';

/// Facts about this computer that the environment cannot ask a test for.
///
/// Production reads them from the platform. A test builds the class with fixed
/// values, so no test depends on the compilers of the computer.
class ToolchainHostInfo {
  const ToolchainHostInfo({
    required this.isWindows,
    required this.isLinux,
    required this.isMacOS,
    required this.environment,
    required this.executableDirectory,
  });

  /// Defaults for the computer that runs this process.
  factory ToolchainHostInfo.current() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return ToolchainHostInfo(
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
        isMacOS: Platform.isMacOS,
        environment: Map<String, String>.from(Platform.environment),
        executableDirectory: File(Platform.resolvedExecutable).parent.path,
      );
    }
    // A bundled-toolchain platform reaches neither a compiler process nor a
    // PATH, so no member reads the real environment there.
    return const ToolchainHostInfo(
      isWindows: false,
      isLinux: false,
      isMacOS: false,
      environment: {},
      executableDirectory: null,
    );
  }

  final bool isWindows;
  final bool isLinux;
  final bool isMacOS;

  /// Environment variables of the computer.
  final Map<String, String> environment;

  /// Directory of the running application, for the toolchain beside it.
  final String? executableDirectory;

  /// True on Windows, Linux and macOS.
  bool get isDesktop => isWindows || isLinux || isMacOS;
}
