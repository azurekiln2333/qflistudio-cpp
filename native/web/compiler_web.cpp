#include "qfli_compiler.h"

// Source pointers are owned by the worker during this synchronous call.
extern "C" int qfli_web_compile(const char *project_path,
                                 const char *output_directory,
                                 const char *const *sources,
                                 unsigned source_count) {
  auto *session = qfli_compiler_create();
  if (!session) return 127;
  const int status = qfli_compiler_compile(
      session, "/sdk", project_path, output_directory, sources, source_count, 2);
  qfli_compiler_destroy(session);
  return status;
}
