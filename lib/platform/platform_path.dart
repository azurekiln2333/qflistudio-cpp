// Local platform path facade for this app.
//
// The shared core (`package:qfli_studio_core`) does not yet expose
// `services/platform_path.dart`; it is staged but not integrated. Until then,
// browser code needs `package:path` configured with a POSIX root instead of the
// default URL context. When the shared core ships the facade, these files can be
// deleted and the imports switched back to `package:qfli_studio_core/...`.
export 'platform_path_native.dart'
    if (dart.library.js_interop) 'platform_path_browser.dart';
