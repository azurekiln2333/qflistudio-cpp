import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'clang_runner.dart';

/// Compatibility entry point for the shared native C/C++ compiler backend.
class CppProgramRunner implements ProgramRunner {
  const CppProgramRunner();

  static const Set<String> _sourceExtensions = {
    '.cpp',
    '.cc',
    '.cxx',
    '.hpp',
    '.hh',
  };

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    if (!_sourceExtensions.contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }
    return ClangProgramRunner().run(
      projectPath: projectPath,
      entryFile: entryFile,
    );
  }
}
