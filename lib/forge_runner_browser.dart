import 'package:qfli_studio_core/services/studio_profile.dart';

import 'web_clang_runner.dart';

class ForgeProgramRunner implements ProgramRunner {
  ForgeProgramRunner({this.web = const WebClangProgramRunner()});

  final ProgramRunner web;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) => web.run(projectPath: projectPath, entryFile: entryFile);
}
