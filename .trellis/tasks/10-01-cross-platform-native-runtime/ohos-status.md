# OHOS / Android 本次验收状态（2026-10-15）

当前结论：**OHOS 桥接和打包缺陷已修复，正式 release HAP、设备验收 HAP 与 Android release APK 均构建成功；OHOS 应用内验收尚未完成，手机锁屏阻止启动。不得将构建成功报告成完整移植验收通过。**

## 范围、授权和工作区

- 所有代码与报告写入 `D:/MyNewProjects/qfli_c`。Herdr 实际工作区为 `w6`，三个 Pi 为 `w6:p4`、`w6:p5`、`w6:p7`，启动前均核实 cwd 和 Git 根目录。
- 本轮用户明确要求 OHOS 完整测试、Android 仅构建不推送、标准化 Git 提交，并增加 C/C++ 教程/示例检查；这些要求覆盖旧任务的禁止 OHOS 调试和不提交限制。
- 未修改兄弟工作区，未执行 Android 安装、推送或设备调试；保留用户原有 OHOS 签名配置。

## 已修复的实际阻塞

- 工具链 C++ 头文件检查路径错误，导致真实工具链始终被判不可用。
- NAPI external 句柄误用、缓存目录未传入、同一 PID 文件重复使用、资源读取方式错误。
- 编译器/链接器改装入 HAP 签名 native library 目录；资源 ZIP 仅保留配置、头文件和链接资源，约 13 MiB。
- 移除 Android 遗留 `-latomic`：OHOS SDK 没有该库，OHOS compiler-rt 提供原子实现；保留 `-lm`。
- 修复 EOF 后取消、后代进程清理、句柄释放后调用、符号链接清理、大小写源扩展、UTF-8 与按行输出。
- 为四个工具链 native 文件配置精确 strip 排除；最终 HAP 文件必须与清单 SHA256 一致，未放宽校验器。

## 实际检查结果

| 检查 | 结果 |
| --- | --- |
| Flutter 全仓静态分析 | No issues found；只排除生成目录，没有屏蔽真实源文件 |
| Flutter 全量 VM 测试 | 176/176 通过 |
| 原生桥/真实 NAPI + executor 主机回归 | 7 组全部通过，含混编、异常、stdin、非零退出、崩溃、取消、GC、错误后禁止旧产物 |
| OHOS SDK ARM64 C++ 严格语法检查 | 通过 `-Wall -Wextra -Werror` |
| 实际 OHOS 资源交叉链接 | C17 math/stdatomic、C++20 标准库/异常、混编/项目头文件/span/16 字节 atomic、未定义符号拒绝通过 |
| ArkTS 实际源码逻辑检查 | 资源分段读写、准备取消、单次终止、完整行与缓存/参数检查通过 |
| OHOS release HAP | ArkTS、native、打包、签名通过 |
| HAP 资源与可执行文件审计 | ELF ABI、依赖、加载器、资源 ZIP、原文件 SHA256 全部通过 |
| Android release APK | ARM64 + x86_64 完整工具链；构建、v2 签名和 ELF/资源/16 KiB 对齐检查通过；无设备操作 |
| C/C++ 教程与示例 | 各语言 100 组，400 个实际加载行与 staging 一致，零占位；200/200 原生编译运行、10/10 负例、33 个内容集成/管线测试通过 |

## OHOS 设备验收的真实阻塞

设备是此前获授权的 nova 14 Ultra（`MRT-AL10`），HDC 目标 `192.168.68.207:46551`。验收 HAP 已安装成功，但 `aa start` 返回：

```text
Error Code:10106102
The device screen is locked during the application launch, unlock screen failed.
The current mode is developer mode, and the screen cannot be unlocked automatically.
```

已请用户解锁并保持屏幕亮。未尝试绕过锁屏。当前没有 `QFLI_C_OHOS_AUDIT ok:true` 证据，全部应用内编译/运行/取消和 200 个教程代码的手机结果均保持待验。

重启后已重新向 `w6:p4`、`w6:p5`、`w6:p7` 下发分工，三者均再次确认本仓库路径。Pi 真机复查仍是相同锁屏错误，具体证据见 `research/device-recheck-2026-10-15.md`。构建/分析修复已提交为 `7f92787`，本轮源代码与课程证据另有 `797d9b7`、`49a7579`、`cccc0b8`。

## 解锁后的连续步骤

1. 启动已安装的验收 App，观察 `QFLI_C_OHOS_CASE`，要求 C/C++/异常/混编/错误/崩溃/取消/UTF-8 等 10 个基础用例及 200 个课程示例全部通过。
2. 如失败，直接修复实际错误、补相应回归、提交后重验；不得将 Linux 主机结果当成手机结果。
3. 安装恢复 `lib/main.dart` 正式 release HAP，核验普通编辑器 Run/Stop 与教程/示例入口，保留项目数据。
4. 更新任务检查项、设备/产物记录与平台规范，再完成最终验收提交。

## 产物与记录

- 正式 OHOS release：`native/build/ohos-production-release-20261015.hap`；标准交付路径 `build/ohos/hap/entry-default-signed.hap` 应由 `-t lib/main.dart` 构建。
- 设备验收包：`native/build/ohos-audit-20261015.hap`，入口 `tool/ohos_native_audit.dart`。此包是测试入口，不能冒充正式 UI 包。
- Android：`build/app/outputs/flutter-apk/app-release.apk`（仅 ARM64/x86_64）。
- 详细 Android 结果：`research/android-analysis-2026-10-15.md`；课程逐项证据在 `10-12-c-cpp-substantive-curriculum/research/`。
- Web 不在本轮验收范围；共享核心浏览器集成及编译器资源仍未完成，不能由本轮分析零问题或 Web 源码构建推定 Web App 可用。
