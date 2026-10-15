# Signed native LLVM/LLD and interpreter; user output is WASI bytecode data.
cmake_minimum_required(VERSION 3.16)
project(qfli_ohos_runner)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QFLI_PORTABLE_PACKAGE "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native/build/ohos-portable/package"
    CACHE PATH "Output of build-ohos-portable.sh")
if(NOT OHOS_ARCH STREQUAL "arm64-v8a" AND NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  message(FATAL_ERROR "The OHOS portable package currently supports arm64-v8a only")
endif()
foreach(component compiler wasm)
  set(archive "${QFLI_PORTABLE_PACKAGE}/lib/arm64-v8a/libqfli_${component}.a")
  if(NOT EXISTS "${archive}")
    message(FATAL_ERROR "Missing ${archive}; run native/toolchain/build-ohos-portable.sh first")
  endif()
  add_library(qfli_${component} STATIC IMPORTED)
  set_target_properties(qfli_${component} PROPERTIES IMPORTED_LOCATION "${archive}")
endforeach()

add_library(qfli_ohos_runner SHARED qfli_ohos_portable.cpp)
target_compile_options(qfli_ohos_runner PRIVATE -fexceptions -frtti -fvisibility=hidden)
target_link_options(qfli_ohos_runner PRIVATE
  -Wl,--exclude-libs,ALL -Wl,-z,defs
  -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384)

target_link_libraries(qfli_ohos_runner PUBLIC
  -Wl,--start-group qfli_compiler qfli_wasm -Wl,--end-group
  # NAPI 运行时与 OHOS 日志。
  libace_napi.z.so
  libhilog_ndk.z.so
  dl m
)
