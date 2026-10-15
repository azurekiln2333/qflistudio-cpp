// Browser implementation of the platform IO facade.
//
// The browser has no `dart:io` filesystem. Project storage is a virtual
// `MemoryFileSystem` rooted at `/qfli`, made durable through an IndexedDB
// snapshot. This mirrors the contract staged for the shared core so the Web
// compiler runner can read/write project files without `dart:io`.
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:js_interop';
import 'dart:math';

import 'package:file/file.dart' as file;
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

export 'dart:io' hide Platform;

// Browser flags never query dart:io's unsupported Platform implementation.
abstract final class Platform {
  static const isWindows = false;
  static const isMacOS = false;
  static const isLinux = false;
  static const isAndroid = false;
  static const isIOS = false;
  static const isFuchsia = false;
  static const operatingSystem = 'web';
  static const pathSeparator = '/';
  static const environment = <String, String>{};
}

const _root = '/qfli';
web.IDBDatabase? _database;
Future<void>? _initialization;
Future<void> _writes = Future.value();
var _loading = true;
var _dirty = false;
var _scheduled = false;
String? _revision;
final _writerId =
    '${DateTime.now().microsecondsSinceEpoch}-'
    '${List.generate(4, (_) => Random().nextInt(1 << 30)).join('-')}';
var _commitSequence = 0;

MemoryFileSystem _newMemory() => MemoryFileSystem(
  opHandle: (_, operation) {
    if (!_loading &&
        operation != FileSystemOp.read &&
        operation != FileSystemOp.exists) {
      _markDirty();
    }
  },
);

var _memory = _newMemory();

io.File studioFile(String path) => _StoredFile(_memory.file(path));
io.Directory studioDirectory(String path) =>
    _StoredDirectory(_memory.directory(path));
io.Directory get studioCurrentDirectory => studioDirectory(_root);
io.Directory get studioSystemTemp => studioDirectory('/tmp');

Future<io.FileSystemEntityType> studioEntityType(
  String path, {
  bool followLinks = true,
}) => _memory.type(path, followLinks: followLinks);

io.FileSystemEntityType studioEntityTypeSync(
  String path, {
  bool followLinks = true,
}) => _memory.typeSync(path, followLinks: followLinks);

io.FileSystemException _storageError(Object error, String operation) =>
    error is io.FileSystemException
    ? error
    : io.FileSystemException(
        'Browser project storage failed to $operation: $error',
        _root,
      );

Future<void> initializeStudioStorage() async {
  try {
    await (_initialization ??= _initialize());
  } catch (error) {
    _database?.close();
    _database = null;
    _initialization = null;
    _loading = true;
    _memory = _newMemory();
    throw _storageError(error, 'initialize');
  }
}

@visibleForTesting
Future<void> reloadStudioStorageForTesting({
  bool discardUnsaved = false,
}) async {
  if (discardUnsaved) {
    await _writes.catchError((Object _) {});
  } else {
    await flushStudioStorage();
  }
  _database?.close();
  _database = null;
  _initialization = null;
  _writes = Future.value();
  _loading = true;
  _dirty = false;
  _revision = null;
  _memory = _newMemory();
  await initializeStudioStorage();
}

Future<web.IDBDatabase> _openDatabase() async {
  final opened = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open('qfli-studio-forge-files', 1);
  request.onupgradeneeded = ((web.Event _) {
    try {
      (request.result as web.IDBDatabase).createObjectStore('filesystem');
    } catch (error) {
      if (!opened.isCompleted) {
        opened.completeError(_storageError(error, 'upgrade'));
      }
    }
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final database = request.result as web.IDBDatabase;
    if (opened.isCompleted) {
      database.close();
    } else {
      opened.complete(database);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(
        const io.FileSystemException(
          'Browser project storage failed to open',
          _root,
        ),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(
        const io.FileSystemException(
          'Browser project storage upgrade is blocked',
          _root,
        ),
      );
    }
  }).toJS;
  return opened.future;
}

Future<void> _initialize() async {
  _database = await _openDatabase();
  final loaded = Completer<Object?>();
  final read = _database!
      .transaction('filesystem'.toJS, 'readonly')
      .objectStore('filesystem')
      .get('snapshot'.toJS);
  read.onsuccess = ((web.Event _) => loaded.complete(
    read.result.dartify(),
  )).toJS;
  read.onerror = ((web.Event _) => loaded.completeError(
    const io.FileSystemException(
      'Browser project storage failed to load',
      _root,
    ),
  )).toJS;
  final encoded = await loaded.future;
  _memory.directory(_root).createSync(recursive: true);
  _memory.directory('/tmp').createSync(recursive: true);
  if (encoded != null) {
    if (encoded is! String) {
      throw const FormatException('Invalid browser filesystem snapshot');
    }
    final snapshot = jsonDecode(encoded) as Map<String, dynamic>;
    _revision = snapshot['revision'] as String?;
    if (snapshot['version'] != 1) {
      throw const FormatException('Unsupported browser filesystem version');
    }
    final entries = snapshot['entries'] as List;
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      final path = entry['path'] as String;
      if (!_memory.path.isAbsolute(path) ||
          path == '/' ||
          path == '/tmp' ||
          path.startsWith('/tmp/') ||
          _memory.path.normalize(path) != path) {
        throw const FormatException('Invalid browser filesystem path');
      }
      if (entry['directory'] == true) {
        _memory.directory(path).createSync(recursive: true);
      } else {
        final target = _memory.file(path);
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(base64Decode(entry['bytes'] as String));
        target.setLastModifiedSync(DateTime.parse(entry['modified'] as String));
      }
    }
  }
  _memory.currentDirectory = _root;
  _loading = false;
}

void _markDirty() {
  if (_loading) return;
  _dirty = true;
  if (_scheduled) return;
  _scheduled = true;
  scheduleMicrotask(() {
    _scheduled = false;
    unawaited(
      flushStudioStorage().catchError((Object error) {
        debugPrint('Browser project storage: $error');
      }),
    );
  });
}

Future<void> flushStudioStorage() async {
  await initializeStudioStorage();
  final previous = _writes;
  final current = previous.catchError((Object _) {}).then((_) async {
    if (!_dirty) return;
    try {
      final entries = <Map<String, Object>>[];
      for (final entity in _persistentEntities()) {
        if (entity is file.Directory) {
          entries.add({'path': entity.path, 'directory': true});
        } else if (entity is file.File) {
          entries.add({
            'path': entity.path,
            'bytes': base64Encode(entity.readAsBytesSync()),
            'modified': entity.lastModifiedSync().toIso8601String(),
          });
        }
      }
      final nextRevision = '$_writerId-${++_commitSequence}';
      final encoded = jsonEncode({
        'version': 1,
        'revision': nextRevision,
        'entries': entries,
      });
      _dirty = false;
      await _commitSnapshot(encoded, nextRevision);
    } catch (error) {
      _dirty = true;
      throw _storageError(error, 'save');
    }
  });
  _writes = current;
  await current;
}

Iterable<file.FileSystemEntity> _persistentEntities() sync* {
  // MemoryFileSystem's root listing returns relative names; bind them to '/'.
  for (final child in _memory.directory('/').listSync(followLinks: false)) {
    final path = _memory.path.join('/', child.path);
    if (path == '/tmp') continue;
    if (child is file.Directory) {
      final directory = _memory.directory(path);
      yield directory;
      yield* directory.listSync(recursive: true, followLinks: false);
    } else if (child is file.File) {
      yield _memory.file(path);
    }
  }
}

Future<void> _commitSnapshot(String encoded, String nextRevision) async {
  final transaction = _database!.transaction('filesystem'.toJS, 'readwrite');
  final store = transaction.objectStore('filesystem');
  final currentSnapshot = store.get('snapshot'.toJS);
  final committed = Completer<void>();
  io.FileSystemException? conflict;
  transaction.oncomplete = ((web.Event _) {
    _revision = nextRevision;
    committed.complete();
  }).toJS;
  transaction.onabort = ((web.Event _) {
    if (!committed.isCompleted) {
      committed.completeError(
        conflict ??
            const io.FileSystemException(
              'Browser project save was aborted',
              _root,
            ),
      );
    }
  }).toJS;
  transaction.onerror = ((web.Event _) {
    if (!committed.isCompleted) {
      committed.completeError(
        const io.FileSystemException(
          'Browser project storage is full or unavailable',
          _root,
        ),
      );
    }
  }).toJS;
  currentSnapshot.onsuccess = ((web.Event _) {
    try {
      final previous = currentSnapshot.result.dartify();
      final currentRevision = previous == null
          ? null
          : (jsonDecode(previous as String)
                as Map<String, dynamic>)['revision'];
      if (currentRevision != _revision) {
        conflict = const io.FileSystemException(
          'Project storage changed in another browser tab. Reload before saving.',
          _root,
        );
        transaction.abort();
        return;
      }
      store.put(encoded.toJS, 'snapshot'.toJS);
    } catch (error) {
      conflict = _storageError(error, 'save');
      transaction.abort();
    }
  }).toJS;
  await committed.future;
}

abstract class _StoredEntity<
  T extends file.FileSystemEntity,
  D extends io.FileSystemEntity
>
    extends file.ForwardingFileSystemEntity<T, D> {
  _StoredEntity(this.delegate);
  @override
  final D delegate;
  @override
  file.FileSystem get fileSystem => _memory;
  @override
  file.File wrapFile(io.File delegate) => _StoredFile(delegate);
  @override
  file.Directory wrapDirectory(io.Directory delegate) =>
      _StoredDirectory(delegate);
  @override
  file.Link wrapLink(io.Link delegate) => _memory.link(delegate.path);
  @override
  Future<T> rename(String path) async {
    final result = super.renameSync(path);
    _markDirty();
    await flushStudioStorage();
    return result;
  }

  @override
  T renameSync(String path) {
    final result = super.renameSync(path);
    _markDirty();
    return result;
  }

  @override
  Future<T> delete({bool recursive = false}) async {
    final result = await super.delete(recursive: recursive);
    await flushStudioStorage();
    return result;
  }
}

class _StoredFile extends _StoredEntity<file.File, io.File>
    with file.ForwardingFile {
  _StoredFile(super.delegate);
  @override
  Future<file.File> create({
    bool recursive = false,
    bool exclusive = false,
  }) async {
    createSync(recursive: recursive, exclusive: exclusive);
    await flushStudioStorage();
    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    if (exclusive && existsSync()) {
      throw io.FileSystemException('File already exists', path);
    }
    delegate.createSync(recursive: recursive, exclusive: exclusive);
  }

  @override
  Future<file.File> writeAsBytes(
    List<int> bytes, {
    io.FileMode mode = io.FileMode.write,
    bool flush = false,
  }) async {
    delegate.writeAsBytesSync(bytes, mode: mode, flush: flush);
    await flushStudioStorage();
    return this;
  }

  @override
  Future<file.File> writeAsString(
    String value, {
    io.FileMode mode = io.FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => writeAsBytes(encoding.encode(value), mode: mode, flush: flush);

  @override
  Future<file.File> copy(String path) async {
    final result = wrapFile(delegate.copySync(path));
    await flushStudioStorage();
    return result;
  }
}

class _StoredDirectory extends _StoredEntity<file.Directory, io.Directory>
    with file.ForwardingDirectory<file.Directory> {
  _StoredDirectory(super.delegate);
  @override
  file.Directory childDirectory(String name) =>
      wrapDirectory(_memory.directory(_memory.path.join(path, name)));
  @override
  file.File childFile(String name) =>
      wrapFile(_memory.file(_memory.path.join(path, name)));
  @override
  file.Link childLink(String name) =>
      _memory.link(_memory.path.join(path, name));
  @override
  Future<file.Directory> create({bool recursive = false}) async {
    delegate.createSync(recursive: recursive);
    await flushStudioStorage();
    return this;
  }

  @override
  Future<file.Directory> createTemp([String? prefix]) async {
    final result = wrapDirectory(delegate.createTempSync(prefix));
    await flushStudioStorage();
    return result;
  }
}
