import 'toolchain_environment.dart';
import 'toolchain_environment_base.dart';

/// Compiler environment of a build that owns no compiler.
///
/// The web build compiles nothing on this computer, so every member is inert
/// and [supported] stays false. The file also keeps `dart:io` and the setup
/// code out of the web bundle.
class LocalToolchainEnvironment extends ToolchainEnvironmentBase {
  @override
  bool get supported => false;
}

/// The instance that the runner and the environment page share.
final ToolchainEnvironment forgeToolchainEnvironment =
    LocalToolchainEnvironment();
