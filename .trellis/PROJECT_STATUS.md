# 项目交接状态

更新日期：2026-11-27。
迁移状态：已完成。
迁移验收快照：`f34deb125fccdb57c717602e0197555fc3a89be6`。
最终交付提交以当前 `main` 为准。
该提交的云端结果以 GitHub Actions 记录为准。

## 源码与发布

GitHub 仓库为 `azurekiln2333/qflistudio-cpp`。
已发布的主分支基线为 `918233c5f32e848e63df11fa4e25639cdf17053a`。
交接确认绑定快照 `f34deb125fccdb57c717602e0197555fc3a89be6`。
协调者已将云端检查分支纳入本地主分支。
该分支的证据提交为 `b8e48afba505ac636877dfb1c5958702485b0832`。
该提交只补充运行证据。
后续迁移修改仍须通过推送闸门。
验收快照的树为 `e59b07f88bbd65e8ec8a858b9a45c418a717edb9`。
后续记录提交保留该快照的构建输入。

运行约束见 `tasks/11-26-github-workspace-migration/research/execution-contract.md`。
运行证据见 `tasks/11-26-six-platform-cloud-delivery/research/cloud-evidence.md`。

## 已验收的云端运行

应用工作流为 `.github/workflows/app-installers.yml`。
已验收 run 为 `45892017304`。
该 run 的第 2 次尝试成功。
该 run 检查的源码为 `82f344657b5074698aa934db77408599d26024c5`。
该 run 的 20 个 job 全部成功。
Flutter 分析未发现问题。
Flutter 测试通过 268 项。
运行记录还覆盖 Python 测试和工作流检查。

原生工作流为 `.github/workflows/native-artifacts.yml`。
应用 run 复用该原生工作流。
移动端原生产物来自同一 run。
桌面包不消费移动端原生产物。
该 run 保留 28 个产物的元数据。
其中应用产物和 Flutter 中间产物各有 7 个。
应用产物和最终原生产物保留 30 天。
Flutter 中间产物、日志和 iOS 切片保留 7 天。
包清单、摘要和签名边界见运行证据。
本轮未下载产物。

| 平台 | 应用产物 | 签名状态 |
| --- | --- | --- |
| Android | `app-android-arm64-v8a`、`app-android-x86_64` | 测试签名 |
| Windows | `app-windows-x64` | 未签名 |
| Linux | `app-linux-x64` | 未签名 |
| macOS | `app-macos-universal` | ad hoc，未公证 |
| iOS | `app-ios-arm64-unsigned` | 未签名 |
| OHOS | `app-ohos-arm64-unsigned` | 未签名 |

第 1 次尝试遇到 Maven Central 的 HTTP 429。
协调者重跑失败 job 后完成第 2 次尝试。
旧 run `45874912699` 的 OHOS 归档只有状态文件。
该旧 run 不作为完整中间产物证据。
应用运行 `45957995690` 检查提交 `69497a97a667b090c461e60ef37487888906ddf4`。
该运行在迁移提交前启动。应用和原生输入保持一致。
记录运行 `45959065568` 检查该验收快照。
该运行的两个 job 全部成功。
云端打包成功不等于设备验收。
`deviceRuntimeVerified` 仍为 `false`。

## 目录与运行规则

目标克隆为 `E:/MyNewProjects/QFLIProjects/qflistudio-cpp`。
共享 core 目录为同级 `qflistudio-core`。
应用依赖路径为 `../qflistudio-core`。
Dart 包名仍为 `qfli_studio_core`。
云端 core 固定为 `1ae4674a4b153701b0c3b3ff04b1a1b77a318611`。
本轮按协调指令更新固定版本。
目标克隆须只绑定 GitHub 远端。
协调者已检查 fetch 和 push URL。

根目录 `AGENTS.md` 保存父目录云端规则原文。
所有构建、测试、分析和 lint 只在云端运行。
中文文本检查也只在云端运行。
历史脚本和模板不构成本地运行授权。
持久任务、规范、研究和工作日志继续跟踪。
身份、会话、缓存和密钥继续忽略。
agent 协作只走 Herdr。

## 保全与签名边界

Trellis 保全摘要见 `tasks/11-26-trellis-cloud-only-rules/research/retained-items-audit-2026-11-27.md`。
旧构建研究摘要见 `tasks/10-22-offline-standalone-ide/research/legacy-build-progress-20261026.md`。
平台适配摘要见 `tasks/11-26-trellis-cloud-only-rules/research/platform-adapters-2026-11-27.md`。
该摘要覆盖 53 份 Claude 定义。
该摘要另列 17 项专用适配定义。
旧构建树已移入外部备份。
本轮只提取可移植的历史结论。
备份不等于可移植内容已经发布。
原始设备记录、证书和二进制不随摘要入库。

`ohos/build-profile.json5` 照常跟踪。
其 DevEco 密码字段为加密密文。
不得将该字段当作明文凭据。
`.p12`、`.cer`、`.p7b` 证书只留本地。
`D:/Keystore` 不得入库。
`~/.ohos/config/material` 不得入库。
生产签名和 Apple 公证仍须单独授权。
未签名的 iOS 和 OHOS 包不具备设备安装验收。

## 迁移门禁与责任

| 门禁 | 所有者 | 验收条件 |
| --- | --- | --- |
| 分支与快照收敛 | 源协调者、p2 | 独有源码和进度均有处置证据 |
| Trellis 发布 | 源协调者、p3 | 批准的持久知识进入主分支 |
| 原生树保全 | p2 | 独有候选和签名副本均有保全记录 |
| 最终提交检查 | 源协调者、p4 | 云端结果绑定最终提交 |
| 生产签名与公证 | 产品所有者 | 单独授权并补齐签名证据 |
| 设备验收 | 产品所有者 | 安装包与实际运行结果有绑定证据 |
| GitHub 发布 | 源协调者 | 推送闸门接受最终提交 |
| 目标一致性 | 源协调者、p5 | 源、远端和目标的提交与树相同 |
| 目标零构建产物 | 目标协调者 | 新目录没有构建输出和依赖缓存 |
| 正式交接 | 源协调者 | 目标 Codex 已通过 Herdr 确认 |
| 旧目录处置 | 所有者 | 保全、目标验收和授权均已完成 |

验收快照处的源目录和目标目录均已干净。
该快照处的提交与树已对齐。
后续记录提交仍须通过推送闸门。
协调者须再次检查最终交付提交。
本页不授权删除旧目录。
本页不授权删除共享 WSL。

## 未完成的产品任务

| 任务 | 状态与边界 |
| --- | --- |
| `00-bootstrap-guidelines` | 通用规范仍有模板 |
| `10-01-cross-platform-native-runtime` | 平台运行和当前源码设备验收仍未完成 |
| `10-22-offline-standalone-ide` | 原有 200 对课程已有历史验收，新增 160 对仍未交付 |
| `11-18-desktop-env-icons-packages` | 云端包已有证据，真实工具链安装和运行仍待验收 |

历史主机课程结果不证明当前 OHOS 包或设备结果。
新增课程须先通过当前 OHOS 基线门禁。
Windows 工具链的 Clang、GCC、C 和 C++ 仍待验收。
Linux 和 macOS 安装流程仍待目标环境验收。
macOS 的 GCC 需求仍待产品决策。
其他产品的验收不能由 C/C++ 证据替代。
本轮不将未完成的产品任务标为完成。
