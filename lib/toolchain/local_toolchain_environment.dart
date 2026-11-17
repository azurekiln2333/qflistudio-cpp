import 'package:flutter/foundation.dart';

import 'toolchain_environment.dart';

/// Compiler environment of this computer.
class LocalToolchainEnvironment extends ChangeNotifier
    implements ToolchainEnvironment {
  @override
  bool get supported => false;

  @override
  ToolchainSettings get settings => const ToolchainSettings();

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
      const Stream.empty();

  @override
  Future<void> cancelSetup() async {}

  @override
  Future<void> remove(String optionId) async {}
}

/// The instance that the runner and the environment page share.
final ToolchainEnvironment forgeToolchainEnvironment =
    LocalToolchainEnvironment();
