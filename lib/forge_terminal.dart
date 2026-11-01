/// QFLIForge terminal hook, resolved per platform at compile time.
///
/// Native/desktop keeps the `dart:io` implementation; the web build gets a
/// no-op delegate so `main.dart` can reference one symbol everywhere without
/// pulling `dart:io` into a browser compilation.
library;

export 'forge_terminal_native.dart'
    if (dart.library.js_interop) 'forge_terminal_browser.dart';
