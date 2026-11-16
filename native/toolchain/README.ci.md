# GitHub native 构建

本仓库通过 GitHub Actions 构建 native 依赖包。
工作流覆盖 Android、OHOS 和 iOS。
本轮不会生成 APK、HAP 或 IPA。

## 产物范围

| 产物名称 | 内容 | 用途 |
| --- | --- | --- |
| `qfli-native-android-arm64-v8a` | ARM64 编译器、链接器、进程启动器、资源与验证记录 | Android ARM64 打包 |
| `qfli-native-android-x86_64` | x86_64 编译器、链接器、进程启动器、资源与验证记录 | Android x86_64 打包 |
| `qfli-native-ohos-arm64-v8a` | 编译器静态库、解释器静态库、头文件与 WASI 资源 | OHOS ARM64 打包 |
| `qfli-native-ios` | 真机与模拟器静态库、XCFramework、头文件与 WASI 资源 | iOS 打包 |
| `qfli-ohos-wasi-resources` | WASI 头文件、标准库、Clang 资源与许可证 | OHOS 运行时资源 |
| `logs-*` | 构建日志与 CMake 配置 | 失败排查 |
| `ios-slice-*` | 单个 iOS 架构的中间产物 | XCFramework 合并 |

Android 包使用 LLVM 15.0.7。
Android 包使用 NDK 27.0.12077973。
两个 Android 包分别校验架构和 16 KiB 对齐。
验证过程还校验 C、C++ 和混合链接。
这些校验不能证明设备运行成功。

OHOS 资源使用 LLVM 22.1.0 和 WASI SDK 33。
OHOS 资源包不含编译器或解释器的原生归档。
完整 OHOS 包另含两份原生静态库。
云端采用公开 SDK 5.1.0.107，即 API 18。
现有本地包使用 SDK 26.0.0.105。
下载包会记录使用的 SDK 版本。
更换 SDK 后仍须验证应用运行。

iOS 包包含真机 ARM64。
iOS 包包含模拟器 ARM64 和 x86_64。
三个架构分别构建，再合并为 XCFramework。
工作流校验原生链接，不验证签名或设备运行。
Web 暂无本轮云端构建任务。

## 下载

1. 打开仓库的 **Actions** 页面。
2. 选择 **Native artifacts**。
3. 打开运行记录。
4. 在 **Artifacts** 中下载目标产物。

只有完成上传的任务才提供下载。
某个平台失败时，其他平台仍可上传产物。

运行摘要也提供每个产物的下载链接。
测试分支为 `ci/native-artifacts`。
主分支合入工作流后，可手动选择构建范围。
主分支和测试分支的构建文件修改会触发构建。

依赖包保留 30 天。
日志保留 7 天。
iOS 中间产物保留 7 天。
请下载需要长期保留的产物。
GitHub 的下载操作可能要求登录。

## Android 本地使用

先解压 GitHub 下载的外层 ZIP。
请校验内层归档的 SHA256。
再把内层 `.tar.gz` 解压到此目录：

```text
native/build/android-package/
```

解压后的目录如下：

```text
android-package/
  jniLibs/<abi>/
    libqfli_clang.so
    libqfli-ld.lld-.so
    libqfli_executor.so
    libc++_shared.so
  assets/qfli_toolchain/<abi>.zip
  assets/qfli_toolchain/<abi>.zip.sha256
  manifests/<abi>.json
  manifests/build-<abi>.json
  validation/<abi>/
  SHA256SUMS-<abi>
```

两个架构可解压到同一目录。
Gradle 默认读取该目录中的库与资源。
Gradle 不会自动重编 LLVM。
其他路径可通过 `qfliToolchainPackage` 指定。

## OHOS 本地使用

完整产物名为 `qfli-native-ohos-arm64-v8a`。
先解压外层 ZIP，再校验内层归档。
把内层 `.tar.gz` 解压到仓库根目录。
归档会恢复以下目录：

```text
native/build/ohos-portable/package/
ohos/entry/src/main/resources/rawfile/qfli_toolchain/
```

单独资源产物名为 `qfli-ohos-wasi-resources`。
解压资源产物后，请复制以下两个文件：

```text
ohos-wasi.zip
ohos-wasi.zip.sha256
```

目标目录如下：

```text
ohos/entry/src/main/resources/rawfile/qfli_toolchain/
```

OHOS App 使用以下静态库：

```text
native/build/ohos-portable/package/lib/arm64-v8a/libqfli_compiler.a
native/build/ohos-portable/package/lib/arm64-v8a/libqfli_wasm.a
```

App 构建会直接导入这两个静态库。
App 构建仍会编译或更新原生桥接层。
修改编译器或运行时后，必须重建对应静态库。
删除本地预编译包后，必须先恢复它。
仅下载 WASI 资源包不能替代这些静态库。

## iOS 本地使用

下载 `qfli-native-ios`。
先解压外层 ZIP，再校验内层归档。
把内层 `.tar.gz` 解压到以下目录：

```text
native/build/ios-portable/package/
```

在 Mac 上进入仓库根目录。
本地安装器要求 Python 3.9 或更高版本。
运行配置安装器：

```sh
python3 native/toolchain/install-ios-package.py --package native/build/ios-portable/package
```

安装器会生成本机使用的 xcconfig。
配置路径为 `ios/Flutter/NativeRuntime.generated.xcconfig`。
随后使用原有 Flutter iOS 打包命令。
应用签名仍需本机的 Apple 开发配置。

## 本地空间

无需拆分仓库即可使用云端构建。
云端构建不会自动删除本地缓存。
以下容量来自 2026 年 11 月 17 日盘点。

| 路径 | 大小 | 删除条件 |
| --- | --- | --- |
| `native/build/llvm-android-arm64-v8a/` | 13.71 GiB | 保留已校验的 Android 最终包 |
| `native/build/llvm-android-x86_64/` | 13.42 GiB | 保留已校验的 Android 最终包 |
| `native/build/portable-deps/` | 2.96 GiB | 接受重建时重新下载依赖 |
| `native/build/emsdk-4.0.23/` | 1.62 GiB | 接受 Web 重建时重新安装工具 |
| `native/build/msys64/` | 0.83 GiB | 暂不使用旧 Windows LLVM 构建 |

删除编译缓存会失去本地增量构建能力。
请保留 `native/build/android-package/`。
请保留 `native/build/ohos-portable/package/`。
请保留 OHOS 资源 ZIP 及校验文件。
请勿整体删除 `native/build/`。
其中的 `ci-publish` 是 Git 工作树。
源码目录也可能含有未提交修改。
历史验证目录可能包含唯一的测试记录。

## 追踪与校验

每个下载包都记录源码提交和 Actions 运行编号。
每个下载包都包含文件校验清单。
归档旁的 `.sha256` 文件校验整个归档。
Android 的 `toolchain.json` 还记录库文件校验值。
OHOS 包的 `validation/` 记录资源与链接验证。
iOS 包的 `manifests/` 记录各架构与合并验证。

工作流只上传最终包和验证记录。
LLVM 源码、对象文件和 SDK 留在云端构建机。
本地已有缓存不会因云端构建而自动删除。
