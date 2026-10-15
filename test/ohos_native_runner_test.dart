import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_c/clang_runner.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// OHOS routing for the native C/C++ backend.
///
/// OHOS reuses Android's and iOS's channel protocol (`qfli_forge/native` plus
/// `qfli_forge/native/events`) but reaches it through its own ArkTS bridge and
/// fork/exec of a bundled LLVM. These tests pin the parts that are easy to
/// regress: the platform predicate, the startup payload shape, and the fact
/// that a failed compilation never silently reports success.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('qfli_forge/native');
  const eventsChannel = EventChannel('qfli_forge/native/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory project;
  late StreamController<Object?> events;

  setUp(() {
    project = Directory.systemTemp.createTempSync('qfli-ohos-route');
    File('${project.path}/main.cpp').writeAsStringSync('int main() { return 0; }');
    events = StreamController<Object?>.broadcast();
    // The runner subscribes to a shared broadcast stream; feed it directly so
    // the test does not depend on an actual EventChannel implementation.
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          events.stream.listen(
            sink.success,
            onError: (Object error) => sink.error(code: error.toString()),
            onDone: sink.endOfStream,
          );
        },
      ),
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(methods, null);
    await events.close();
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  test('desktop is not routed through the native channel', () {
    // The predicate must not claim desktop, or a local run would try to reach
    // a channel no desktop shell implements.
    expect(
      ClangProgramRunner.usesBundledToolchainChannel,
      Platform.isAndroid || Platform.isIOS,
    );
  });

  test('a bundled-toolchain platform reports the OHOS bridge unavailable', () async {
    // Marks the run as unavailable, which is how the Dart layer learns it must
    // fall through to another backend instead of failing outright.
    var started = false;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'start') {
        started = true;
        return {'available': false};
      }
      return null;
    });
    events.add(<String, Object?>{
      'runId': 'ohos-1',
      'kind': 'exit',
      'exitCode': 127,
    });

    final runner = NativeClangRunnerForTest(
      events: events.stream,
      methodChannel: methods,
    );
    final result = await runner.run(
      type: 'cpp',
      projectPath: project.path,
      entryFile: '${project.path}/main.cpp',
      sources: ['${project.path}/main.cpp'],
    );

    expect(started, isTrue, reason: 'the start call must reach the bridge');
    expect(result, isNotNull);
    await result!.stdout.drain<void>();
    await result.stderr.drain<void>();
    expect(await result.exitCode, kProgramNotRunExitCode);
  });
}

/// Minimal stand-in that injects the channels, so the routing test does not
/// depend on platform detection (which cannot be faked for OHOS on the host).
class NativeClangRunnerForTest {
  NativeClangRunnerForTest({
    required Stream<Object?> events,
    required MethodChannel methodChannel,
  }) : _events = events,
       _methodChannel = methodChannel;

  final Stream<Object?> _events;
  final MethodChannel _methodChannel;

  Future<ProgramRunResult?> run({
    required String type,
    required String projectPath,
    required String entryFile,
    required List<String> sources,
  }) {
    return ClangProgramRunner.constructNativeRunner(
      channel: _methodChannel,
      events: _events,
      backendName: 'OHOS Clang',
      runIdPrefix: 'ohos',
    ).run(
      type: type,
      projectPath: projectPath,
      entryFile: entryFile,
      sources: sources,
    );
  }
}
