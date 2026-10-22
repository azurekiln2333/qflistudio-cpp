#ifndef QFLI_CODE_ANALYSIS_H
#define QFLI_CODE_ANALYSIS_H

#include "qfli_compiler.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct qfli_source_snapshot {
  const char *path;
  const char *text;
  size_t length;
} qfli_source_snapshot;

// Parse/type-check C17/C++20 using in-memory UTF-8 snapshots over the real SDK
// and project files. Never emit code, link, execute, or write source/output files.
// The active file must appear in snapshots. All paths are absolute and snapshot
// paths must resolve under project_root. At most64 snapshots/16MiB UTF-8.
// Canonicalize reads before the snapshot overlay and confine them to the physical
// project, SDK container, and explicitly resolved WASI/Clang resource roots.
// In-project symlink aliases read the same unsaved snapshot. The analyzer owns
// a virtual project cwd and never changes the process working directory.
// An active header is checked in its entered translation-unit context, or
// independently when no checked translation unit entered it.
// JSON reaches output_fd: diagnostics contain original snapshot paths and
// half-open UTF-8 byte offsets. unmappedErrors distinguishes a closed/system-file
// error from a successful check. Both FDs are borrowed; sessions are single-use.
// Status0/1 means a completed check;127 invalid/unavailable;130 cancelled.
int qfli_compiler_analyze(qfli_compiler_session *session, const char *sdk_root,
                          const char *project_root, const char *active_file,
                          int active_is_cpp,
                          const qfli_source_snapshot *snapshots,
                          size_t snapshot_count, int output_fd,
                          int diagnostic_fd);

#ifdef __cplusplus
}
#endif
#endif
