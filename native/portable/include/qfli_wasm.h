#ifndef QFLI_WASM_H
#define QFLI_WASM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct qfli_wasm_session qfli_wasm_session;

qfli_wasm_session *qfli_wasm_create(void);

// One execution per session. FDs are borrowed and must stay open until return.
// Use a finite input file, and drain output pipes concurrently on the caller.
int qfli_wasm_run(qfli_wasm_session *session, const char *module_path,
                  const char *project_path, int input_fd, int output_fd,
                  int error_fd, uint64_t cost_limit);

// May be called from another thread; join the run before destroying its session.
void qfli_wasm_cancel(qfli_wasm_session *session);
const char *qfli_wasm_error(const qfli_wasm_session *session);
void qfli_wasm_destroy(qfli_wasm_session *session);

#ifdef __cplusplus
}
#endif

#endif
