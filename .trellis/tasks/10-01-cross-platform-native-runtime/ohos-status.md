# OHOS / Android 本次验收状态（2026-10-16）

当前结论：**本轮 OHOS 应用与 Android 仅构建验收通过。已替换受系统执行策略阻断的进程方案，签名应用内的 ARM64 LLVM22/Clang/LLD 编译器与 WasmEdge 解释器已构建并通过严格产物校验。实际 release 手机完整审计 212/212 通过：12 个基础用例、100 个 C 示例、100 个 C++ 示例。最新正式编辑器 HAP 已严格校验并覆盖安装，Run、Stop、再次运行及教程/示例内容入口全部通过，原项目数据保留。Android 本轮 release 重构建与产物检查通过，未执行设备操作。跨平台总任务保留 iOS/Web 未完成项。**

这里的用户程序目标是 **WASI ABI**：Clang/LLD 将 C17/C++20 编译成 Wasm 数据，由应用内签名解释器运行；编译器与解释器本身是原生 ARM64 库。它不等于可任意链接 OHOS 系统库或调用原生 OHOS API 的机器码移植。不得将构建、主机回归或部分手机用例写成完整移植验收通过。

## 当前方案与证据

| 检查 | 当前结果 |
| --- | --- |
| ARM64 编译器与解释器 | LLVM22/LLD 与 WasmEdge 静态库已完成；实际 OHOS SDK 严格共享库链接通过，保留输入、补丁、对象和产物 provenance |
| 签名工具链资源 | WASI SDK33 资源共 4114 个文件；资源 ZIP SHA256 为 `a29e74b526e4689289d590ab35d1dee6209d9b0ccb7538554284000ef4cc5d27` |
| 实际 NAPI 主机运行 | 31/31 通过；覆盖 C/C++ 混编、异常、SjLj、时钟、stdin、独立输出、线程、内存增长、取消及资源回收 |
| 课程主机执行 | 原生 200/200、portable 200/200 通过；C 与 C++ 各保留 100 组真实课程，OHOS 对 errno/目标宏采用明确的 WASI 预期 |
| Flutter | 完整 VM 178/178、全仓分析零问题；使用本仓库内只读导出的 shared-core `7768b91` 快照，不修改兄弟仓库 |
| 当前 audit HAP | `native/build/ohos-portable-audit-20261016.hap` 已按 `native/build/ohos-portable-audit-artifact-20261016.json` 严格校验 ELF、依赖、资源与原文件哈希 |
| 当前手机审计 | 212/212 全部通过，包括 C++ 线程取消返回 130、共享内存增长及两种语言各 100 个课程示例；逐项唯一性与完整性已核对 |
| 正式 UI | 最新 `lib/main.dart` release HAP 已严格校验、覆盖安装；普通 C++ Run 输出正常、Stop 返回 130、再次 Run 成功；教程与 200 个示例的列表/详情正常，原 `sss`/`tt` 项目保留 |
| Android | 当前课程更新后的 release 构建、签名、ABI、资源和 16 KiB 对齐检查通过；无安装、推送或设备调试 |

实际手机取消用例首次因 C++20 `volatile++` 警告污染 stderr 断言失败；运行时已正确返回 130。修正 fixture 后完整 212 例重新通过，未把首次失败计作成功。最终摘要为 `QFLI_C_OHOS_AUDIT {ok:true,execution:interpreter,passed:212,curriculum:200}`；逐项记录与准确 HAP/log 哈希见 `research/ohos-portable-device-2026-10-16.json`，架构及构建证据见 `research/ohos-portable-acceptance-2026-10-16.md`。

正式 UI 在普通编辑器新建 C++ 项目 `ohos_cpp_verified_20261016`，点击 Run 输出 `Hello, QFLIStudio+!`；再次运行时点击 Stop，实际终端显示 exit code130，随后 fresh Run 成功。教程列表及 lesson 源码、目标、输出、练习可打开；示例列表显示 200 条，详情源码和输出可打开。最终生产 HAP 哈希、原项目保留情况及截图见 `research/ohos-production-ui-2026-10-16.json`；截图保存在 `native/build/qfli-production-{run,stop,tutorials,lesson,examples}-20261016.jpeg`。

## 范围、授权和工作区

- 所有代码与报告写入 `D:/MyNewProjects/qfli_c`。Herdr 实际工作区为 `w6`，三个 Pi 为 `w6:p4`、`w6:p5`、`w6:p7`，启动前均核实 cwd 和 Git 根目录。
- 本轮用户明确要求 OHOS 完整测试、Android 仅构建不推送、标准化 Git 提交，并增加 C/C++ 教程/示例检查；这些要求覆盖旧任务的禁止 OHOS 调试和不提交限制。
- 未修改兄弟工作区，未执行 Android 安装、推送或设备调试；保留用户原有 OHOS 签名配置。

## 历史进程方案修复记录（10-15 至 10-16）

以下是架构替换前的进程工具链修复和验证记录。它们保留诊断依据，但不代表当前生产运行方式；当前规范为 `.trellis/spec/backend/ohos-runtime.md` 的应用内编译与解释执行契约。

- 工具链 C++ 头文件检查路径错误，导致真实工具链始终被判不可用。
- NAPI external 句柄误用、缓存目录未传入、同一 PID 文件重复使用、资源读取方式错误。
- 编译器/链接器改装入 HAP 签名 native library 目录；资源 ZIP 仅保留配置、头文件和链接资源，约 13 MiB。
- 移除 Android 遗留 `-latomic`：OHOS SDK 没有该库，OHOS compiler-rt 提供原子实现；保留 `-lm`。
- 修复 EOF 后取消、后代进程清理、句柄释放后调用、符号链接清理、大小写源扩展、UTF-8 与按行输出。
- 为四个工具链 native 文件配置精确 strip 排除；最终 HAP 文件必须与清单 SHA256 一致，未放宽校验器。

## 历史进程方案检查结果

| 检查 | 结果 |
| --- | --- |
| Flutter 全仓静态分析 | No issues found；只排除生成目录，没有屏蔽真实源文件 |
| Flutter 全量 VM 测试 | 176/176 通过 |
| 原生桥/真实 NAPI + executor 主机回归 | 15 组全部通过，含混编、异常、stdin、非零退出、崩溃、取消、GC、错误后禁止旧产物、初始化错误和 loader 参数解析；不是手机通过证据 |
| OHOS SDK ARM64 C++ 严格语法检查 | 通过 `-Wall -Wextra -Werror` |
| 实际 OHOS 资源交叉链接 | C17 math/stdatomic、C++20 标准库/异常、混编/项目头文件/span/16 字节 atomic、未定义符号拒绝通过 |
| ArkTS 实际源码逻辑检查 | 资源分段读写、准备取消、单次终止、完整行与缓存/参数检查通过 |
| OHOS release HAP | ArkTS、native、打包、签名通过 |
| HAP 资源与可执行文件审计 | ELF ABI、依赖、加载器、资源 ZIP、原文件 SHA256 全部通过 |
| Android release APK | ARM64 + x86_64 完整工具链；构建、v2 签名和 ELF/资源/16 KiB 对齐检查通过；无设备操作 |
| C/C++ 教程与示例 | 各语言 100 组，400 个实际加载行与 staging 一致，零占位；200/200 原生编译运行、10/10 负例、33 个内容集成/管线测试通过 |

## 历史设备阻塞与架构替换依据

设备是此前获授权的 nova 14 Ultra（`MRT-AL10`），HDC 目标 `192.168.68.207:46551`。2026-10-16 已正常启动实际 release 验收应用，取代 10-15 的锁屏阻塞。依次复现并定位：

```text
nativeLibraryPath=libs/arm64（相对路径，已改为按 bundleCodeDir 解析）
executor st_mode=0100644, R_OK=yes, X_OK denied（安装的原生文件无执行位）
execve('/system/lib/ld-musl-aarch64.so.1') = EACCES, errno 13（精确真机诊断）
```

在应用内方案替换前，验收停在 `real-C-source exit=125`、`passed:[]`，没有 `QFLI_C_OHOS_AUDIT ok:true` 证据。直接 fork/exec 链路不适用于这台 release 手机；官方 native-child API 随后确定返回 `16010004`（`NCP_ERR_MULTI_PROCESS_DISABLED`）。因此切换到签名原生编译器与 WASI 解释器，未更改系统策略，也不使用 JIT 或新生成原生代码映射。这个历史失败不代表当前已通过的基础/C 示例仍不可用。

此前三个代理均限定本仓库：原生桥、官方子进程探针、portable 交叉构建。历史失败日志和准确阶段见 `research/ohos-device-acceptance-2026-10-16.md`。10-15 的锁屏检查及以上 EACCES 记录保留为历史，不代表当前 portable 方案的验收进度。

## 当前收尾与跨平台未完成项

1. 保留已通过的 `212/212` 签名应用真机审计及解释执行目标，不重复将主机测试充作手机证据。
2. 正式 `lib/main.dart` release 已恢复，普通编辑器 Run/Stop、再次运行和教程/示例验收通过；保留原项目数据。
3. 完成最终记录、日志与授权的提交/远端同步；不得把记录中的旧失败包替代当前正式包。
4. 跨平台总任务仍为 `in_progress`，iOS 的 Apple 构建/设备和 Web 的实际编译器/共享核心/UI 门槛继续保留，不归档总任务。

## 产物与记录

- 当前设备验收包：`native/build/ohos-portable-audit-20261016.hap`，入口 `tool/ohos_native_audit.dart`；严格产物记录为 `native/build/ohos-portable-audit-artifact-20261016.json`。此包是测试入口，不能冒充正式 UI 包。
- 已通过手机审计的 HAP SHA256：`e85120111893d9a319eb1160440037f26e2cd13e14b154fbf186e91087c7c1d2`；逐项手机证据为 `research/ohos-portable-device-2026-10-16.json`。
- 正式 OHOS 标准交付路径：`build/ohos/hap/entry-default-signed.hap`，已由 `-t lib/main.dart` 构建并完成严格校验、覆盖安装和正式 UI 验收；准确生产包哈希及证据引用 `research/ohos-production-ui-2026-10-16.json`。
- 历史进程方案产物：`native/build/ohos-production-release-20261015.hap`、`native/build/ohos-audit-20261015.hap`；精确哈希保留于 `research/acceptance-artifacts-2026-10-15.json`。
- Android：`build/app/outputs/flutter-apk/app-release.apk`（仅 ARM64/x86_64）。
- 当前 Android 结果：`research/android-build-acceptance-2026-10-16.md` 与 `research/android-release-artifact-2026-10-16.json`；历史结果为 `research/android-analysis-2026-10-15.md`。课程逐项证据在 `10-12-c-cpp-substantive-curriculum/research/`。
- Web 不在本轮验收范围；共享核心浏览器集成及编译器资源仍未完成，不能由本轮分析零问题或 Web 源码构建推定 Web App 可用。
