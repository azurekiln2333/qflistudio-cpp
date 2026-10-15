# OHOS 原生编译运行桥。
#
# 只构建一个共享库：libqfli_ohos_runner.so。
# 它是 NAPI 模块，由 ArkTS 通过 import 加载，内部 fork/exec 启动打包的 clang。
#
# 注意这里不链接 LLVM：编译器是预先构建并安装到签名 native library 目录的
# 可执行文件；只有头文件、sysroot 和配置资源解压到 App 私有目录。
# 这与 Android 的架构一致，比把 LLVM 链进 .so 省几百 MB。
cmake_minimum_required(VERSION 3.5.0)
project(qfli_ohos_runner)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(qfli_ohos_runner SHARED qfli_ohos_runner.cpp)

target_link_libraries(qfli_ohos_runner PUBLIC
  # NAPI 运行时与 OHOS 日志。
  libace_napi.z.so
  libhilog_ndk.z.so
)
