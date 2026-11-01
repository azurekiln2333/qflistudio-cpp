import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';

/// Browser-safe QFLIForge terminal hook.
///
/// The C/C++ toolchain is only wired on native/OHOS platforms; the web build
/// has no in-app clang terminal bridge. Recognising nothing here lets the
/// shared sandbox keep its own honest unsupported message instead of claiming a
/// command it cannot run.
Future<bool> forgeTerminalCommandDelegate(
  SandboxShellBackend backend,
  String command,
) async => false;
