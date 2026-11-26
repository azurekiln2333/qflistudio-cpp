# Git 分支、worktree 与快照处置

审计者：cpp-git。日期：2026-11-27。协调者：Claude（Herdr w5R:p7）。
基准 main 与 GitHub main 均为 `9ff5ce6b80de46011490fdc84db098d48758eb26`。
本文件记录审计时点，不声明迁移已完成。未提交或归并任何分支。

## 需要保留的新增内容

旧分支没有 main 缺失的有效源码。
活跃 `ci/cloud-validation` 有 2 个新增提交，另作 0003 补丁。
没有发现 main 缺失的有效旧 worktree 源码。
没有发现需要恢复的有效悬空源码或独有历史研究结论。
五个未跟踪的 11-26 任务目录有持久项目价值。
其中现有任务记录通过 0001 补丁保留。
本审计通过 0002 补丁保留。
其他 worker 随后新增的 research 由原作者补存。

| ref/路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| 五个 `.trellis/tasks/11-26-*` 目录的既有记录 | 保留 | 31 个文件不在 GitHub main | 应用 0001，或提交已存在的同名文件 |
| 本文件 | 保留 | main 不含本轮审计 | 应用 0002，或提交现有文件 |
| 同伴新增的 research 与规则 | 保留，由原作者交付 | 同伴报告及主工作区状态 | 不回退，不用旧补丁覆盖新稿 |
| 活跃 `ci/cloud-validation` | 保留，尚待云端结果 | cherry 为 `+ ef2a9b4`、`+ 70b59ca`，main...ref 为 `0/2` | 0003 保存差异，由 cpp-ci 完成后交协调者归并 |
| `ohos/build-profile.json5` | DevEco 加密密文，非明文，无需处理 | 用户确认，文件 blob 与 main 相同 | 保持原样，不统计历史，不出清洗补丁 |
| `ed4c9c0` 相对当前 main 的剩余差异 | 本地签名配置变更，丢弃 | 7 条原始路径中 6 个 postimage 与 main 相同 | 不归并 backup，不导出签名补丁 |

## 补丁顺序

补丁目录：`D:/MyNewProjects/_pi_reports/qfli_c/2026-11-27/patches/`。
1. `0001-trellis-task-records.patch`：保留既有 31 个任务记录。
2. `0002-reconciliation.patch`：保留本文件。
3. `0003-ci-cloud-validation-70b59ca.patch`：保存活跃 CI 分支差异。
0003 暂不应用。待 cpp-ci 最新云端结果与协调者决定。
0003 不替代该分支的后续提交。
0001 和 0002 均为新增文件，不覆盖 main 的已有文件。
若原工作区已有同名文件，直接提交现有文件。
不要在同名文件已存在时强行应用新增补丁。
在最终主线快照上先用 `git apply --check` 检查。
当前补丁只记录一个时点。协调者须保留同伴的后续稿。
0001 只含各任务顶层文件和父任务 baseline，共 31 个文件。
原作者后续补存的研究、规则和旁存报告不重复打包。

## 五个远端

全部 fetch 与 ls-remote 成功。抓取使用 `--tags --no-prune`。
未删除远端跟踪 ref。五个远端均未广告 tag，本地也没有 tag。
下表的增加/缺少提交数均相对 GitHub main。

| 远端 branch | SHA | 增加 | 缺少 | 结论 |
| --- | --- | ---: | ---: | --- |
| github/ci/app-installers | `1969ef40d69134e45eaab6b558d71b96cf9be68a` | 0 | 47 | 已含于 main |
| github/ci/ui-core-installers-20261121 | `dcb4355a6e9e3526db8b69956959dc1680a44872` | 0 | 44 | 已含于 main |
| github/main | `9ff5ce6b80de46011490fdc84db098d48758eb26` | 0 | 0 | 已含于 main |
| cnb/main | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 0 | 64 | 已含于 main |
| gitcode/main | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 0 | 64 | 已含于 main |
| gitee/main | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 0 | 64 | 已含于 main |
| gitlab/main | `23ea13cda6fec378ff20209af81f2d909c99eab5` | 0 | 64 | 已含于 main |

审计过程中 cpp-ci 新增了远端 `ci/cloud-validation`。
最终观察 SHA 为 `70b59ca4755a2f64f523e0e3d09c90e32178c94e`。
这是活跃交付分支，其差异由 cpp-ci 报告承接，不丢弃。

## 全部本地与远端跟踪 ref

对每个 ref 执行 `merge-base --is-ancestor <ref> main`。
初始时点只有 backup 不满足，因此另查 cherry 与路径。
活跃 CI 的两个新增提交同样已查 cherry 与路径。

| ref | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `refs/heads/backup/main-before-sync-20261125` | 有效内容已含于 main，签名差异丢弃 | `4463ebb`，main...ref = `46/22` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/ci/app-installers` | 已含于 main | `d673a23`，main...ref = `42/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/ci/cloud-validation` | 已含于 main | `9ff5ce6`，main...ref = `0/0` | cpp-ci 活跃分支，保留 |
| `refs/heads/ci/ui-core-installers-20261121` | 已含于 main | `dcb4355`，main...ref = `44/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/main` | 已含于 main | `9ff5ce6`，main...ref = `0/0` | 保留 |
| `refs/heads/wp/ci-packaging` | 已含于 main | `5f8f962`，main...ref = `46/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/wp/env-core` | 已含于 main | `5f8f962`，main...ref = `46/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/wp/env-ui` | 已含于 main | `5f8f962`，main...ref = `46/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/heads/wp/icons` | 已含于 main | `7eb0dd5`，main...ref = `45/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/cnb/HEAD` | 已含于 main | `23ea13c`，main...ref = `64/0` | 符号别名，不单独归并 |
| `refs/remotes/cnb/main` | 已含于 main | `23ea13c`，main...ref = `64/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/gitcode/HEAD` | 已含于 main | `23ea13c`，main...ref = `64/0` | 符号别名，不单独归并 |
| `refs/remotes/gitcode/main` | 已含于 main | `23ea13c`，main...ref = `64/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/gitee/main` | 已含于 main | `23ea13c`，main...ref = `64/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/github/HEAD` | 已含于 main | `9ff5ce6`，main...ref = `0/0` | 符号别名，不单独归并 |
| `refs/remotes/github/ci/app-installers` | 已含于 main | `1969ef4`，main...ref = `47/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/github/ci/ui-core-installers-20261121` | 已含于 main | `dcb4355`，main...ref = `44/0` | 通过迁移门禁后可删，当前不执行 |
| `refs/remotes/github/main` | 已含于 main | `9ff5ce6`，main...ref = `0/0` | 保留 |
| `refs/remotes/gitlab/HEAD` | 已含于 main | `23ea13c`，main...ref = `64/0` | 符号别名，不单独归并 |
| `refs/remotes/gitlab/main` | 已含于 main | `23ea13c`，main...ref = `64/0` | 通过迁移门禁后可删，当前不执行 |

backup 的 22 个祖先唯一提交中，cherry 给出 19 个 `-`。
另有 2 个归并提交和 1 个 `+ ed4c9c0`。
`ed4c9c0` 原始提交并非只碰一个文件，而是 7 个文件。
6 个源码 postimage 与 main 完全相同。
其 profile 去掉签名配置后与 main 语义相同。
因此只丢弃本地签名差异，不丢弃产品功能。
表中 `ci/cloud-validation` 为初始时点。最终状态见下表。

| ref | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `refs/heads/ci/cloud-validation` 与 GitHub 同名 branch | 保留 | `70b59ca4755a2f64f523e0e3d09c90e32178c94e`，main...ref = `0/2` | 由 cpp-ci 完成云端证据后交协调者归并 |
本地 `ci/app-installers=d673a23` 缺少 main 后续 42 个提交。
GitHub 的 `1969ef4` 缺少 main 后续 47 个提交。
两者都没有 main 缺失的提交。

## 六个旧 worktree

忽略 cpp-ci 的新 `qfli_c-cloud-validation`。
共 46 个脏路径。34 个等价，12 个过期，没有新增源码。
表内 blob 均为 Git blob SHA。`CRLF` 差异不构成新增源码。

### D:/MyNewProjects/_wt/qfli-c-ui-sync/qfli_c

分支：`refs/heads/ci/ui-core-installers-20261121`。HEAD：`dcb4355a6e9e3526db8b69956959dc1680a44872`。
工作区干净。分支提交已含于 main。

### D:/MyNewProjects/_wt/qfli_c-ci-app-installers

分支：`refs/heads/ci/app-installers`。HEAD：`d673a2397547089901636b6a6d0ef75a623b863b`。

| 路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `.trellis/tasks/11-18-desktop-env-icons-packages/reports/wp-env-core.md` | 过期旧版 | 旧报告缺少 640abb0 的归并检查点。main 保留验收限制。blob `1db20ed / bd8a8ad` | 不出补丁，迁移后可丢弃本地副本 |
| `.trellis/tasks/11-18-desktop-env-icons-packages/reports/ci-readiness.md` | 过期旧版 | 旧报告仍称构建前就绪。main 已记录后续云端结果。blob `b903e4b / 5b37371` | 不出补丁，迁移后可丢弃本地副本 |

### D:/MyNewProjects/_wt/qfli_c-wp-ci

分支：`refs/heads/wp/ci-packaging`。HEAD：`5f8f962bc44ab3a78bc0e6937a099924e539a983`。

| 路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `.github/workflows/app-installers.yml` | 过期旧版 | 旧版回退 core pin，并删除 ci-tests、复用 native 和门禁。blob `096515c / c764a47` | 不出补丁，迁移后可丢弃本地副本 |
| `.github/workflows/native-artifacts.yml` | 过期旧版 | 旧版缺少 034d69d 的 workflow_call 和 native run ID 输出。blob `de3cfe4 / 4b5b85b` | 不出补丁，迁移后可丢弃本地副本 |
| `tool/ci/package_app.py` | 过期旧版 | 旧版缺少版本传参，并恢复已修复的 /D= 提取参数。blob `d2c8802 / bf75166` | 不出补丁，迁移后可丢弃本地副本 |
| `tool/ci/test_ci_helpers.py` | 过期旧版 | 旧版缺少 main 的 WindowsPortableTest 回归覆盖。blob `4448487 / f599aed` | 不出补丁，迁移后可丢弃本地副本 |
| `tool/ci/appimage-tools.lock.json` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `e762068 / e762068` | 不出补丁，迁移后可丢弃本地副本 |
| `tool/ci/fetch_appimage_tools.py` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `3fe00d2 / 3fe00d2` | 不出补丁，迁移后可丢弃本地副本 |
| `tool/ci/windows_portable.nsi` | 过期旧版 | 旧版恢复无效的 # 预处理和额外截字逻辑。blob `a11ffab / cf4c4dc` | 不出补丁，迁移后可丢弃本地副本 |

### D:/MyNewProjects/_wt/qfli_c-wp-env-core

分支：`refs/heads/wp/env-core`。HEAD：`5f8f962bc44ab3a78bc0e6937a099924e539a983`。

| 路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `lib/clang_runner.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `b468072 / b468072` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/local_toolchain_environment.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `ea20861 / ea20861` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_environment.dart` | 过期旧版 | 旧版只有抽象 getter。main 已补默认 getter 兼容实现。blob `42517d3 / 60a5fcf` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugin_registrant.cc` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `64a0ece / 64a0ece` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugin_registrant.h` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `e0f0a47 / e0f0a47` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugins.cmake` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `2db3c22 / 2db3c22` | 不出补丁，迁移后可丢弃本地副本 |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `b878e03 / b878e03` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugin_registrant.cc` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `77ab7a0 / 77ab7a0` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugin_registrant.h` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `dc139d8 / dc139d8` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugins.cmake` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `a423a02 / a423a02` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/compiler_candidate.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `63a4d77 / 63a4d77` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/local_toolchain_environment_native.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `ca8eac3 / ca8eac3` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/local_toolchain_environment_stub.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `dbe0c61 / dbe0c61` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_downloader.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `7e3c658 / 7e3c658` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_environment_base.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `1c94c31 / 1c94c31` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_host_info.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `186f1e7 / 186f1e7` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_host_info_native.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `edcae9b / edcae9b` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_host_info_stub.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `2852678 / 2852678` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_installer_platform.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `78aa874 / 78aa874` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_lookup.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `eebb3d5 / eebb3d5` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_settings_file.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `4afec42 / 4afec42` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/toolchain_setup.dart` | 过期旧版 | 旧版缺少 b894ec1 的目录根检查和失败清理。blob `62bc596 / 0912cff` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/toolchain/windows_toolchain_packages.dart` | 过期旧版 | 旧版含错误摘要和空 archiveRoot。main 已修复。blob `a503a1f / 7b0f8ad` | 不出补丁，迁移后可丢弃本地副本 |
| `test/toolchain_fake_compiler.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `4dd05af / 4dd05af` | 不出补丁，迁移后可丢弃本地副本 |
| `test/toolchain_fake_process.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `7989e30 / 7989e30` | 不出补丁，迁移后可丢弃本地副本 |
| `test/toolchain_lookup_test.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `c043a92 / c043a92` | 不出补丁，迁移后可丢弃本地副本 |

### D:/MyNewProjects/_wt/qfli_c-wp-env-ui

分支：`refs/heads/wp/env-ui`。HEAD：`5f8f962bc44ab3a78bc0e6937a099924e539a983`。

| 路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `lib/forge_tools_page.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `1c09faf / 1c09faf` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugin_registrant.cc` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `64a0ece / 64a0ece` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugin_registrant.h` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `e0f0a47 / e0f0a47` | 不出补丁，迁移后可丢弃本地副本 |
| `linux/flutter/generated_plugins.cmake` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `2db3c22 / 2db3c22` | 不出补丁，迁移后可丢弃本地副本 |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `b878e03 / b878e03` | 不出补丁，迁移后可丢弃本地副本 |
| `test/forge_tools_test.dart` | 过期旧版 | 旧桩缺少 storedSettings 和 managedRoots getter。blob `55b0115 / f05512b` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugin_registrant.cc` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `77ab7a0 / 77ab7a0` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugin_registrant.h` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `dc139d8 / dc139d8` | 不出补丁，迁移后可丢弃本地副本 |
| `windows/flutter/generated_plugins.cmake` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `a423a02 / a423a02` | 不出补丁，迁移后可丢弃本地副本 |
| `lib/forge_environment_page.dart` | 与 main 等价 | 完整 blob 或换行规范化相同。blob `b181475 / b181475` | 不出补丁，迁移后可丢弃本地副本 |
| `test/forge_environment_page_test.dart` | 过期旧版 | 旧假环境缺少 storedSettings 和 managedRoots getter。blob `799e481 / c88f262` | 不出补丁，迁移后可丢弃本地副本 |

### D:/MyNewProjects/_wt/qfli_c-wp-icons

分支：`refs/heads/wp/icons`。HEAD：`7eb0dd5760daa441e279ee91490a47f6d17058da`。
工作区干净。分支提交已含于 main。

## 悬空提交与 reflog

`fsck --no-reflogs --unreachable` 返回 196 个对象。
其中有 5 个 commit、71 个 tree 和 120 个 blob。
reflog 共 328 条记录、104 个唯一提交。
reflog 未发现额外的非 ref 可达提交。未使用 `--lost-found`。

| 快照 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `9965f0c` | 过期旧版 | 两个 workflow 改为 Node24 pin。main 已有相同 pin，并有后续门禁 | 丢弃，不回退工作流 |
| `abf84db` | 空 index 快照 | tree 与父提交同为 `8acc9c07` | 丢弃 |
| `928cbd5` | 与 main 等价 | 只增 backend/index.md 的 app-installers 条目，postimage 相同 | 丢弃重复快照 |
| `2a53307` | 空 index 快照 | tree 与父提交同为 `b6bc3e0c` | 丢弃 |
| `2b6b59c` | 功能已整合 | 53 条路径中 51 个 postimage 相同。其余两个是旧换行判断 | 丢弃旧脚本，保留 main 的 CRLF 修复 |

### 不可达树的 13 个根快照

递归逐 blob 对照 main、main 历史、其他 ref 和旧 worktree。
历史 blob 不重新作为当前源码恢复。
非历史差异已逐项审阅，均为冲突残留或缺少后续修复。

| 根 tree | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `0f21fe8134bd796a2c37262c536641d5e17f4310` | 过期旧版或等价 | 874 个文件，146 个历史 blob，0 个非历史差异 | 丢弃快照，不出源码补丁 |
| `2c03175f2938fc46a40b680fc638585ed694a44c` | 过期旧版或等价 | 983 个文件，132 个历史 blob，4 个非历史差异 | 丢弃快照，不出源码补丁 |
| `3924e23b188575c260744ae6b06c2a4500a45fc6` | 过期旧版或等价 | 901 个文件，177 个历史 blob，1 个非历史差异 | 丢弃快照，不出源码补丁 |
| `12293f4975a627b131776f013eec3a7de40bf1a3` | 过期旧版或等价 | 957 个文件，137 个历史 blob，4 个非历史差异 | 丢弃快照，不出源码补丁 |
| `00ec8f7e4dc591197b0c12910f9238c36a9f40cc` | 过期旧版或等价 | 940 个文件，170 个历史 blob，9 个非历史差异 | 丢弃快照，不出源码补丁 |
| `124f2a68ca4d6b04c5da1da88937dbc27575b569` | 过期旧版或等价 | 940 个文件，171 个历史 blob，9 个非历史差异 | 丢弃快照，不出源码补丁 |
| `93f0dd511948b67fda8badf99bd94392b71b25ca` | 过期旧版或等价 | 983 个文件，132 个历史 blob，4 个非历史差异 | 丢弃快照，不出源码补丁 |
| `f63119ccd6ec8eb76bf5b6c468ccbe6a83437021` | 过期旧版或等价 | 628 个文件，186 个历史 blob，1 个非历史差异 | 丢弃快照，不出源码补丁 |
| `fb31787ee3e3805bbcdb120f959cb191ac78bb2e` | 过期旧版或等价 | 608 个文件，187 个历史 blob，1 个非历史差异 | 丢弃快照，不出源码补丁 |
| `0df52650dc9a0d3a7710706e78ff33aa02046d52` | 过期旧版或等价 | 628 个文件，186 个历史 blob，1 个非历史差异 | 丢弃快照，不出源码补丁 |
| `239d7f8dbd55bbfa5c6250afbee13df634b95dca` | 过期旧版或等价 | 909 个文件，181 个历史 blob，0 个非历史差异 | 丢弃快照，不出源码补丁 |
| `12bf99dac32aa6664236498f01f7064e887afa2c` | 过期旧版或等价 | 881 个文件，162 个历史 blob，0 个非历史差异 | 丢弃快照，不出源码补丁 |
| `60bfd9ea99dda79b5a6ea0fee9aff172a37a85a9` | 过期旧版或等价 | 830 个文件，189 个历史 blob，0 个非历史差异 | 丢弃快照，不出源码补丁 |

### 树内非历史差异

| 路径 | 结论 | 证据 | 建议动作 |
| --- | --- | --- | --- |
| `.github/workflows/app-installers.yml` | 丢弃 | 旧 Node24 快照缺 main 的 CI 门禁和便携包流程。共 1 个版本 | 保留 main |
| `.trellis/spec/backend/app-installers.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 5 个版本 | 保留 main |
| `.trellis/tasks/10-22-offline-standalone-ide/implement.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/11-18-desktop-env-icons-packages/reports/wp-env-core.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 3 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-ohos-startup-icon/delivery.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/check.jsonl` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/delivery.json` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/delivery.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/implement.jsonl` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/implement.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `.trellis/tasks/archive/2026-10/10-17-forge-terminal-ui-delivery/prd.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 2 个版本 | 保留 main |
| `native/compiler/compiler_analysis.inc` | 丢弃 | 缺少 weakly_canonical 与错误处理。共 1 个版本 | 保留 main |
| `pubspec.lock` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 3 个版本 | 保留 main |
| `test/forge_editor_analysis_test.dart` | 丢弃 | 缺少快捷栏断言及 hitTestable/pump 修复。共 2 个版本 | 保留 main |
| `tool/ci/README.md` | 丢弃 | 含归并冲突标记。main 已保留有效内容及后续修复。共 3 个版本 | 保留 main |

### 独立 blob

82 个 blob 未归属根树、main 历史或 worktree postimage。
其中 22 个只差换行，19 个为 Python 缓存。
24 个匹配当前未提交文件，其中 2 个是机器状态。
其余 17 个均为旧草案或旧摘要表。
当前任务记录由 0001 保留，机器状态丢弃。

| blob | 路径或识别结果 | 结论 | 证据与动作 |
| --- | --- | --- | --- |
| `c5e00da7309e58e5a3f7556afd0cf876b5857bd0` | `旧片段，见证据说明` | 丢弃 | 冻结证据的旧 * -text 规则。main 现有局部 .gitattributes 已覆盖。丢弃，不出补丁 |
| `bb0139dcbab80055a45bfa7ef1843a7c7c23a0e5` | `.trellis/tasks/11-26-trellis-cloud-only-rules/implement.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `45c3b7c400640538631f715d9240481a9264ed7c` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/manifest.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `a903f4c6ccce1183e7accf8756bdc95a39014efc` | `.trellis/tasks/11-26-workspace-cleanup-handoff/implement.jsonl` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `0f6410c2d7e132e49dde38a936ab93db8eba5823` | `.trellis/tasks/11-18-desktop-env-icons-packages/wp-common.md` | 丢弃 | wp-common.md 的旧 core pin、过期 pane 和截止指令。丢弃，不出补丁 |
| `59e463d1bb9ac6aa8c22442eff42691392f711bb` | `tool/host_baseline/baseline_200_control_test.py` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `7124bbab84b8c91bada4361e611ea04f1439ecf9` | `tool/host_baseline/snapshot-sha256.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `00457c2beccb6bfcc4b4782b2a6449dd631238bf` | `.trellis/tasks/11-26-workspace-cleanup-handoff/task.json` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `09057b14ce425e36aa5fc7904c8d24af864207cc` | `.trellis/scripts/common/__pycache__/session_context.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `3e25ba066ad533dd122caab17da224b9cae5b0f0` | `.trellis/.gitignore` | 丢弃 | 旧 ignore 草案会公开身份和会话状态。main 已区分持久知识。丢弃，不出补丁 |
| `6fc5e89ea0305a889eb448996a979fd8450d24d1` | `.trellis/tasks/11-26-trellis-cloud-only-rules/design.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `7e25809b2ff577149237bf26d15aa3640f796a9f` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/native/manifest.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `90054e16c34a9aa479d792cbbf0ad330d99a4015` | `tool/host_baseline/pure-control-results.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `d645b7876efe6be4afd0640d01fcc495108d9552` | `.trellis/tasks/11-26-github-workspace-migration/implement.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `d985db958643ca414421dfcd891f3ec6a13ae56a` | `.trellis/scripts/common/__pycache__/types.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `32e6845c373838705b5856d6c2b8885270730aee` | `.trellis/scripts/common/__pycache__/git.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `3586ac581f36fec63780ec5560ae963ba220fb98` | `.trellis/scripts/common/__pycache__/__init__.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `872606859db5900fb65c70acc0d8185b6b7c1297` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/native/windows-owner.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `954624b625c5e649eb916e7e25b9bef8ea61be5d` | `.trellis/tasks/11-26-github-workspace-migration/research/baseline.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `ed863ba527e441dd03ce428000921c1d653497ff` | `.trellis/tasks/10-22-offline-standalone-ide/research/core-workspace-publication-20261024.json` | 与 main 等价 | CRLF/LF 或完整 blob 相同。保留 main，不出补丁 |
| `83e7af263d1e60860f1ca341b439bdc79629245d` | `tool/host_baseline/baseline_200_linux.py` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `9a67d7d38074a366e258c7373918ee92bb6701e7` | `.trellis/tasks/11-26-github-branch-reconciliation/task.json` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `07887f79b674f478ead0909c2a209fb8b20aa5bf` | `.trellis/PROJECT_STATUS.md` | 丢弃 | PROJECT_STATUS 旧稿。未发布计数和桌面待归并描述已过期。丢弃，不出补丁 |
| `7b48c6850e0f761879349715cd74a45032f8068e` | `.trellis/scripts/common/__pycache__/log.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `a3e85914ebd2764019a3c99cb93edf3b15845dc2` | `.trellis/tasks/11-26-workspace-cleanup-handoff/design.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `7109753d304d366fd619b88a1b2e766563f77092` | `.trellis/scripts/common/__pycache__/paths.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `bb4afccf7f1ef5baa75e991118bddb229cd44435` | `.trellis/tasks/11-26-six-platform-cloud-delivery/prd.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `eb0a5cf5b1011030ceb63c053645ddaee0759f80` | `README.md` | 丢弃 | 旧 README 缺运行时边界和 GPL 许可证节。丢弃，不出补丁 |
| `13abb0cc150795b79003f84279bae52df451149f` | `.trellis/tasks/11-26-github-workspace-migration/design.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `2acc7480a93630e57f4d2a79492c4c32a347482c` | `.trellis/scripts/common/__pycache__/active_task.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `4d6ce99bac664a00ccd8d0e3ee868a6a57169d3e` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/wasi/windows-owner.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `844c3563704ede90e536180c0b889a2ddb999dca` | `.trellis/tasks/11-26-six-platform-cloud-delivery/task.json` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `95ccb59624b4d281edbd2516e5f20ae2958c5df7` | `.trellis/tasks/10-22-offline-standalone-ide/research/.artifacts/core-workspace-20261024/.gitattributes` | 丢弃 | 现有局部 .gitattributes 含全部规则及额外日志规则。丢弃，不出补丁 |
| `45cdcddd21c78bd773b6a37b3789df35cac2a226` | `tool/host_baseline/README.md` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `8eae362a4ac883fa7e20692bc82aa73355829194` | `.trellis/.runtime/sessions/codex_01a0ef27-baf5-73c3-a03e-2c06dcaa0f9f.json` | 丢弃 | 机器身份或活跃会话状态，不是项目知识。丢弃，不出补丁 |
| `760f838ee63d1764cf79b15102f73ceb1b8fc25d` | `.trellis/scripts/common/__pycache__/task_utils.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `a3f040ab3baa636e5f44aac943880b3698cdd014` | `README.en.md` | 丢弃 | 旧英文 README 缺运行时边界和 GPL 节。丢弃，不出补丁 |
| `e1501c3e0385e7b987b1c7951d6d6ecc6e1bddd1` | `.trellis/scripts/common/__pycache__/config.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `35318e38ab33824850ffbc4e4e0446b3824fabf0` | `.trellis/tasks/11-26-workspace-cleanup-handoff/implement.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `9cb10efc2f08aeb4fb18ab979ca76798a478a183` | `.trellis/tasks/11-26-workspace-cleanup-handoff/prd.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `0fd215dfa09f3908c71bd88f9eead31312ec7725` | `.trellis/tasks/10-22-offline-standalone-ide/research/c-editor-analysis-publication-20261024.json` | 丢弃 | 旧 publication JSON 缺 legacy requirement 对照。main 信息更全。丢弃，不出补丁 |
| `56f26392793948385fa62bdf526a1a108c9ed05b` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/control-launch.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `9452fba6501b8f2d37546defddc24d6e3dbac77f` | `.trellis/scripts/common/__pycache__/task_store.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `e9b25cc694ec066adb48fb2ea57e140be7034113` | `.trellis/tasks/11-26-github-workspace-migration/prd.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `66f3112cd15f506486f627f3450e8db3281d5f37` | `.trellis/tasks/11-26-github-branch-reconciliation/prd.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `94134fd75d5df14561c4a88f998c9f48cd67b79a` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/native/launch.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `c77388f7a1e076740204988e2d91be007327a1e0` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/README.md` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `fa1385d99a319b43c06f5309d1aae9fdd3adea46` | `旧片段，见证据说明` | 丢弃 | 旧 * -text 片段。main 的局部规则已覆盖。丢弃，不出补丁 |
| `6094b0c63090e6ee51b8de82ee46965774713758` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/wasi/sha256.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `8bf4ff991278a93e41adbffbf7adc66c4ca75c7b` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/windows-control-owner.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `83155b431bcb280a7730fd5660671f8f40f62a80` | `.trellis/scripts/common/__pycache__/packages_context.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `f8d580a7b9e1616d6a04b019ac1b5536d473bf04` | `tool/host_baseline/native-200-review.md` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `4076ba80a6ec55b54195141694f8578d5edcadaf` | `.trellis/scripts/common/__pycache__/io.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `45361f791d3560e9239fcdc6582efe6033e4a574` | `.trellis/tasks/11-26-six-platform-cloud-delivery/design.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `711659e9f2b3ea3c4f79f012fcff869b6d36a9e1` | `.trellis/tasks/archive/2026-11/11-21-sync-core-ui-installers/results.md` | 丢弃 | 旧 results 缺同步后的云端记录。绝对工作区路径无迁移价值。丢弃，不出补丁 |
| `5cd7a73a0721d1af0fc8e3f52cb9ac3c83367b13` | `.trellis/scripts/common/__pycache__/task_context.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `68b766b512955e25025e7b73aa8cde392c5cfcfa` | `.trellis/tasks/11-18-desktop-env-icons-packages/reports/ci-readiness.md` | 丢弃 | ci-readiness 旧稿。main 保留动作摘要及后续云端结果。丢弃，不出补丁 |
| `9157c068d9b96b3b4f77204bf1653dd17bbece69` | `.trellis/tasks/11-26-github-workspace-migration/task.json` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `f757ab0c61e4c29b644451ae575b1276ab114595` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/wasi/launch.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `4cb8dcc91ae278b7b10eee63f44fefff395e7629` | `.trellis/scripts/common/__pycache__/git_context.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `dcb85430e6ed52704f5af18e687244824d136684` | `.trellis/tasks/11-26-github-branch-reconciliation/implement.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `4619fca0678b1196232f15dadd165d5d392ffc38` | `.trellis/.developer` | 丢弃 | 机器身份或活跃会话状态，不是项目知识。丢弃，不出补丁 |
| `d97a58f287b911ff58377542eaf00c81ba47537f` | `.trellis/tasks/10-22-offline-standalone-ide/research/c-editor-analysis-source-handoff-20261024.md` | 丢弃 | 旧 handoff 缺 legacy R5/R8 与 umbrella R10 对照。丢弃，不出补丁 |
| `e41a6c31742c9413edb5de14fb53327bb02c56ac` | `README.zh-TW.md` | 丢弃 | 旧繁中 README 缺运行时边界和 GPL 节。丢弃，不出补丁 |
| `b53b458dbcb2389ac3418d82e7e18f0836684be8` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/native/sha256.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `e1db5f38df104e12c9a81a2705a56651b4c0ace0` | `旧片段，见证据说明` | 丢弃 | 旧机器会话指针，不是持久项目进度。丢弃，不出补丁 |
| `153c72be77f83e195d8aad423fae82d2e337d48f` | `旧片段，见证据说明` | 丢弃 | 旧机器会话指针，不是持久项目进度。丢弃，不出补丁 |
| `435ccc56272ca004095275dcc1805bfbb88fd5e6` | `tool/host_baseline/baseline_200_window.py` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `6d5cfa557d087cb8bf36300b66b65ed65af7edc1` | `.trellis/tasks/11-26-trellis-cloud-only-rules/prd.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `0cbdbdb23a347a0daab493d006074494023120f6` | `.trellis/tasks/11-26-trellis-cloud-only-rules/task.json` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `55fd202477b9627d3f46d280c8a14c7ba16c7a55` | `.trellis/scripts/common/__pycache__/workflow_phase.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `a15d749133584330c65e03983b9a76028e4de313` | `.trellis/tasks/11-26-six-platform-cloud-delivery/implement.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `a9bd334e9a3449841a02d6aea41274ae86eeecf5` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/SHA256SUMS.txt` | 丢弃 | 旧摘要表缺 .gitattributes 条目。main 是其超集。丢弃，不出补丁 |
| `c95dd380d0cd332eeb01ad8a082c5597a4426a81` | `tool/host_baseline/baseline_200_owned_job.py` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `cd7d2393a45e5e8666cabda455c42d924e380a2d` | `.trellis/scripts/common/__pycache__/trellis_config.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `067e263c4e41a0f334ffc2b175f5ddfefd99fddb` | `.trellis/scripts/common/__pycache__/developer.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `203ea728f4c858e14b76b59c4514a580103be5ba` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/README.md` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `52be1b4210e581b41fbf7c889d9b8b7c0609ab0b` | `.trellis/scripts/common/__pycache__/tasks.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |
| `935eff0cec76d0077033306f26682e2a3909a206` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-controls-20261026/SHA256SUMS.txt` | 丢弃 | 旧摘要表只含换行差异，并缺 .gitattributes 条目。丢弃，不出补丁 |
| `a9df55bd7fdf5876b92f9545e62d3772aab5b96e` | `.trellis/tasks/11-26-github-branch-reconciliation/design.md` | 当前未提交内容 | 与当前源目录文件相同，交由文件所有者保留。0001 保留既有任务文件 |
| `b73f99ea746c04f5922ffcf1fa2945169ca789cf` | `.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/wasi/manifest.json` | 与 main 等价 | 原始字节的换行规范化后相同。保留 main，不出补丁 |
| `d05f1f71c059969f3ff3bd86d899cb7d1a2ab78b` | `.trellis/scripts/common/__pycache__/safe_commit.cpython-313.pyc` | 丢弃 | Python 缓存字节码，可由已跟踪源码再生。丢弃，不出补丁 |

## 归并后可删除的分支和 worktree

这里只建议，不执行删除。
先将持久任务记录送入 GitHub main。
再由目标克隆确认 SHA、tree、干净状态和零构建产物。
还须通过 cpp-handoff 的嵌套仓库与保留文件门禁。

| 分支 | worktree | 条件 |
| --- | --- | --- |
| `ci/ui-core-installers-20261121` | `D:/MyNewProjects/_wt/qfli-c-ui-sync/qfli_c` | 本报告处置入库，所有者确认后可删 |
| `ci/app-installers` | `D:/MyNewProjects/_wt/qfli_c-ci-app-installers` | 本报告处置入库，所有者确认后可删 |
| `wp/ci-packaging` | `D:/MyNewProjects/_wt/qfli_c-wp-ci` | 本报告处置入库，所有者确认后可删 |
| `wp/env-core` | `D:/MyNewProjects/_wt/qfli_c-wp-env-core` | 本报告处置入库，所有者确认后可删 |
| `wp/env-ui` | `D:/MyNewProjects/_wt/qfli_c-wp-env-ui` | 本报告处置入库，所有者确认后可删 |
| `wp/icons` | `D:/MyNewProjects/_wt/qfli_c-wp-icons` | 本报告处置入库，所有者确认后可删 |
| `backup/main-before-sync-20261125` | 无 | 本地签名差异已明确丢弃后可删 |
| GitHub `ci/app-installers`、`ci/ui-core-installers-20261121` | 不适用 | 仅建议远端所有者在最终主线确认后删除 |
保留 main。保留 cpp-ci 活跃分支与新 worktree。
旧四个镜像远端均落后 64 个提交，不需要从它们归并源码。

## 边界与证据

GitHub main 尚未接收本轮新增任务记录。协调者负责最后提交和推送。
cpp-ci 的新分支独立交付，不属于六个旧 worktree。
cpp-trellis 负责共享 agent 定义、忽略规则和持久知识补存。
cpp-handoff 已发现 native/build 内有脏嵌套仓库。
因此本审计完成不表示现在可以删除旧目录。
该嵌套仓库和忽略文件的处置由 cpp-handoff 报告承接。
本轮未触碰目标克隆，未执行本地构建、产品测试或依赖安装。
未接触 WSL，未删除分支或 worktree。

外部逐项证据位于报告目录：
- `cpp-git-remotes.json`、`cpp-git-ref-comparison.json`。
- `cpp-git-worktrees.json`、`cpp-git-worktree-diffs.txt`。
- `cpp-git-backup.json`、`cpp-git-snapshots.json`。
- `cpp-git-fsck.json`、`cpp-git-reflog.json`。
- `cpp-git-loose-trees.json`、`cpp-git-loose-diffs.txt`。
- `cpp-git-object-disposition.json`、`cpp-git-orphan-final.json`。
- `cpp-git-orphan-review.txt` 仅含非签名差异。

STATUS: DONE
