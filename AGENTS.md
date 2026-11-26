<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

## 仅云端构建

本节优先于工作流模板的本地检查指令。
本仓库为 `azurekiln2333/qflistudio-cpp`。

- 只在 GitHub 托管 runner 运行构建、测试和 lint。
- 禁止本地基准测试、模拟器和原生编译。
- 禁止本地依赖安装、依赖还原和 SDK 安装。
- 禁止本地运行会产生产物的工具命令。
- 工具包括 `flutter`、`dart`、`gradle`、`cmake`、`ninja`、`xcodebuild`、`hvigor`、`ohpm`、`npm`、`pip` 和 `pytest`。
- 禁止下载构建产物、安装包、SDK 和构建缓存。
- 本地只允许源码编辑和只读检查。
- 中文文本检查只允许下列命令。

```text
python -I -B scripts/ste-lint-zh.py <文件>
```

- 应用工作流为 `.github/workflows/app-installers.yml`。
- 原生工作流为 `.github/workflows/native-artifacts.yml`。
- 产物只留在 GitHub。
- 将提交、run ID、job 结果、摘要和签名状态写入 Trellis。
- 迁移克隆只绑定 GitHub 远端。
- 检查远端的 fetch 和 push URL。
- core 目标目录为 `../qflistudio-core`。
- Dart 包名仍为 `qfli_studio_core`。
- 证书文件只留本地。
- 证书扩展名包括 `.p12`、`.cer` 和 `.p7b`。
- 禁止提交 `D:/Keystore` 和 `~/.ohos/config/material`。
- `ohos/build-profile.json5` 照常跟踪。
- 该文件的 DevEco 密码字段是加密密文。
- 将任务、研究、规范、工作日志和工作流定义纳入版本控制。
- 忽略身份、会话、缓存和密钥文件。
- agent 协作只走 Herdr。
- 未经所有者批准，不得删除旧目录或共享 WSL。

## 受控中文

- 一句只写一个动作。
- 使用主动语态。
- 同一概念全篇使用同一个词。
- 不用分号连接动作。
- 指令句不超过 25 字。
- 说明句不超过 40 字。
- 禁用虚动词结构，如 `进行 / 加以 + 名词`。
- 禁用套话，如 `需要注意的是`、`在一定程度上`。
- 禁用营销形容词，如 `无缝`、`强大`、`赋能`、`闭环`。
- 禁用含糊词，如 `若干`、`一些`、`相关`。
- 不得改动情态，如 `可能`、`也许`。
- 置信度属于内容。
- 先用上述中文文本检查命令检查文件。