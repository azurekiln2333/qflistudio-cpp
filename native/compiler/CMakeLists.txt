cmake_minimum_required(VERSION 3.24)
project(qfli_wasm_compiler LANGUAGES C CXX)

include(FetchContent)
FetchContent_Declare(llvm22
  URL https://codeload.github.com/llvm/llvm-project/tar.gz/4434dabb69916856b824f68a64b029c67175e532
  URL_HASH SHA256=8d1c513efc817c7b4bef634156e6666e19462de2044c64e8f2df4fdd375a0600
  SOURCE_SUBDIR llvm
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "Compiler and linker" FORCE)
set(LLVM_TARGETS_TO_BUILD WebAssembly CACHE STRING "Portable output only" FORCE)
set(LLVM_ENABLE_EH ON CACHE BOOL "Unwind cooperative cancellation" FORCE)
set(LLVM_ENABLE_RTTI ON CACHE BOOL "Required by LLVM exceptions" FORCE)
set(LLVM_ENABLE_ZLIB OFF CACHE BOOL "No external dependencies" FORCE)
set(LLVM_ENABLE_ZSTD OFF CACHE BOOL "No external dependencies" FORCE)
set(LLVM_ENABLE_LIBXML2 OFF CACHE BOOL "No external dependencies" FORCE)
set(LLVM_ENABLE_LIBEDIT OFF CACHE BOOL "No external dependencies" FORCE)
set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "Use Forge fixtures" FORCE)
set(LLVM_INCLUDE_BENCHMARKS OFF CACHE BOOL "Embedding only" FORCE)
set(LLVM_INCLUDE_EXAMPLES OFF CACHE BOOL "Embedding only" FORCE)
set(LLVM_BUILD_TOOLS OFF CACHE BOOL "Embedding only" FORCE)
set(CLANG_INCLUDE_TESTS OFF CACHE BOOL "Use Forge fixtures" FORCE)
set(CLANG_ENABLE_STATIC_ANALYZER OFF CACHE BOOL "Compilation only" FORCE)
set(CLANG_ENABLE_OBJC_REWRITER OFF CACHE BOOL "C and C++ only" FORCE)
FetchContent_MakeAvailable(llvm22)

add_library(qfli_compiler STATIC compiler.cpp)
target_compile_features(qfli_compiler PRIVATE cxx_std_17)
target_include_directories(qfli_compiler PUBLIC include)
target_include_directories(qfli_compiler PRIVATE
  "${llvm22_SOURCE_DIR}/llvm/include"
  "${llvm22_BINARY_DIR}/include"
  "${llvm22_SOURCE_DIR}/clang/include"
  "${llvm22_BINARY_DIR}/tools/clang/include"
  "${llvm22_SOURCE_DIR}/lld/include"
)
llvm_map_components_to_libnames(qfli_llvm_libs
  WebAssemblyCodeGen WebAssemblyAsmParser WebAssemblyDesc WebAssemblyInfo Passes
)
target_link_libraries(qfli_compiler PUBLIC
  clangCodeGen clangFrontend clangDriver lldWasm lldCommon ${qfli_llvm_libs}
)
option(QFLI_BUILD_COMPILER_TESTS "Build the host in-process compiler probe" OFF)
if(QFLI_BUILD_COMPILER_TESTS)
  add_executable(qfli_compiler_probe tests/compiler_probe.cpp)
  target_compile_features(qfli_compiler_probe PRIVATE cxx_std_17)
  target_link_libraries(qfli_compiler_probe PRIVATE qfli_compiler)
endif()
