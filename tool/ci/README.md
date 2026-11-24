# GitHub 安装包构建

本仓库通过 GitHub Actions 构建应用安装包。
工作流名称为 **Application installers**。
工作流覆盖 Android、iOS、OHOS、Windows、Linux 和 macOS。
工作流不构建 Web 版本。

## 公共 UI 版本

安装包使用共享 core 的 `cbaa4a4` 提交。
该提交包含编辑器快捷栏和新版侧栏。
该提交也更新主页导航与聊天组件。
Forge 保留离线策略和 C/C++ 工具。
Forge 不显示联网产品的 AI 入口。
本地路径依赖读取 core 的工作区内容。
云构建按提交号检出 core。
更新 UI 时，请同时更新工作流和兼容脚本的版本。

本地测试通过。
本轮云构建详情见项目状态记录。
记录位置为 `.trellis/PROJECT_STATUS.md`。

## 已验证的云端构建

以下任务已于 2026 年 11 月 17 日（UTC）成功。
运行编号为 `44120892921`。
运行分支为 `ci/app-installers`。
运行提交为 `5a9522a`。

| 平台 | 任务名称 | 下载产物 |
| --- | --- | --- |
| Android ARM64 | Android arm64-v8a APK | `app-android-arm64-v8a` |
| Android x86_64 | Android x86_64 APK | `app-android-x86_64` |
| Windows x64 | Windows x64 installer | `app-windows-x64` |
| Linux x64 | Linux x64 packages | `app-linux-x64` |
| macOS 通用架构 | macOS universal disk image | `app-macos-universal` |
| iOS ARM64 | iOS ARM64 unsigned IPA | `app-ios-arm64-unsigned` |
| OHOS ARM64 | OHOS ARM64 unsigned HAP and APP | `app-ohos-arm64-unsigned` |

七个任务均通过构建和安装包内容校验。
本轮未验证设备运行。
本轮未验证界面操作。
上述记录不包含本次新增的单文件版本。
新增版本仍需通过云端构建。

## 最近一次云构建

运行编号为 `44797136694`。
运行时间为 2026 年 11 月 20 日（UTC）。
运行分支为 `ci/ui-core-installers-20261121`。
七个任务均以 `success` 结束。
构建使用 core 提交 `cbaa4a4`。
构建使用 app 提交 `6908e44`。
所有产物的来源提交均匹配。
本轮未验证设备安装或运行。

任务记录位于 `.trellis/tasks/archive/2026-11/11-21-sync-core-ui-installers/`。
产物元数据证据保存在任务目录的 `cloud-evidence/`。
SHA256SUMS 格式通过校验。
未下载完整产物或重算载荷哈希。

## 产物范围

| 产物名称 | 安装包文件 | 签名状态 |
| --- | --- | --- |
| `app-android-arm64-v8a` | `qfli-forge-android-arm64-v8a-test-signed.apk` | 临时调试密钥 |
| `app-android-x86_64` | `qfli-forge-android-x86_64-test-signed.apk` | 临时调试密钥 |
| `app-windows-x64` | `qfli-forge-windows-x64-setup.exe`、`qfli-forge-windows-x64.zip`、`qfli-forge-windows-x64-portable.exe` | 未签名 |
| `app-linux-x64` | `qfli-forge-linux-x64.deb`、`qfli-forge-linux-x64.tar.gz`、`qfli-forge-linux-x64.AppImage` | 未签名 |
| `app-macos-universal` | `QFLIForge-macos-universal.dmg` | ad hoc 签名，未公证 |
| `app-ios-arm64-unsigned` | `QFLIForge-ios-arm64-unsigned.ipa`、`QFLIForge-ios-arm64-unsigned.xcarchive.zip` | 未签名 |
| `app-ohos-arm64-unsigned` | `qfli-forge-ohos-arm64-unsigned.hap`、`qfli-forge-ohos-arm64-unsigned.app` | 未签名 |

每个产物还包含 `SHA256SUMS`、`SIGNING.txt`、`provenance.json` 和 `LICENSE`。
`LICENSE` 是本仓库的 GNU GPL 第 3 版许可证文本。
OHOS 产物另含 `hap-contents.json`。

## Native 依赖工作流

独立 Native 工作流覆盖 Android、iOS 和 OHOS。
Android 构建 ARM64 与 x86_64 包。
iOS 构建真机和模拟器静态库。
iOS 模拟器包含 ARM64 与 x86_64。
OHOS 构建 ARM64 编译器与 WASI 资源。

该工作流不构建 Windows、Linux 或 macOS 编译器包。
桌面安装包会构建 Flutter runner 和插件。
桌面 C/C++ 编译使用系统 clang 或 gcc。
用户可在环境配置页安装或选择工具链。

## 桌面架构与版本

x64、x86_64 和 AMD64 表示同一架构。
Android 使用 ABI 名称 `x86_64`。
Flutter 桌面使用名称 `x64`。
Windows 和 Linux 暂无 32 位或 arm64 安装包。
macOS 同时包含 arm64 和 x86_64。

| 平台 | 版本 | 首次使用 |
| --- | --- | --- |
| Windows | `setup.exe` | 运行安装器 |
| Windows | `.zip` | 解压后运行应用 |
| Windows | `portable.exe` | 解压到 `%LOCALAPPDATA%/QFLIForge/portable/<构建编号>` 后启动 |
| Linux | `.deb` | 用 apt 安装 |
| Linux | `.tar.gz` | 解压后运行应用 |
| Linux | `.AppImage` | 配置权限后启动 |
| macOS | `.dmg` | 将应用复制到 Applications |

Windows 单文件版不需要管理员权限。

## 工作流动作版本

checkout 使用 v7.0.1。
upload-artifact 使用 v7.0.2。
download-artifact 使用 v8.0.2。
三个版本均使用 Node.js 24。

## 下载

1. 打开仓库的 **Actions** 页面。
2. 选择 **Application installers**。
3. 打开运行记录。
4. 在 **Artifacts** 中下载目标产物。
5. 解压下载的 ZIP。

运行摘要也提供每个产物的下载链接。
只有完成上传的任务才提供下载。
某个平台失败时，其他平台仍可上传产物。
产物保留 30 天。
请下载需要长期保留的安装包。
下载产物需要登录 GitHub 账号。

## 触发方式

推送到 `main` 会触发构建。
测试分支为 `ci/app-installers`。
只有应用源码、资源、平台目录或构建文件的修改才触发构建。
只修改 Markdown 文件不会触发构建。

也可在 **Actions** 页面手动运行工作流。
`target` 选择构建范围，默认值为 `all`。
`native_run_id` 指定 native 依赖包的运行编号。
`native_run_id` 留空时，任务选择 `main` 分支的最新产物。

## GitHub 取消任务

macOS 和 iOS 任务使用 GitHub 的 macOS 构建机。
macOS 构建机容量不足时，GitHub 可能取消等待中的任务。
这类任务没有运行任何步骤。
此时运行结果显示失败，其他平台的产物仍可下载。
请在运行页面选择 **Re-run failed jobs**。

## 安装限制

### Android

APK 使用临时调试密钥签名。
每次运行都会生成新密钥。
安装新 APK 前，请先卸载旧的 CI 版本。
此 APK 不能上传应用商店。
每个 APK 只含一个架构。
每个 APK 内置对应架构的 Clang 工具链。

### iOS

IPA 和 Xcode 归档均未签名。
未签名的 IPA 无法安装到设备。
安装前，请用 Apple 证书和描述文件签名。

### OHOS

HAP 和 APP 均未签名。
未签名的安装包无法安装到设备。
安装前，请用 HarmonyOS 证书和 Profile 签名。
任务在构建前删除 CI 副本中的签名配置。
仓库中的签名配置不参与云端构建。

### Windows

安装器和 ZIP 均未签名。
SmartScreen 可能在安装器启动前告警。
应用调用 PATH 中的 clang 或 gcc 编译程序。
ZIP 含同一套应用文件，不含安装器。

### Linux

安装包在 Ubuntu 24.04 上构建并校验。
`.deb` 依赖 GTK 3 和 libstdc++。
应用调用 PATH 中的 clang 或 gcc 编译程序。
`.tar.gz` 含同一套应用文件，不经 apt 安装。

### macOS

应用使用 ad hoc 签名，未公证。
Gatekeeper 会拦截首次启动，直到用户允许。
应用为通用二进制，含 arm64 和 x86_64 两个架构。
应用调用 PATH 中的 clang 编译程序。

## 安装包内容校验

每个任务在上传前校验安装包。
校验失败时，任务失败并且不上传产物。

| 平台 | 校验内容 |
| --- | --- |
| Android | APK 只含目标架构，并含 Flutter 库、工具链库和工具链资源 |
| Windows | 静默安装、比对安装文件清单、静默卸载 |
| Linux | 通过 apt 安装、校验启动器链接和共享库解析、通过 apt 卸载 |
| macOS | 校验通用架构、校验签名、校验并挂载磁盘映像 |
| iOS | 校验 ARM64 架构、WASI SDK 资源，确认不含描述文件 |
| OHOS | HAP 只含 `arm64-v8a`，并含 Flutter 库、原生运行库和 WASI 资源 |

这些校验不能证明设备运行成功。

## native 依赖包

Android、iOS 和 OHOS 任务不重编 LLVM。
这三类任务下载 **Native artifacts** 工作流的产物。
任务默认选择 `main` 分支上最新的未过期产物。
任务校验归档的 SHA-256 后才解压。
native 依赖包保留 30 天。
产物过期后，请先重新运行 **Native artifacts**。
native 依赖包的说明见 `native/toolchain/README.ci.md`。

## 构建环境

| 项目 | 版本 |
| --- | --- |
| Flutter | 3.41.9 |
| Flutter OHOS | `3.41.9+ohos-1.0.2` |
| HarmonyOS 命令行工具 | 26.0.0.821，即 API 26 |
| Android NDK | 27.0.12077973 |
| Android、Linux 与 OHOS 构建机 | `ubuntu-24.04` |
| Windows 构建机 | `windows-2022` |
| macOS 与 iOS 构建机 | `macos-15` |

工作流按提交号固定 Flutter 和共享 core。
Android、iOS、Windows、Linux 和 macOS 任务使用官方 Flutter。
这五类任务先对共享 core 应用兼容补丁。
补丁文件为 `tool/ci/stock-flutter-core.patch`。
OHOS 任务使用 Flutter OHOS 和未打补丁的共享 core。
HarmonyOS 命令行工具的地址和校验值记录在锁文件中。
锁文件为 `tool/ci/ohos-command-line-tools.lock.json`。

## 追踪与校验

`provenance.json` 记录应用提交、共享 core 提交和 Flutter 提交。
`provenance.json` 还记录运行编号、签名状态和校验项。
移动端的 `provenance.json` 记录所用的 native 依赖包。
`SHA256SUMS` 记录每个安装包的 SHA-256。
`SIGNING.txt` 说明签名状态和安装限制。

## 本地测试

在仓库根目录运行脚本的单元测试：

```sh
python -m unittest discover -s tool/ci -p "test_*.py"
```

单元测试不构建安装包。
安装包构建只在 GitHub 构建机上运行。
