#include "qfli_compiler.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <memory>
#include <string>
#include <thread>
#include <vector>
#include <unistd.h>

int compile(const char *sdk, const char *project_path, const char *output,
            bool cancel, bool cancel_before) {
  const auto project = std::filesystem::absolute(project_path);
  std::vector<std::string> sources;
  for (const auto &entry : std::filesystem::recursive_directory_iterator(project)) {
    if (!entry.is_regular_file() || entry.is_symlink()) continue;
    auto extension = entry.path().extension().string();
    std::transform(extension.begin(), extension.end(), extension.begin(),
                   [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
    if (extension == ".c" || extension == ".cpp" || extension == ".cc" ||
        extension == ".cxx") sources.push_back(entry.path().string());
  }
  std::sort(sources.begin(), sources.end());
  std::vector<const char *> paths;
  for (const auto &source : sources) paths.push_back(source.c_str());
  std::unique_ptr<qfli_compiler_session, decltype(&qfli_compiler_destroy)> session(
      qfli_compiler_create(), qfli_compiler_destroy);
  if (!session) return 127;
  if (cancel_before) qfli_compiler_cancel(session.get());
  std::atomic<bool> finished{false};
  std::thread stop;
  if (cancel) {
    stop = std::thread([&] {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      if (!finished.load()) qfli_compiler_cancel(session.get());
    });
  }
  const int code = qfli_compiler_compile(session.get(), sdk, project.c_str(), output,
                                        paths.data(), paths.size(), STDERR_FILENO);
  finished.store(true);
  if (stop.joinable()) stop.join();
  return code;
}

int main(int argc, char **argv) {
  bool cancel = false, cancel_before = false, repeat = false, sequence = false;
  bool recover = false;
  int first = 1;
  for (; first < argc && argv[first][0] == '-'; ++first) {
    if (std::strcmp(argv[first], "--cancel") == 0) cancel = true;
    else if (std::strcmp(argv[first], "--cancel-before") == 0) cancel_before = true;
    else if (std::strcmp(argv[first], "--repeat") == 0) repeat = true;
    else if (std::strcmp(argv[first], "--sequence") == 0) sequence = true;
    else if (std::strcmp(argv[first], "--cancel-recover") == 0) cancel = recover = true;
    else if (std::strcmp(argv[first], "--cancel-before-recover") == 0) cancel_before = recover = true;
    else return 2;
  }
  if (recover) {
    if (argc - first != 4) return 2;
    const char *sdk = argv[first], *project = argv[first + 1];
    const char *output = argv[first + 2], *good_project = argv[first + 3];
    if (compile(sdk, good_project, output, false, false)) return 126;
    const int code = compile(sdk, project, output, cancel, cancel_before);
    const auto directory = std::filesystem::path(output);
    if (code != 130 || std::filesystem::exists(directory / "program.wasm") ||
        std::filesystem::exists(directory / "program.pending.wasm")) {
      std::fprintf(stderr, "Expected cancelled compiler cleanup, got %d.\n", code);
      return 126;
    }
    return compile(sdk, good_project, output, false, false);
  }
  if (sequence) {
    if (argc - first < 4 || (argc - first - 1) % 3 != 0) return 2;
    const char *sdk = argv[first++];
    for (; first < argc; first += 3) {
      const int expected = std::stoi(argv[first + 2]);
      const int code = compile(sdk, argv[first], argv[first + 1], false, false);
      if (code != expected ||
          std::filesystem::exists(std::filesystem::path(argv[first + 1]) /
                                  "program.wasm") != (code == 0)) {
        std::fprintf(stderr, "Expected compiler status %d, got %d.\n", expected, code);
        return 126;
      }
    }
    return 0;
  }
  if (argc - first != 3) return 2;
  int code = 0;
  for (int run = 0; run < (repeat ? 2 : 1); ++run) {
    code = compile(argv[first], argv[first + 1], argv[first + 2], cancel, cancel_before);
    if (code) return code;
  }
  return code;
}
