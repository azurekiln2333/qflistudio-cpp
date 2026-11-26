# 项目交接状态

更新日期：2026-11-27。
迁移状态：进行中。

## 已发布基线

GitHub 仓库为 `azurekiln2333/qflistudio-cpp`。
GitHub `main` 已包含 `9ff5ce6b80de46011490fdc84db098d48758eb26`。
基线树为 `7258defc922596dfa07c6b22dc8089c26780ffbf`。
本轮修改尚未形成最终迁移提交。

依据为 `.trellis/tasks/11-26-github-workspace-migration/research/baseline.md`。
该文件记录协调者在 2026-11-26 检查的结果。
本页保留签名字段的用户更正。

## 云端结果

`app-installers.yml` 的 run 为 `45645017677`。
该 run 的源提交为上述基线提交。
六个平台共 18 个 job 成功。
这些 job 包括可复用原生工作流和产物门禁。
这些 job 也包括 Python CI 辅助测试。

| 平台 | 应用产物 | 签名状态 |
| --- | --- | --- |
| Android | `app-android-arm64-v8a`、`app-android-x86_64` | 测试签名 |
| Windows | `app-windows-x64` | 未签名 |
| Linux | `app-linux-x64` | 未签名 |
| macOS | `app-macos-universal` | ad hoc |
| iOS | `app-ios-arm64-unsigned` | 未签名 |
| OHOS | `app-ohos-arm64-unsigned` | 未签名 |

该 run 含七个应用产物。
该 run 也含原生依赖产物。
独立原生 run `44001588302` 不是本次应用 run 的来源结论。
原生工作流为 `native-artifacts.yml`。
应用包保留期大多为 30 天。
日志和切片保留期大多为 7 天。
协调者未下载产物内容。
包内来源清单和摘要仍待验收。
云端打包成功不等于设备验收。

## 目标布局与规则

目标克隆为 `E:/MyNewProjects/QFLIProjects/qflistudio-cpp`。
目标 core 为同级 `qflistudio-core`。
应用依赖目标路径为 `../qflistudio-core`。
Dart 包名仍为 `qfli_studio_core`。
目录改名和依赖路径修改归 `cpp-ci`。
目标克隆只绑定 GitHub 远端。

所有 agent 只在 GitHub 托管 runner 运行构建与验证。
本地禁令见根目录 `AGENTS.md`。
持久任务、规范、研究、工作日志和工作流定义须入库。
身份、会话、缓存和构建产物须继续忽略。
agent 协作只走 Herdr。

## 签名更正

用户确认 DevEco 密码字段为加密密文。
`ohos/build-profile.json5` 照常跟踪。
不得将该文件定为敏感文件或泄露风险。
`.p12`、`.cer`、`.p7b` 证书文件只留本地。
`D:/Keystore` 不得入库。
`~/.ohos/config/material` 不得入库。
此更正优先于基线报告的旧判断。

## 待关闭门禁

| 门禁 | 所有者 | 验收条件 |
| --- | --- | --- |
| Git 历史与源码收敛 | `cpp-git` | 分支、worktree、备份和可恢复快照均有处置证据 |
| Trellis 完整性 | `cpp-trellis` | 主工作区保留各 worktree 的独有知识 |
| GitHub 发布 | 协调者 | 全部批准内容进入 GitHub `main` |
| core 布局 | `cpp-ci` | 依赖不再要求旧 D 盘目录 |
| 云端验证覆盖 | `cpp-ci` | 补充 Dart 分析和产品测试证据 |
| 包内来源 | `cpp-ci` | 固定源码、core、原生产物来源和摘要 |
| 目标克隆一致性 | `cpp-handoff` | 提交、树和跟踪字节与 GitHub 一致 |
| 目标零构建产物 | `cpp-handoff` | 新目录无构建输出和依赖缓存 |
| 旧目录可删除 | 协调者 | 有价值内容均已保存并完成目标验收 |

当前不批准删除旧目录。
共享 WSL 的所有权仍未确认。
本轮不操作 WSL。
最终迁移完成证据：待补。
GitHub 最终提交与树：待补。
目标克隆最终提交与树：待补。
目标零构建产物证据：待补。
旧目录删除授权：待补。

## 产品门禁

| 任务 | 状态与边界 |
| --- | --- |
| `00-bootstrap-guidelines` | 五份后端和六份前端通用规范仍有模板 |
| `10-01-cross-platform-native-runtime` | iOS、Web、macOS 和当前源设备门禁未关闭 |
| `10-22-offline-standalone-ide` | 已验收 200 对课程，新增 160 对和总体验收未完成 |
| `11-18-desktop-env-icons-packages` | 云端打包已有基线，真实安装验收仍待完成 |

Windows 工具链的 Clang、GCC、C 和 C++ 仍待验收。
Linux、macOS 安装流程仍待目标环境验收。
macOS GCC 需求仍待产品决策。
生产签名、Apple 公证和移动设备验收须单独授权。
这些产品门禁不等于迁移内容缺失。
