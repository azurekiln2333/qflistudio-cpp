cmake_minimum_required(VERSION 3.24)
project(qfli_portable_runtime LANGUAGES C CXX)

include(FetchContent)
FetchContent_Declare(wasmedge
  URL https://codeload.github.com/WasmEdge/WasmEdge/tar.gz/845df599e7b71c98b0c77990c3aa3a10022bbaae
  URL_HASH SHA256=70c117f3c9bc22d6e3f83077167154336fd66f7f12c6373979de12d79386a197
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  PATCH_COMMAND "${CMAKE_COMMAND}" "-DQFLI_WASMEDGE_SOURCE=<SOURCE_DIR>"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/apply-wasmedge-patch.cmake"
)
FetchContent_Declare(fmt
  URL https://codeload.github.com/fmtlib/fmt/tar.gz/refs/tags/11.0.2
  URL_HASH SHA256=6cb1e6d37bdcb756dbbe59be438790db409cdb4868c66e888d5df9f13f7c027f
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_Declare(spdlog
  URL https://codeload.github.com/gabime/spdlog/tar.gz/refs/tags/v1.13.0
  URL_HASH SHA256=534f2ee1a4dcbeb22249856edfb2be76a1cf4f708a20b0ac2ed090ee24cfdbc9
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
set(WASMEDGE_USE_LLVM OFF CACHE BOOL "Interpreter only" FORCE)
set(WASMEDGE_BUILD_SHARED_LIB OFF CACHE BOOL "Static embedding" FORCE)
set(WASMEDGE_BUILD_STATIC_LIB ON CACHE BOOL "Static embedding" FORCE)
set(WASMEDGE_BUILD_TOOLS OFF CACHE BOOL "Embedding only" FORCE)
set(WASMEDGE_BUILD_PLUGINS OFF CACHE BOOL "No optional plugins" FORCE)
set(WASMEDGE_BUILD_TESTS OFF CACHE BOOL "Use Forge fixtures" FORCE)
if(FETCHCONTENT_SOURCE_DIR_WASMEDGE)
  set(QFLI_WASMEDGE_SOURCE "${FETCHCONTENT_SOURCE_DIR_WASMEDGE}")
  include("${CMAKE_CURRENT_SOURCE_DIR}/apply-wasmedge-patch.cmake")
endif()
FetchContent_MakeAvailable(wasmedge)
set(QFLI_WASMEDGE_SOURCE "${wasmedge_SOURCE_DIR}")
include("${CMAKE_CURRENT_SOURCE_DIR}/apply-wasmedge-patch.cmake")

find_package(Threads REQUIRED)
add_library(qfli_wasm STATIC wasm_runtime.cpp)
target_compile_features(qfli_wasm PRIVATE cxx_std_17)
target_include_directories(qfli_wasm PUBLIC include)
target_include_directories(qfli_wasm PRIVATE "${wasmedge_SOURCE_DIR}/include/api")
target_link_libraries(qfli_wasm PUBLIC wasmedge_static Threads::Threads ${CMAKE_DL_LIBS})

option(QFLI_BUILD_WASM_TESTS "Build the host execution probe" OFF)
if(QFLI_BUILD_WASM_TESTS)
  add_executable(qfli_wasm_probe tests/runtime_probe.cpp)
  target_compile_features(qfli_wasm_probe PRIVATE cxx_std_17)
  target_link_libraries(qfli_wasm_probe PRIVATE qfli_wasm)
endif()
