# Design

Use JVMX `Index.ets` as the native splash reference, retaining the existing C FlutterAbility and compiler registration. `qflistudio/platform.startupProgress` validates a finite value and emits a clamped progress event. The native component subscribes only while mounted. Dart defers the OHOS first frame before runApp, reports AppBootstrap progress, waits for the ready home frame, then releases the frame in finally. Other platforms retain their current startup routes. The shared UI remains Flutter, as in JVMX.

Source icons are AppScope app_icon.png, entry icon.png, and assets/app_icon.png. Verify all are current and inspect their packaged counterparts. Preserve the latest `.cpp` bundle ID. Device verification must explicitly target that bundle because the earlier `.forge` installation can coexist.
