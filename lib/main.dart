import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'forge_runner.dart';
import 'forge_content_repository.dart';
import 'forge_tools_page.dart';
import 'android_startup.dart';

/// 本 App 的产品名。窗口标题、任务切换器和应用内顶栏都读它。
const String _appTitle = StudioProductCatalog.forge;

/// Forge 档位：同一套内核 UI，收窄成 C/C++ 工具。
///
/// 新建项目使用 C/C++ 模板，运行与工具入口由 Forge 档位提供。
/// 单独提出来是为了让测试能直接断言档位，而不必为了一个常量去跑 `main()`。
final StudioProfile forgeProfile = StudioProfile(
  id: StudioProductCatalog.forgeKey,
  appTitle: _appTitle,
  templates: [ProjectTemplate.empty, ProjectTemplate.c, ProjectTemplate.cpp],
  runner: ForgeProgramRunner(),
  toolsPageBuilder: (_) => const ForgeToolsPage(),
  contentRepositoryFactory: ForgeContentRepository.new,
  isOffline: true,
  productKey: StudioProductCatalog.forgeKey,
  showHomeTabs: false,
  runtimeKind: 'clang-c-cpp-native-and-desktop',
  runtimeStatus: 'unavailable',
  supportedFileExtensions: ['.c', '.cpp', '.cc', '.cxx'],
  entryFileNames: ['main.c', 'src/main.c', 'main.cpp', 'src/main.cpp'],
);

/// Backwards-compatible name for integrations that imported the former C profile.
final StudioProfile cProfile = forgeProfile;

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final startup = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? AndroidStartup(binding: binding)
      : null;
  startup?.holdFirstFrame();

  // 在 runApp 之前定档。
  StudioProfile.current = cProfile;

  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  // 先 runApp 品牌启动页（与原生遮罩同色，无白屏），数据后台并行加载。
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));
  // 首轮布局后再做磁盘/插件初始化；Android 首帧仍由原生启动层等待。
  binding.addPostFrameCallback((_) {
    Future<void> load(ValueChanged<double>? onProgress) => AppBootstrap.run(
      store: store,
      auth: auth,
      settings: settings,
      ready: ready,
      onProgress: onProgress,
    );
    unawaited(startup == null ? load(null) : startup.complete(load));
  });
}
