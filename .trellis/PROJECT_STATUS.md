# 项目交接状态

更新日期：2026 年 11 月 21 日

## 已验证 UI 与安装包

共享界面属于 qfli_studio_core。
应用通过 StudioProfile 配置共享界面。
云端固定 core 提交 cbaa4a4166461baafff7c1a343bd3ca1865fcc4f。
该版本含编辑器快捷栏、会话侧栏和新版聊天布局。

安装包分支提交为 6908e44ecb5edbc8a3a1388d40ec8d3166a35ac5。
云构建运行号为 44797136694。
文档同步不会触发安装包构建。
七个任务全部成功，覆盖六个平台。
Android 分别构建 ARM64 和 x86_64。
所有产物的 app/core 来源提交均已检查。
Trellis 交接提交为 f2529c32da5e52ba1efbd0c44d685284f494e1fc。
GitHub main 已包含 UI 同步和交接记录。
主分支安装包运行 44822103705 已成功。
该运行固定 core 提交 cbaa4a4166461baafff7c1a343bd3ca1865fcc4f。
七项任务全部成功，七份产物均未过期。

签名限制：Android 使用临时调试密钥。
Windows 和 Linux 产物未签名。
macOS 使用临时 ad hoc 签名，且未公证。
iOS 与 OHOS 产物未签名。
本轮没有验证设备安装或运行。
产物元数据证据保存在归档 Trellis 任务中。
UI 同步任务归档后位于 .trellis/tasks/archive/2026-11/11-21-sync-core-ui-installers/。

## Native 构建范围

Native 工作流独立构建 Android、iOS 和 OHOS。
Android 包含 ARM64 与 x86_64。
iOS 包含真机 ARM64 和两个模拟器架构。
OHOS 构建 ARM64 编译器与 WASI 资源。

Native 工作流没有 Windows、Linux 或 macOS 工具链包。
桌面安装包会构建 Flutter runner 和插件。
桌面 C/C++ 编译依赖系统中的 clang 或 gcc。
本轮复用了 native 运行 44001588302 的移动端产物。

## 尚未发布的本地进度

原始 main 有 23 个未上推提交。
其中包含未审查的 OHOS 签名配置。
不要从原始 main 推送提交。
原始应用和 core 工作区仍保留本地改动。

本轮使用隔离 app/core 兄弟工作区。
app 分支为 `ci/ui-core-installers-20261121`。
core 固定在提交 `cbaa4a4166461baafff7c1a343bd3ca1865fcc4f`。
请从这对工作区继续构建和检查。

本地 OHOS 终端与启动进度仍未进入云端 app。
详见 .trellis/spec/backend/ohos-runtime.md 的发布状态说明。
桌面环境、图标和便携安装包任务仍为 in_progress。
详情见 .trellis/tasks/11-18-desktop-env-icons-packages/。
该任务的云就绪检查不代表云构建已成功。
AppImage 和单文件 Windows 包也未包含在本轮。

图标工作包已有提交 7eb0dd5，仍待整合和推送。
CI 工作包分支有四个提交和未提交修改。
CI 工作包含 AppImage 和 Windows 便携包改动。
该分支尚未完成工作包复核或云构建。
CI readiness 报告只记录构建前检查。
ENV-CORE 报告记有 17 项测试通过。
Windows 端到端安装流程仍未验证。
ENV-CORE 和 ENV-UI 工作树仍有未提交修改。
整合前应逐个复核工作包和测试。
不要把这些工作包并入本轮 UI 提交。

## 后续检查

检查隔离工作区和配套 core 是否一致。
继续前先审查桌面任务各工作包的提交和报告。
不要把本地 OHOS 进度标记为已发布。
