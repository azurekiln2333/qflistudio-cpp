import 'package:flutter/services.dart';

import 'native_clang_runner.dart';

/// Android's native executor retains the existing optional C fallback.
class AndroidClangRunner extends NativeClangRunner {
  AndroidClangRunner({
    super.channel = const MethodChannel('qfli_forge/native'),
    super.events,
  }) : super(
         backendName: 'Android Clang',
         runIdPrefix: 'android',
         allowCFallback: true,
         cancellationExitTimeout: const Duration(seconds: 5),
       );
}
