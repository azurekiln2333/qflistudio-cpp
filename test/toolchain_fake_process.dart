import 'dart:convert';
import 'dart:io';

/// In-memory [Process] for a fake command. [stdout] and [stderr] are delivered
/// as the chunks of [chunks].
Process fakeProcess({
  String stdout = '',
  String stderr = '',
  int exitCode = 0,
  List<List<int>>? chunks,
}) => _FakeProcess(
  chunks ?? (stdout.isEmpty ? const <List<int>>[] : [utf8.encode(stdout)]),
  stderr.isEmpty ? const <List<int>>[] : [utf8.encode(stderr)],
  exitCode,
);

class _FakeProcess implements Process {
  _FakeProcess(this._stdout, this._stderr, this._exitCode);

  final List<List<int>> _stdout;
  final List<List<int>> _stderr;
  final int _exitCode;

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.fromIterable(_stdout);

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.fromIterable(_stderr);

  @override
  IOSink get stdin => throw UnsupportedError('a fake command reads no input');

  @override
  Future<int> get exitCode async => _exitCode;

  @override
  int get pid => 0;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
