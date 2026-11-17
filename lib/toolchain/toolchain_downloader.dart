import 'dart:async';
import 'dart:io';

/// Opens a GET request. Test seam of [ToolchainDownloader].
typedef ToolchainHttpClientFactory = HttpClient Function();

/// Downloads one pinned file.
///
/// The bytes go to `<file>.part`. [ToolchainDownloader.download] renames that
/// file to [File] only after the transfer finished, so a partial file never
/// looks like a complete one.
class ToolchainDownloader {
  ToolchainDownloader({ToolchainHttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  /// Give up when the connection does not open within this time.
  static const Duration connectTimeout = Duration(seconds: 20);

  /// Gives up when no byte arrives for [stallTimeout]. A slow line stays
  /// valid, a dead socket does not hang the page.
  static const Duration stallTimeout = Duration(seconds: 60);

  final ToolchainHttpClientFactory _clientFactory;

  HttpClient? _client;
  StreamSubscription<List<int>>? _subscription;
  _StallWatch? _watch;

  /// Receives the byte count as the transfer advances.
  void Function(int received)? onReceived;

  /// Downloads [url] into [file] and returns the byte count.
  ///
  /// [cancel] is polled for every chunk. [offset] continues a `.part` file
  /// from an earlier attempt and asks the server for the rest. Throws
  /// [ToolchainDownloadException] with a short Chinese message on a network
  /// error, a timeout or a cancel; the `.part` file stays in place.
  Future<int> download(
    String url,
    File file, {
    required bool Function() cancel,
    int offset = 0,
  }) async {
    final partFile = File('${file.path}.part');
    final client = _clientFactory()
      ..connectionTimeout = connectTimeout
      ..autoUncompress = true;
    _client = client;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.userAgentHeader, 'QFLIForge');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response = await request.close();
      final resumed =
          offset > 0 && response.statusCode == HttpStatus.partialContent;
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw ToolchainDownloadException('下载失败：服务器返回 ${response.statusCode}。');
      }
      final start = resumed ? offset : 0;
      final total = _totalBytes(response, start);
      sink = partFile.openWrite(
        mode: start > 0 ? FileMode.append : FileMode.write,
      );
      var received = start;
      var failed = false;
      var stalled = false;
      final done = Completer<void>();
      final watch = _watch = _StallWatch(stallTimeout, () => stalled = true);
      onReceived?.call(received);
      _subscription = response.listen(
        (chunk) {
          watch.reset();
          if (failed) return;
          if (cancel()) {
            failed = true;
            if (!done.isCompleted) done.complete();
            return;
          }
          received += chunk.length;
          sink?.add(chunk);
          onReceived?.call(received);
        },
        onError: (Object error, StackTrace stackTrace) {
          failed = true;
          if (!done.isCompleted) done.completeError(error, stackTrace);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      try {
        await done.future;
      } finally {
        watch.stop();
        await sink.close();
        sink = null;
      }
      if (cancel()) {
        throw const ToolchainDownloadException('已取消下载。', cancelled: true);
      }
      if (stalled) {
        throw ToolchainDownloadException(
          '下载停止：${stallTimeout.inSeconds} 秒没有收到数据。',
        );
      }
      if (failed) {
        throw const ToolchainDownloadException('下载中断：连接已断开。');
      }
      if (total != null && received != total) {
        throw ToolchainDownloadException(
          '下载不完整：收到 $received 字节，应为 $total 字节。',
        );
      }
      await partFile.rename(file.path);
      return received;
    } on SocketException catch (error) {
      throw ToolchainDownloadException(_socketMessage(error));
    } on HandshakeException {
      throw const ToolchainDownloadException('下载失败：无法建立加密连接。');
    } on TimeoutException {
      throw ToolchainDownloadException(
        '下载失败：${connectTimeout.inSeconds} 秒内没有连上服务器。',
      );
    } on HttpException {
      throw const ToolchainDownloadException('下载失败：连接被服务器关闭。');
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _watch?.stop();
      _watch = null;
      await sink?.close();
      _client?.close(force: true);
      _client = null;
    }
  }

  /// Stops a running [download]. The `.part` file stays on disk.
  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    _watch?.stop();
    _watch = null;
    _client?.close(force: true);
    _client = null;
  }

  static int? _totalBytes(HttpClientResponse response, int start) {
    final contentLength = response.contentLength;
    if (contentLength < 0) return null;
    return response.statusCode == HttpStatus.partialContent
        ? contentLength + start
        : contentLength;
  }

  static String _socketMessage(SocketException error) {
    final detail = error.message.isEmpty ? '' : '：${error.message}';
    return '下载失败：无法连接服务器$detail';
  }
}

/// Reports when no data arrived for a while.
class _StallWatch {
  _StallWatch(this.timeout, this.onStall) {
    reset();
  }

  final Duration timeout;
  final void Function() onStall;
  Timer? _timer;

  void reset() {
    _timer?.cancel();
    _timer = Timer(timeout, onStall);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Failure of a setup action with a short Chinese message.
class ToolchainDownloadException implements Exception {
  const ToolchainDownloadException(this.message, {this.cancelled = false});

  final String message;

  /// True when the user called [ToolchainDownloader.cancel].
  final bool cancelled;

  @override
  String toString() => message;
}
