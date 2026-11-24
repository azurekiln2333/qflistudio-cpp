// Compiler environment of this computer.
//
// A web build compiles nothing on this computer, so the conditional import
// picks a class whose every member is inert and whose `supported` is false.
// Only the native import reads `dart:io`, and the web build never compiles it.
export 'local_toolchain_environment_stub.dart'
    if (dart.library.io) 'local_toolchain_environment_native.dart';
