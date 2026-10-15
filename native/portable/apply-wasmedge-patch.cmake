cmake_minimum_required(VERSION 3.24)

if(NOT DEFINED QFLI_WASMEDGE_SOURCE OR NOT IS_DIRECTORY "${QFLI_WASMEDGE_SOURCE}")
  message(FATAL_ERROR "QFLI_WASMEDGE_SOURCE must identify the pinned WasmEdge source.")
endif()
find_program(QFLI_PATCH_GIT git REQUIRED)
get_filename_component(source_parent "${QFLI_WASMEDGE_SOURCE}" DIRECTORY)
function(qfli_apply_wasmedge_patch name expected_hash)
  set(patch "${CMAKE_CURRENT_LIST_DIR}/patches/${name}")
  file(SHA256 "${patch}" patch_hash)
  if(NOT patch_hash STREQUAL expected_hash)
    message(FATAL_ERROR "WasmEdge ${name} SHA256 mismatch: ${patch_hash}")
  endif()
  # Stop Git discovering Forge's parent repository and skipping nested paths.
  set(git_command "${CMAKE_COMMAND}" -E env
    "GIT_CEILING_DIRECTORIES=${source_parent}" "${QFLI_PATCH_GIT}")
  execute_process(
    COMMAND ${git_command} apply --reverse --check "${patch}"
    WORKING_DIRECTORY "${QFLI_WASMEDGE_SOURCE}"
    RESULT_VARIABLE already_applied OUTPUT_QUIET ERROR_QUIET
  )
  if(already_applied EQUAL 0)
    return()
  endif()
  execute_process(
    COMMAND ${git_command} apply --check "${patch}"
    WORKING_DIRECTORY "${QFLI_WASMEDGE_SOURCE}"
    RESULT_VARIABLE can_apply OUTPUT_QUIET ERROR_VARIABLE patch_error
  )
  if(NOT can_apply EQUAL 0)
    message(FATAL_ERROR "WasmEdge source does not match ${name}: ${patch_error}")
  endif()
  execute_process(
    COMMAND ${git_command} apply "${patch}"
    WORKING_DIRECTORY "${QFLI_WASMEDGE_SOURCE}"
    RESULT_VARIABLE applied OUTPUT_QUIET ERROR_VARIABLE patch_error
  )
  if(NOT applied EQUAL 0)
    message(FATAL_ERROR "Cannot apply WasmEdge ${name}: ${patch_error}")
  endif()
endfunction()
qfli_apply_wasmedge_patch(wasmedge-interruptible-poll.patch
  751c8581be13c260c83b6a7bc212352ba953b480a2ab18659d302aea93e01c4e)
qfli_apply_wasmedge_patch(wasmedge-static-archive.patch
  2df4a65505f1b1b58a66a3b361bedbeb375434045b59edadfdfa5a9f42a8c294)
qfli_apply_wasmedge_patch(wasmedge-shared-memory-growth.patch
  e593f66d367fd9efd54bb27446f81f0a70d1093df8bf899e3f2c5910b988c9b9)
