#include "qfli_wasm.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <memory>
#include <thread>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char **argv) {
  bool cancel = false;
  bool cancel_before = false;
  bool repeat = false;
  uint64_t cost_limit = 0;
  int first = 1;
  for (; first < argc && argv[first][0] == '-'; ++first) {
    if (std::strcmp(argv[first], "--cancel") == 0) cancel = true;
    else if (std::strcmp(argv[first], "--cancel-before") == 0) cancel_before = true;
    else if (std::strcmp(argv[first], "--repeat") == 0) repeat = true;
    else if (std::strcmp(argv[first], "--fuel") == 0) cost_limit = 100;
    else return 2;
  }
  if (argc - first != 2) return 2;

  int code = 0;
  for (int run = 0; run < (repeat ? 2 : 1); ++run) {
    // The application opens a fresh finite input file for each run.
    if (run && lseek(STDIN_FILENO, 0, SEEK_SET) < 0) return 126;
    std::unique_ptr<qfli_wasm_session, decltype(&qfli_wasm_destroy)> session(
        qfli_wasm_create(), qfli_wasm_destroy);
    if (!session) return 125;
    if (cancel_before) qfli_wasm_cancel(session.get());
    std::atomic<bool> finished{false};
    std::thread stop;
    if (cancel) {
      stop = std::thread([&] {
        // stdout is redirected to a regular file by the fixture verifier.
        for (int i = 0; i < 500 && !finished.load(); ++i) {
          struct stat output{};
          if (fstat(STDOUT_FILENO, &output) == 0 && output.st_size > 0) break;
          std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if (!finished.load()) qfli_wasm_cancel(session.get());
      });
    }
    code = qfli_wasm_run(session.get(), argv[first], argv[first + 1],
                         STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO, cost_limit);
    finished.store(true);
    if (stop.joinable()) stop.join();
    if (*qfli_wasm_error(session.get())) {
      std::fprintf(stderr, "%s\n", qfli_wasm_error(session.get()));
    }
    // Runtime teardown must leave all caller-owned descriptors open.
    struct stat descriptor{};
    if (fstat(STDIN_FILENO, &descriptor) || fstat(STDOUT_FILENO, &descriptor) ||
        fstat(STDERR_FILENO, &descriptor)) return 126;
  }
  return code;
}
