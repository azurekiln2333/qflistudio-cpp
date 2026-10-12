#ifndef QFLI_COMPILER_H
#define QFLI_COMPILER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct qfli_compiler_session qfli_compiler_session;
qfli_compiler_session *qfli_compiler_create(void);

// SDK resources are WASI SDK 33's share/wasi-sysroot and lib/clang/22.
// All paths must be absolute. The diagnostic FD is borrowed.
// Each session compiles one project; compilation is serialized within the app.
int qfli_compiler_compile(qfli_compiler_session *session, const char *sdk_root,
                          const char *project_path, const char *output_directory,
                          const char *const *sources, size_t source_count,
                          int diagnostic_fd);
void qfli_compiler_cancel(qfli_compiler_session *session);
// Destroy only after the compile call and any cancellation calls have returned.
void qfli_compiler_destroy(qfli_compiler_session *session);

#ifdef __cplusplus
}
#endif

#endif
