# Forge OHOS 包体积核查（2026-10-17）

结论：当前包尚未最小化，确实包含当前 Forge 路由未使用的资源。
遵守用户“不要影响工具链”的要求，编译器、SDK、线程、C++ 异常和运行时完整保留。
本次仅核查、生成报告和隔离链接实验，没有修改产品源码、工具链或正式 HAP。

## 被检查的正式包

- 路径：`build/ohos/hap/entry-default-signed.hap`
- 大小：**151,351,796 B / 144.34 MiB**（151.35 MB）
- SHA256：`42842f1fde02203ce3f90db744cae8c24dc98e60eb31a0067451c446873fbf30`
- 包名：`com.azurekiln.qfli.cpp`
- 原生库 ABI：仅 `arm64-v8a`，没有 x86_64 或 armeabi-v7a。
- 4 个原生 ELF 都已移除 `.debug*`、`.symtab`、`.strtab`，未发现调试符号膨胀。

以下为 ZIP 条目大小；所有外层条目均使用 STORE，SDK 内层 ZIP 自带压缩。

| 内容 | 字节 | MiB |
| --- | ---: | ---: |
| `libqfli_ohos_runner.so`，离线编译与运行 | 93,430,096 | 89.10 |
| `qfli_toolchain/ohos-wasi.zip`，SDK | 16,703,195 | 15.93 |
| `libflutter.so` | 16,286,544 | 15.53 |
| `libapp.so`，Dart AOT | 13,321,136 | 12.70 |
| `libc++_shared.so` | 1,262,504 | 1.20 |
| Flutter assets | 8,343,057 | 7.96 |
| 其他资源、ArkTS 与元数据条目 | 936,092 | 0.89 |
| 容器及签名等开销（总大小与条目之和的差额） | 1,069,172 | 1.02 |

## 当前应用未使用的资源：6,807,831 B / 6.49 MiB

以下路径相对于 `resources/rawfile/flutter_assets/`：

| 资源 | 字节 |
| --- | ---: |
| `packages/qfli_studio_core/assets/content/tutorials.json` | 3,969,122 |
| `packages/qfli_studio_core/assets/content/examples.json` | 1,904,586 |
| `packages/qfli_studio_core/assets/tutorials/python.json` | 378,456 |
| `packages/qfli_studio_core/assets/tutorials/java.json` | 249,035 |
| `packages/qfli_studio_core/assets/tutorials/web.json` | 16,495 |
| `packages/qfli_studio_core/assets/tutorials/dart.json` | 14,252 |
| `packages/qfli_studio_core/assets/tutorials/c.json` | 13,801 |
| `packages/qfli_studio_core/assets/tutorials/cpp.json` | 2,279 |
| `packages/qfli_studio_core/assets/tutorials/lua.json` | 2,177 |
| `packages/cupertino_icons/assets/CupertinoIcons.ttf` | 257,628 |

证据：`lib/main.dart` 安装 `ForgeContentRepository`，它只读取 Forge staging
的两份 JSON。共享主页把同一个 repository 传给教程和示例页，不会走
`AssetContentRepository` 的共享内容回退路径。`TutorialService` 没有生产调用者；
应用、共享 core 与编辑器没有 `CupertinoIcons` 使用点。

这些内容由依赖的共享 core pubspec 广泛声明而被带入。后续应在 Forge 的构建中
筛选，不能全局删除共享 core 文件，其他语言应用仍可能使用。
保留 Forge staging 内容、应用图标、编辑器 RobotoMono 字体及许可、MaterialIcons、
shader、NOTICES 与资源清单；清理时需要同步资源清单并验证教程、示例及图标页面。

单独排除上述 10 项，按当前条目大小估算，HAP 为
**144,543,965 B / 137.85 MiB**，签名与清单开销会稍有变化。
这是预计值，尚未清理或产出新的正式包。这个范围不涉及工具链。

## 工具链保留；以下仅记录研究结果

1. 原生链接的隔离实验仅添加 `--gc-sections`，strip 后从 93,430,096 B
   变成 84,015,296 B，差 **9,414,800 B / 8.98 MiB**。仅证明体积差，
   未做该变体的运行、线程、异常、取消和恢复验证；不计入本次可清理资源，
   不应用到正式工具链。
2. SDK 的两个 sysroot 头文件目录各 1,892 个文件，逐路径、逐字节相同，
   单目录原始大小 12,976,420 B、压缩 payload 2,633,997 B / 2.51 MiB。
   全归档内容去重统计为 2,636,944 B，包含少量其他重复内容，不能全部算作头文件。
   编译器、manifest 和解压校验当前依赖两个目录路径，全部保留。
3. SDK 的 `libc.so` 是 Wasm 数据，不是额外的 OHOS 架构库。
   `native/compiler/compiler.cpp::parse_command` 对参数使用白名单，
   `-shared`、`-fPIC` 被拒绝，不能声称它们目前可用。是否存在可删 SDK 文件
   尚未完成依赖与回归验证，故不计入可靠节省量，也不删除。

## 核查来源与限制

通过 Herdr 分派 3 个 pi，分别核查原生库、应用资源和 SDK；主代理复核包内容、
资源调用路径及编译参数解析，并修正初稿中的参数透传、strip 差额与体积数字。

- 原始测量：`native/build/forge-hap-size-audit-20261017.json`
- 资源报告：`native/build/forge-size-assets-audit-20261017.md`
- 原生实验：`native/build/forge-size-native-audit-20261017.md`
- SDK 报告：`native/build/forge-size-toolchain-audit-20261017.md`

只读审计没有引入产品变更，因此没有重新安装或运行功能测试。
正式 HAP 在审计后 SHA256 与审计前相同。

## 后续补充：APP 发布容器（同日）

用户指出 APP 发布包可以小于 HAP，核实属实：APP 容器对内含 HAP 使用
DEFLATE 压缩，文件大小与 HAP 内条目原始体积不是同一口径，安装后的占用也不同。
以上 6.49 MiB 是 HAP 未压缩资源的节省量，不能直接从压缩 APP 大小扣除。

发现原有 `ohos/build/outputs/default/ohos-default-signed.app` 是过期产物，
仍含 x86_64。已按此前仅 ARM64 的要求，以正式 Flutter 发布命令重新生成：

```text
dart.exe flutter_tools.snapshot build app --release --no-pub --target lib/main.dart --target-platform ohos-arm64
```

- 新签名 APP：`build/ohos/app/ohos-default-signed.app`
- 大小：**70,595,683 B / 67.33 MiB**。
- SHA256：`1eff61092e33cb8df80ec53433b41bc1b9431420f43ffc20cbdb7ebe2413db8a`。
- 内含 HAP：150,275,284 B / 143.31 MiB，外层压缩 payload 为 70,579,630 B。
- 内含 4 个原生库全部属于 arm64-v8a，未包含 x86_64。
- 编译运行库、SDK ZIP 以及其他 3 个原生库的 SHA256 与原审计 HAP 逐个相同。
- MaterialIcons 保留正式发布的 29,008 B 字体裁剪结果；没有带入完整大字体。
- 原始 HAP 副本保持不变；未清理上述 10 项应用资源，也没有裁剪工具链。

单独对原 HAP 做原始 DEFLATE 流的计数实验，level 6/9 分别为
67,358,929 B / 67,260,531 B（64.24 / 64.14 MiB）。这只是压缩流实验，
没有修改正式打包压缩参数，不能当作已生成 APP 的实测大小。

正式构建成功；本次只验证打包内容、ABI 与文件哈希，没有重新安装手机。
检查记录：`native/build/forge-app-arm64-packaging-20261017.json`。
构建日志：`native/build/forge-app-arm64-release-20261017.log`。
