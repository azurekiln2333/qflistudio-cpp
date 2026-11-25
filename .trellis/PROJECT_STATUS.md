# 项目交接状态

更新日期：2026 年 11 月 25 日

## 构建与发布规则

所有构建都在 GitHub Actions 运行。
本地不再运行任何构建。
本地历史构建只作为历史证据。
本记录不触发工作流，也不推送代码。
当前本地 `main` 尚未发布。
本地 HEAD 为 `9e34dcc3f1dfd5f4ba306c7df983e584dbad9b94`。
本地跟踪引用 `github/main` 为 `dcb4355a6e9e3526db8b69956959dc1680a44872`。
该本地快照显示 `main` 比远端多 32 个提交。
协调者须在推送前复核远端引用和提交范围。

## 本地待发布功能批次

当前 `main` 已合并运行时与桌面功能工作。
九个功能提交构成当前功能批次。

| 提交 | 内容 |
| --- | --- |
| `b930c01` | 进程内编译器与 WASM 解释器 |
| `d7345f1` | OHOS 终端桥接 |
| `a1a3bfe` | 终端委托与启动握手 |
| `27db9ff` | OHOS 原生启动进度 |
| `3cc8a1f` | 共享终端命令委托 |
| `f834dbe` | 运行时与课程测试 |
| `5f8f962` | 桌面工具链环境契约 |
| `7eb0dd5` | 各平台应用图标 |
| `2924b76` | 工具链安装与便携包 |

桌面分支已由 `b5896d9` 合并到本地 `main`。
合并包含 `b894ec1` 工具链目录修复。
合并包含 `d673a23` CI 辅助测试。
`9e34dcc` 修复 core 补丁测试的换行。
上表只列九个功能提交。
上表未列出本地新增的全部提交。

新增 Windows 单文件包和 Linux AppImage 代码已进入本地历史。
桌面工具链配置和图标代码也已进入本地历史。
这些改动尚未推送，也没有新的云端验收。
发布签名配置 `ed4c9c0` 不在当前 `main` 历史，未上传 GitHub。
历史 `default` 签名字段和本机证书路径仍存在。
协调者与 pi-ci 须单独审查现存签名字段和本机证书路径。
不得据此声称仓库不含签名材料。

## GitHub 已验证的历史结果

| 工作流 | 运行 | 源提交 | 结果与边界 |
| --- | --- | --- | --- |
| Native artifacts | `44001588302` | `ba5c33a` | 历史移动端依赖构建成功，不含本地运行时重写 |
| Application installers | `44125206686` | `1969ef4` | 七个 job 成功，覆盖六个平台 |
| Application installers | `44797136694` | `6908e44` | 七个 job 成功，iOS 未签名构建成功 |
| Application installers | `44822103705` | `f2529c3` | 七个 job 成功，固定 core `cbaa4a4` |

这些成功运行不验证当前本地 HEAD。
旧安装包不含 AppImage 和 Windows 单文件包。
历史运行也不证明当前 OHOS 桥接已上云。
历史 OHOS 手机审计为 212/212。
历史生产界面验证覆盖普通运行、停止和再次运行。
这些设备结果只适用于当时的精确产物。
本轮没有重跑测试、构建或设备验收。

## 推送后必须验证

先复核签名配置和待推送提交。
协调者推送后运行当前 `main` 的 Native 工作流。
确认 Native 产物对应当前源码提交。
再运行 Application installers 工作流。
确认应用工作流下载匹配的 Native 产物。
检查七个安装包 job 的结果和 Node.js 24 注记。
检查 Windows portable EXE 和 Linux AppImage。
检查包内清单与 SHA256SUMS。
检查产物来源提交和固定 core 版本。
检查 Actions artifact 是否已上传。
当前源代码尚无这些新运行证据。

云端构建成功不等于真机验收。
OHOS 当前合并包仍待设备验收。
iOS、Web 和 macOS 应用运行门禁仍未关闭。
Windows 工具链须实测 Clang、GCC、C 和 C++。
Linux、macOS 安装流程仍待目标环境验收。
macOS GCC 需求仍待产品决策。
签名、安装和公证状态须按产物分别记录。

## Trellis 任务状态

| 任务 | 状态 | 当前交接 |
| --- | --- | --- |
| `00-bootstrap-guidelines` | `in_progress` | 五份后端和六份前端通用规范仍有模板 |
| `10-01-cross-platform-native-runtime` | `in_progress` | 保留 iOS、Web、macOS 和当前源设备门禁 |
| `10-22-offline-standalone-ide` | `in_progress` | 200 对课程已在独立任务验收，新增 160 对和总体验收未完成 |
| `11-18-desktop-env-icons-packages` | `in_progress` | 等待推送后云端验证及真实安装验收 |
| `10-09-unified-terminal-current-file` | 已归档 | 完成日 2026-11-25，提交 `41ffe52` |
| `10-12-c-cpp-substantive-curriculum` | 已归档 | 保留完成日 2026-10-16 |
| `11-17-ci-app-installers` | 已归档 | 保留 2026-11-21 的历史成功运行证据 |

课程归档不关闭离线 IDE 总任务。
旧安装包运行不关闭桌面新包验收。

## 签名与产物边界

历史安装包含调试签名、未签名或 ad hoc 产物。
本轮未验证设备安装或运行。
生产签名、Apple 公证和 OHOS 签名须单独授权。
不得把本地证书路径或口令复制到交接记录。
推送前由协调者与 pi-ci 审查签名材料。
