import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps Android's native loading layer visible until the home page is laid out.
class AndroidStartup {
  AndroidStartup({required WidgetsBinding binding}) : _binding = binding;

  static const _channel = MethodChannel('qfli_forge/startup');
  final WidgetsBinding _binding;

  void holdFirstFrame() => _binding.deferFirstFrame();

  Future<void> complete(
    Future<void> Function(ValueChanged<double> onProgress) load,
  ) async {
    try {
      await load((progress) => unawaited(_reportProgress(progress)));
      // Loading updates the home route and saved theme before this layout.
      await _binding.endOfFrame;
    } finally {
      _binding.allowFirstFrame();
    }
  }

  Future<void> _reportProgress(double progress) async {
    try {
      await _channel.invokeMethod<void>('startupProgress', {
        'progress': progress,
      });
    } on MissingPluginException {
      // Other entry shells may omit the optional progress channel.
    } on PlatformException {
      // Progress reporting must not prevent Flutter from presenting its UI.
    }
  }
}
