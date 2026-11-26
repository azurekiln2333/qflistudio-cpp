# Trellis 迁移完整性记录

检查日期：2026-11-27。
工作身份：`cpp-trellis`。
协调者：Claude，Herdr `w5R:p7`。
本轮只改文件，不提交。

## 范围与依据

优先目标是保留旧目录的全部有价值内容。
GitHub `main` 是最终保存位置。
新目录须保持零构建产物。
只有协调者可确认旧目录删除门禁。

依据为父任务 `research/baseline.md`。
基线提交为 `9ff5ce6b80de46011490fdc84db098d48758eb26`。
基线应用 run 为 `45645017677`。
本轮未重跑该工作流。
本轮未下载产物。

## worktree 完整性

检查覆盖原六个 worktree。
检查也覆盖新增的 `qfli_c-cloud-validation`。
以下路径均相对 `D:/MyNewProjects/_wt/`。

| worktree | 可共享文件数 | 本机文件数 | 主工作区缺失路径 |
| --- | ---: | ---: | ---: |
| `qfli-c-ui-sync/qfli_c` | 483 | 14 | 0 |
| `qfli_c-ci-app-installers` | 428 | 0 | 0 |
| `qfli_c-wp-ci` | 423 | 0 | 0 |
| `qfli_c-wp-env-core` | 423 | 0 | 0 |
| `qfli_c-wp-env-ui` | 423 | 0 | 0 |
| `qfli_c-wp-icons` | 423 | 0 | 0 |
| `qfli_c-cloud-validation` | 496 | 0 | 0 |

文件数来自规则修改前的只读盘点。
比较前统一文本换行。
主工作区保留现有新版，不覆盖为旧版。
原六个 worktree 的 HEAD 均为 `main` 祖先。
旧版已提交内容仍在 `main` 历史中。

两项任务的旧活动路径已归档。
每个旧 worktree 有 99 个文件使用这些旧路径。
对应关系如下。

| 旧目录 | 主工作区目录 |
| --- | --- |
| `.trellis/tasks/10-09-unified-terminal-current-file/` | `.trellis/tasks/archive/2026-11/10-09-unified-terminal-current-file/` |
| `.trellis/tasks/10-12-c-cpp-substantive-curriculum/` | `.trellis/tasks/archive/2026-11/10-12-c-cpp-substantive-curriculum/` |

不得复制出重复的活动任务。
不得将旧任务状态覆盖到归档状态。

### 安装器 worktree 独有报告

该 worktree 有两份尚未保存的报告版本。
现已原字节复制到主工作区。
原文件和新版主报告均未改动。

| 原文件 | 保留副本 | 独有内容 |
| --- | --- | --- |
| `reports/ci-readiness.md` | `reports/ci-readiness.worktree-ci-app-installers.md` | 历史云端就绪判断和包摘要 |
| `reports/wp-env-core.md` | `reports/wp-env-core.worktree-ci-app-installers.md` | LLVM-MinGW 摘要、WinLibs 根目录和未验收边界 |

表内路径相对 `.trellis/tasks/11-18-desktop-env-icons-packages/`。
复制后 SHA-256 比较一致。
这些副本描述历史工作，不是本轮本地验证。

### 新增云端 worktree

检查期间该 worktree 保存了提交 `ef2a9b4295cfc062679d7ccc63846caf2593e985`。
该提交尚待 `cpp-git` 收敛。
它的 Trellis 差异仅为 core 目录路径替换。
以下替换表完整保留这部分独有信息。
主工作区原文暂不覆盖。
`backend/app-installers.md` 归 `cpp-ci`。

| 文件 | 原文 | 目标文本 | 次数 |
| --- | --- | --- | ---: |
| `.trellis/spec/backend/app-installers.md` | `../qfli_studio_core` | `../qflistudio-core` | 1 |
| `.trellis/spec/backend/app-installers.md` | `qfli_studio_core/    azurekiln2333/qflistudio-core` | `qflistudio-core/    azurekiln2333/qflistudio-core` | 1 |
| `.trellis/spec/frontend/shared-core-ui.md` | `../qfli_studio_core` | `../qflistudio-core` | 1 |
| `.trellis/tasks/10-01-cross-platform-native-runtime/implement.md` | `../qfli_studio_core` | `../qflistudio-core` | 1 |
| `.trellis/tasks/10-01-cross-platform-native-runtime/research/android-analysis-2026-10-15.md` | `../qfli_studio_core` | `../qflistudio-core` | 2 |
| `.trellis/tasks/10-01-cross-platform-native-runtime/research/web-boundary.md` | `../qfli_studio_core` | `../qflistudio-core` | 4 |
| `.trellis/tasks/10-22-offline-standalone-ide/research/core-audit-20261022.md` | `../qfli_studio_core` | `../qflistudio-core` | 1 |
| `.trellis/tasks/11-18-desktop-env-icons-packages/wp-common.md` | `../qfli_studio_core` | `../qflistudio-core` | 2 |

目录改名不改变 Dart 包名 `qfli_studio_core`。
源码和依赖路径处置归 `cpp-ci` 与 `cpp-git`。
本记录不将旧研究中的历史路径定为当前布局。

## 可跟踪性

`.claude/` 有 53 份可共享文件。
它们包括 agents、skills、commands、hooks 和 `settings.json`。
根忽略规则现允许跟踪这些定义。
`.codex/` 和 `.agents/` 当前不存在。
规则已为其同类定义预留跟踪入口。
`CLAUDE.md` 当前不存在。
本轮未创建替代入口。

`.trellis/agents/`、`workflow.md`、任务、规范和工作日志均可跟踪。
已有历史研究日志有窄范围忽略例外。
`git ls-files -ci --exclude-standard -- .trellis .claude` 应无输出。
三份未跟踪课程日志仍忽略。
它们的不可替代结论已写成同目录脱敏摘要。

以下内容继续忽略。

- `settings.local.json`。
- `.trellis/.developer` 和当前任务指针。
- `.runtime/` 和会话记录。
- 缓存、`__pycache__/` 和 Python 字节码。
- `local.properties`。
- 证书、私钥和环境秘密文件。
- `build/`、`.dart_tool/` 和平台构建目录。
- `ohos/node_modules/`、`ohos/oh_modules/` 和 `ohos/.hvigor/`。

`git ls-files` 的构建产物路径候选为 0。
已有 `.trellis` 研究日志不是安装包或二进制构建产物。
本轮不删除旧目录内的任何输出。

## 断链修复

已修复四处归档 manifest 目标。

- `archive/2026-10/10-01-mobile-llvm-runtime/check.jsonl`。
- `archive/2026-10/10-01-mobile-llvm-runtime/implement.jsonl`。
- `archive/2026-11/11-17-native-github-actions/check.jsonl`。
- `archive/2026-11/11-17-native-github-actions/implement.jsonl`。

上述路径均相对 `.trellis/tasks/`。
修复后所有归档 JSONL 的 `file` 目标均存在。

`workflow.md` 两次引用缺失的契约文件。
目标为 `.trellis/spec/cli/backend/workflow-state-contract.md`。
主工作区、七个 worktree 和 Git 历史均未找到原件。
该目标现注明「原文件未保存」。
这不是重建的契约。

## 签名更正

用户确认 `ohos/build-profile.json5` 含 DevEco 加密密文。
该文件照常跟踪。
不得将该文件定为敏感文件或泄露风险。
`.p12`、`.cer`、`.p7b` 证书文件只留本地。
`D:/Keystore` 和 `~/.ohos/config/material` 不得入库。

## 检查结果与交接

- `AGENTS.md` 的 TRELLIS 托管块未改动。
- 新写中文正文的硬违规为 0。
- 托管块原有英文分号保留为 1 处 baseline。
- 归档 manifest 缺失目标为 0。
- 两份报告副本与源文件字节一致。
- 53 份 Claude 定义现可跟踪。
- 指定构建目录和本机状态均继续忽略。
- 本轮未运行产品构建、测试或依赖安装。
- 本轮未提交、推送或操作 WSL。

协调者仍须将批准文件加入 Git。
协调者仍须发布 GitHub `main`。
`cpp-handoff` 仍须检查新目录的跟踪字节和零构建产物。
最终发布提交：待补。
目标克隆一致性证据：待补。
旧目录删除授权：待补。
