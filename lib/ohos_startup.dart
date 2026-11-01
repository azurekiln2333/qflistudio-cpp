import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the OHOS native ArkUI splash visible until the ready home page is laid
/// out, reporting real initialization progress to it.
///
/// The OHOS shell draws its own splash through `FlutterPage(splashScreenView:)`
/// and hides it on Flutter's first frame, so without a hold that frame would be
/// the `SplashScreen` fallback instead of the loaded home page. Android keeps
/// [AndroidStartup]; other platforms are unchanged.
class OhosStartup {
  OhosStartup({required WidgetsBinding binding, MethodChannel? channel})
    : _binding = binding,
      _channel = channel ?? const MethodChannel('qflistudio/platform');

  /// Floor shared with the JVMX shell so a warm start still shows the artwork.
  static const minimumDisplay = Duration(milliseconds: 1100);

  /// Settle time after loading so the native progress bar completes visibly.
  static const settleDelay = Duration(milliseconds: 320);

  /// Subscribed-before-report gap, matching JVMX. The ArkUI component can mount
  /// after Dart starts; reporting immediately would let a fast bootstrap finish
  /// before the native splash subscribes, leaving its bar at zero.
  static const subscribeDelay = Duration(milliseconds: 160);

  final WidgetsBinding _binding;
  final MethodChannel _channel;

  void holdFirstFrame() => _binding.deferFirstFrame();

  /// Loads data while reporting progress, then allows the first frame.
  ///
  /// The floor is measured from entry, as in JVMX: after loading only the
  /// remaining time is awaited, concurrently with the settle delay. The
  /// durations are parameters only so tests can avoid real delays.
  Future<void> complete(
    Future<void> Function(ValueChanged<double> onProgress) load, {
    Duration minimum = minimumDisplay,
    Duration settle = settleDelay,
    Duration subscribe = subscribeDelay,
  }) async {
    final elapsed = Stopwatch()..start();
    try {
      await Future<void>.delayed(subscribe);
      unawaited(_reportProgress(0.05));
      await load((progress) => unawaited(_reportProgress(progress)));
      final remaining = minimum - elapsed.elapsed;
      await Future.wait([
        if (remaining > Duration.zero) Future<void>.delayed(remaining),
        Future<void>.delayed(settle),
      ]);
      // Loading swaps the splash route for the home route and applies the saved
      // theme; wait for that build and layout to finish.
      await _binding.endOfFrame;
    } finally {
      _binding.allowFirstFrame();
    }
  }

  /// Progress reporting must never prevent Flutter from presenting its UI.
  Future<void> _reportProgress(double progress) async {
    if (!progress.isFinite) return;
    try {
      await _channel.invokeMethod<void>('startupProgress', {
        'progress': progress.clamp(0.0, 1.0),
      });
    } on MissingPluginException {
      // Other entry shells use the Flutter startup screen.
    } on PlatformException catch (error) {
      debugPrint('Startup progress unavailable: ${error.code}');
    }
  }
}
