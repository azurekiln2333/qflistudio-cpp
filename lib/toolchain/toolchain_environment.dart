import 'package:flutter/foundation.dart';

/// Compiler family that the desktop runner tries first.
enum CompilerPreference { automatic, clang, gcc }

/// Family that a compiler reports in its `--version` output.
enum CompilerFamily { clang, gcc }

/// Place where the desktop runner found a compiler.
enum CompilerSource {
  /// `QFLI_CLANG`, `QFLI_CLANGXX`, `QFLI_CC` or `QFLI_CXX`.
  environmentVariable,

  /// The directory that the user selected in the environment page.
  configuredDirectory,

  /// A toolchain that a setup action of this application installed.
  managedInstall,

  /// `QFLI_TOOLCHAIN_HOME`, the `toolchain` directory beside the executable
  /// or a known install directory.
  knownLocation,

  /// A bare name that the system resolved through `PATH`.
  systemPath,
}

/// One usable compiler on this computer.
@immutable
class DetectedCompiler {
  const DetectedCompiler({
    required this.language,
    required this.family,
    required this.executable,
    required this.version,
    required this.standard,
    required this.source,
  });

  /// `c` or `cpp`.
  final String language;

  final CompilerFamily family;

  /// Absolute path, or the bare name of a compiler found through `PATH`.
  final String executable;

  /// First line of the `--version` output. Empty when the compiler printed none.
  final String version;

  /// Newest language standard that the probe accepted, for example `c17`.
  final String standard;

  final CompilerSource source;
}

/// Settings that the user controls in the environment page.
@immutable
class ToolchainSettings {
  const ToolchainSettings({
    this.directory,
    this.preference = CompilerPreference.automatic,
  });

  /// Toolchain root that holds `bin/`. Null when the user selected none.
  final String? directory;

  final CompilerPreference preference;
}

/// One setup action that the current platform offers.
@immutable
class ToolchainSetupOption {
  const ToolchainSetupOption({
    required this.id,
    required this.title,
    required this.summary,
    required this.detail,
    this.downloadBytes,
    this.needsAdministrator = false,
    this.installed = false,
    this.removable = false,
  });

  /// Stable identifier, for example `windows-llvm-mingw`.
  final String id;

  /// Short name for the list.
  final String title;

  /// One line that states what the action installs.
  final String summary;

  /// Exact command, or download address and target directory. The page shows
  /// this text before the user confirms.
  final String detail;

  /// Size of the download. Null when the action downloads no pinned file.
  final int? downloadBytes;

  /// True when the action asks for administrator rights.
  final bool needsAdministrator;

  /// True when the result of this action is present and usable.
  final bool installed;

  /// True when [ToolchainEnvironment.remove] can delete the result.
  final bool removable;
}

/// Step of a running setup action.
enum ToolchainSetupPhase {
  preparing,
  downloading,
  verifying,
  extracting,
  running,
  detecting,
  done,
  failed,
  cancelled,
}

/// Progress report of a running setup action.
@immutable
class ToolchainSetupProgress {
  const ToolchainSetupProgress({
    required this.phase,
    this.message = '',
    this.received,
    this.total,
  });

  final ToolchainSetupPhase phase;

  /// Output line of the action, or the reason of a failure.
  final String message;

  /// Bytes received so far. Set only while [phase] is `downloading`.
  final int? received;

  /// Expected bytes. Null when the size is unknown.
  final int? total;

  /// True for `done`, `failed` and `cancelled`.
  bool get isFinal =>
      phase == ToolchainSetupPhase.done ||
      phase == ToolchainSetupPhase.failed ||
      phase == ToolchainSetupPhase.cancelled;
}

/// Desktop compiler environment that the runner and the environment page share.
///
/// Listeners run after the settings change and after a setup action or
/// [remove] changes the installed toolchains.
abstract class ToolchainEnvironment implements Listenable {
  /// True on Windows, Linux and macOS. False on every other platform,
  /// including the web. When false, every other member is a no-op.
  bool get supported;

  /// Current settings. Holds the defaults until [load] completes.
  ToolchainSettings get settings;

  /// Reads the stored settings. Later calls return the same result.
  Future<void> load();

  /// Stores the toolchain root. Null clears it. Does not check the directory.
  Future<void> setDirectory(String? directory);

  Future<void> setPreference(CompilerPreference preference);

  /// Stored settings. The web build cannot start a process that would read
  /// them, so shared code that only reads the settings still compiles there.
  ToolchainSettings? get storedSettings => settings;

  /// Managed toolchain roots, or null.
  ///
  /// Windows only. `ClangProgramRunner` reads them once per run, so a finished
  /// setup works without a restart and `remove` takes effect at the next run.
  /// A build without a file system reports null.
  Future<List<String>>? get managedRoots => null;

  /// Probes the compilers in the order that the runner uses.
  ///
  /// The first entry of each language is the compiler that the next run uses.
  Future<List<DetectedCompiler>> detect();

  /// Setup actions of this platform.
  Future<List<ToolchainSetupOption>> setupOptions();

  /// Starts one setup action.
  ///
  /// The stream reports failures as a `failed` event, never as a stream error.
  /// It closes after the first final event. Only one action runs at a time: a
  /// second call reports `failed` at once. Cancelling the subscription does
  /// not stop the action. Call [cancelSetup] for that.
  Stream<ToolchainSetupProgress> runSetup(String optionId);

  /// Stops the running setup action. Does nothing when none runs.
  Future<void> cancelSetup();

  /// Deletes the result of a removable setup action.
  Future<void> remove(String optionId);
}
