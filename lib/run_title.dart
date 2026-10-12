import 'package:path/path.dart' as p;

/// Short command-style label for one QFLIForge run.
///
/// Contract: `run <project-relative entry path>`, identical for success,
/// unavailable toolchains and interpreter fallback. It never carries backend
/// names such as Clang, GCC or "interpreter". Program stdout/stderr and the
/// numeric exit status are unaffected.
///
/// The relative path is derived with an explicit `package:path` context chosen
/// from the path shape (Windows drive/UNC vs POSIX) rather than the platform
/// default, so a browser build never resolves through the default URL path
/// context and a Windows path never goes through POSIX semantics.
String runTitle({required String projectPath, required String entryFile}) {
  final context = _pathContextFor(entryFile);
  final relative = context.relative(
    context.normalize(entryFile),
    from: context.normalize(projectPath),
  );
  return 'run ${relative.replaceAll(r'\', '/')}';
}

/// Windows paths start with a drive (`C:\`) or a UNC share (`\\server\`).
p.Context _pathContextFor(String entryFile) {
  final isWindows = p.windows.isAbsolute(entryFile) &&
      (p.windows.rootPrefix(entryFile).isNotEmpty);
  return isWindows ? p.windows : p.posix;
}
