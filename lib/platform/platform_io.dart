// Local platform IO facade for this app.
//
// The shared core (`package:qfli_studio_core`) does not yet expose a browser
// filesystem abstraction; its `services/platform_io.dart` is staged but not
// integrated. Until it is, the Web compiler runner and its browser test need a
// platform-neutral file API that is real on native and memory/IndexedDB-backed
// in the browser.
//
// Native platforms re-export `dart:io` unchanged, so existing behavior is
// preserved. When the shared core ships `platform_io.dart`, these files can be
// deleted and the two imports switched back to `package:qfli_studio_core/...`.
export 'platform_io_native.dart'
    if (dart.library.js_interop) 'platform_io_browser.dart';
