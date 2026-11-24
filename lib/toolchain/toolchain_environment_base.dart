import 'package:flutter/foundation.dart';

import 'toolchain_environment.dart';

/// Members of [ToolchainEnvironment] that do nothing.
///
/// The web build has no compiler of this computer, so every member is inert
/// there. A subclass implements the desktop behaviour and keeps these
/// defaults.
abstract class ToolchainEnvironmentBase extends ChangeNotifier
    implements ToolchainEnvironment {
  @override
  ToolchainSettings get settings => const ToolchainSettings();

  /// Defaults for a build that keeps no settings.
  @override
  ToolchainSettings? get storedSettings => settings;

  /// A build without a file system owns no managed toolchain.
  @override
  Future<List<String>>? get managedRoots => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> setDirectory(String? directory) async {}

  @override
  Future<void> setPreference(CompilerPreference preference) async {}

  @override
  Future<List<DetectedCompiler>> detect() async => const [];

  @override
  Future<List<ToolchainSetupOption>> setupOptions() async => const [];

  @override
  Stream<ToolchainSetupProgress> runSetup(String optionId) =>
      const Stream<ToolchainSetupProgress>.empty();

  @override
  Future<void> cancelSetup() async {}

  @override
  Future<void> remove(String optionId) async {}
}
