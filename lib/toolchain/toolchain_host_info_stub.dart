/// Facts about this computer, for a build that reads no `dart:io`.
///
/// The web has no compiler of this computer, so every value reports a
/// non-desktop host and no member reads the page environment.
class ToolchainHostInfo {
  const ToolchainHostInfo({
    this.isWindows = false,
    this.isLinux = false,
    this.isMacOS = false,
    this.environment = const {},
    this.executableDirectory,
  });

  /// Defaults of a build without a file system.
  factory ToolchainHostInfo.current() => const ToolchainHostInfo();

  final bool isWindows;
  final bool isLinux;
  final bool isMacOS;
  final Map<String, String> environment;
  final String? executableDirectory;

  /// Always false: the web and the bundled-toolchain platforms have no
  /// compiler of this computer.
  bool get isDesktop => false;
}
