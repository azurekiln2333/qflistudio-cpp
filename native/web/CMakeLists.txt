cmake_minimum_required(VERSION 3.24)
project(qfli_web_compiler LANGUAGES C CXX)
if(NOT EMSCRIPTEN)
  message(FATAL_ERROR "Configure native/web with emcmake; it produces a browser compiler.")
endif()
add_compile_options(-fwasm-exceptions)
set(QFLI_BUILD_COMPILER_TESTS OFF CACHE BOOL "Browser module only" FORCE)
add_subdirectory(../compiler compiler)
add_executable(qfli_compiler_web compiler_web.cpp)
target_link_libraries(qfli_compiler_web PRIVATE qfli_compiler)
set_target_properties(qfli_compiler_web PROPERTIES
  OUTPUT_NAME qfli-compiler SUFFIX .js)
target_link_options(qfli_compiler_web PRIVATE
  --no-entry
  -fwasm-exceptions
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=worker
  -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=134217728
  -sMAXIMUM_MEMORY=2147483648 -sSTACK_SIZE=8388608
  -sFORCE_FILESYSTEM=1 -sNO_EXIT_RUNTIME=1
  "-sEXPORTED_FUNCTIONS=['_qfli_web_compile','_malloc','_free']"
  "-sEXPORTED_RUNTIME_METHODS=['FS','ccall','UTF8ToString','stringToUTF8','lengthBytesUTF8']"
  "--preload-file=${QFLI_WASI_SDK}/share/wasi-sysroot/include/wasm32-wasip1@/sdk/share/wasi-sysroot/include/wasm32-wasip1"
  "--preload-file=${QFLI_WASI_SDK}/share/wasi-sysroot/lib/wasm32-wasip1@/sdk/share/wasi-sysroot/lib/wasm32-wasip1"
  "--preload-file=${QFLI_WASI_SDK}/lib/clang/22@/sdk/lib/clang/22")
if(NOT EXISTS "${QFLI_WASI_SDK}/share/wasi-sysroot/include/wasm32-wasip1/stdio.h")
  message(FATAL_ERROR "QFLI_WASI_SDK must point to the pinned WASI SDK 33.")
endif()
