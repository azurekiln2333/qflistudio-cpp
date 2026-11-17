# CMake also loads this override in its try_compile projects. Setting only the
# cache rule on the outer configure does not propagate to compiler ABI checks.
get_filename_component(qfli_archive_tool "${CMAKE_AR}" NAME)
if(NOT APPLE OR NOT qfli_archive_tool STREQUAL "libtool")
  message(FATAL_ERROR "The iOS archive override requires Apple's libtool")
endif()
foreach(language C CXX)
  set(CMAKE_${language}_CREATE_STATIC_LIBRARY
    "<CMAKE_AR> -static -o <TARGET> <LINK_FLAGS> <OBJECTS>")
endforeach()
