import 'package:qfli_studio_core/services/studio_profile.dart';

class WebClangProgramRunner implements ProgramRunner {
  const WebClangProgramRunner();

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async => null;
}
