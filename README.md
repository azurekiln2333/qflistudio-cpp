# QFLIForge · C/C++ IDE

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md)

QFLIForge 是面向 C/C++ 的 Flutter IDE。
项目包含编辑器、教程、示例和运行时适配层。
共享核心提供编辑器和工作区界面。
本仓库维护 C/C++ 内容与运行时接入。

## 仓库结构

本应用使用独立的 Git 仓库。
本应用通过相对路径依赖共享核心。

请将两个仓库放在同一父目录。

```text
checkout-parent/
  qfli_studio_core/
  qfli_c/
```

| 路径 | 用途 |
| --- | --- |
| `lib/` | 应用入口与 C/C++ 适配层 |
| `packages/qfli_c_runtime/` | C 源码解释器包 |
| `native/` | 编译器与 WASI 运行时接入 |
| `tool/forge_content/` | 教程与示例内容工具 |
| `ohos/` | OHOS 工程与原生桥接 |
| `test/` | Flutter 与 Dart 测试 |
| `.trellis/` | 开发流程、规范与任务记录 |

该运行时包用 Dart 在应用进程内解释 C 源码。
原生 WASI 工具链位于 `native/`。

编辑器依赖指向共享核心中的修补版本。
其路径为 `../qfli_studio_core/vendor/re_editor`。

## 开发

Dart SDK 约束为 `^3.11.5`。
请使用内含兼容 Dart SDK 的 Flutter SDK。
目标平台还依赖对应的构建工具。
首次下载依赖需要网络。
应用的离线能力不代表构建流程免联网。

请进入本仓库目录。
请获取依赖。

```sh
flutter pub get
```

请选择目标设备。
请启动应用。

```sh
flutter devices
flutter run -d <device-id>
```

## OHOS 构建（开发中）

本节记录待集成的构建脚本。
当前仓库版本尚未包含该脚本。

Windows 构建脚本使用 OHOS Flutter SDK。
脚本读取 `ohos/local.properties` 的 `flutter.sdk`。
参数 `-FlutterSdk` 可指定 SDK 路径。

请先配置 OHOS SDK 与签名。
脚本集成后，请在仓库根目录运行。

```powershell
./tool/build_ohos_release.ps1 -FlutterSdk "D:/path/to/flutter-ohos"
```

脚本刷新依赖。
脚本检查共享核心与编辑器的实际路径。
脚本构建面向 `ohos-arm64` 的 release HAP。
脚本检查签名包是否存在。
默认输出路径为 `build/ohos/hap/entry-default-signed.hap`。
构建结果取决于本机 SDK、签名与原生资源。

## OHOS 终端（开发中）

本节记录待集成的终端编译命令适配层。
当前仓库版本尚未包含该适配层。
该适配层接入内置 Clang 22/WASI 工具链。
编译器输出 WASI 模块。
WASI 解释器运行模块。
终端不会在编译后自动运行程序。

适配层集成后，请参考以下步骤。
请先在终端当前目录准备源文件。
请编译源文件。
请通过相对路径运行程序。

```sh
clang --version
clang hello.c -o hello
./hello
clang++ -std=c++20 main.cpp -o program
./program "argument with spaces"
```

终端从当前目录解析源文件、头文件和输出路径。
路径必须位于终端沙箱内。
命令支持目标文件链接，例如 `clang hello.o -o hello`。
命令支持 `-c`、`-S`、`-E`、`-I`、`-D`、`-O` 与警告选项。
不支持的选项会返回错误。
程序通过当前目录的 `input.txt` 读取有限输入。
WASI 接口不等同于 OHOS 原生接口。
程序不能依此直接调用 OHOS SDK 接口。

## 检查

请运行静态分析。

```sh
flutter analyze
```

请运行 Flutter 测试。

```sh
flutter test
```

请检查中文文档。

```sh
python scripts/ste-lint-zh.py README.md README.zh-TW.md
```

静态分析和测试不代表设备验收通过。
当前源码说明不代表每个功能均已发布。
设备验收必须对应实际安装包与测试记录。
原生运行时规范见 `.trellis/spec/backend/`。
开发流程见 `.trellis/workflow.md`。
