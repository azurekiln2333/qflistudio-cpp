#include "qfli_compiler.h"
#include "../include/qfli_wasm_limits.h"

#include <clang/Basic/CodeGenOptions.h>
#include <clang/CodeGen/CodeGenAction.h>
#include <clang/Driver/Compilation.h>
#include <clang/Driver/Driver.h>
#include <clang/Driver/Job.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/CompilerInvocation.h>
#include <clang/Frontend/TextDiagnosticPrinter.h>
#include <clang/Lex/Preprocessor.h>
#include <lld/Common/Driver.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/VirtualFileSystem.h>
#include <llvm/Support/raw_ostream.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <thread>
#include <vector>

LLD_HAS_DRIVER(wasm)

struct qfli_compiler_session {
  std::atomic<bool> cancelled{false};
  std::atomic<bool> used{false};
  bool threads = false;
};

namespace {
namespace fs = std::filesystem;
constexpr int kCancelled = 130;
std::mutex compiler_mutex;
std::once_flag initialized;
bool linker_usable = true;
struct Cancelled {};

struct ModuleOutput {
  fs::path pending;
  fs::path published;
  bool complete = false;
  ~ModuleOutput() {
    std::error_code ignored;
    fs::remove(pending, ignored);
    if (!complete) fs::remove(published, ignored);
  }
};

void check_cancel(qfli_compiler_session &session) {
  if (session.cancelled.load()) throw Cancelled{};
}

class ObjectAction final : public clang::EmitObjAction {
public:
  ObjectAction(llvm::LLVMContext &context, qfli_compiler_session &session)
      : EmitObjAction(&context), session(session) {}

protected:
  bool BeginSourceFileAction(clang::CompilerInstance &compiler) override {
    if (!EmitObjAction::BeginSourceFileAction(compiler)) return false;
    compiler.getPreprocessor().setTokenWatcher(
        [this](const clang::Token &) { check_cancel(session); });
    return true;
  }

private:
  qfli_compiler_session &session;
};

int execute(qfli_compiler_session &session, std::vector<std::string> arguments,
            llvm::raw_ostream &diagnostics, bool linking) {
  check_cancel(session);
  clang::DiagnosticOptions options;
  clang::TextDiagnosticPrinter printer(diagnostics, options);
  const auto vfs = llvm::vfs::getRealFileSystem();
  auto engine = clang::CompilerInstance::createDiagnostics(*vfs, options,
                                                           &printer, false);
  clang::driver::Driver driver(arguments.front(), "wasm32-unknown-wasip1",
                                *engine, "Forge Clang", vfs);
  std::vector<const char *> argv;
  for (const auto &argument : arguments) argv.push_back(argument.c_str());
  std::unique_ptr<clang::driver::Compilation> compilation(
      driver.BuildCompilation(argv));
  if (!compilation || engine->hasErrorOccurred()) return 1;
  if (compilation->getJobs().size() != 1) {
    diagnostics << "Expected a single in-process compiler or linker job.\n";
    return 127;
  }
  const auto &job = *compilation->getJobs().begin();
  const auto &job_arguments = job.getArguments();
  if (linking) {
    if (!linker_usable) {
      diagnostics << "The native linker requires an app restart.\n";
      return 127;
    }
    std::vector<const char *> linker_args{"wasm-ld"};
    linker_args.insert(linker_args.end(), job_arguments.begin(), job_arguments.end());
    const lld::DriverDef drivers[] = {{lld::Wasm, lld::wasm::link}};
    const auto result = lld::lldMain(linker_args, diagnostics, diagnostics, drivers);
    linker_usable = result.canRunAgain;
    check_cancel(session);
    return result.retCode;
  }
  if (job_arguments.empty() || std::string(job_arguments.front()) != "-cc1") {
    diagnostics << "Unexpected compiler job; subprocess execution is disabled.\n";
    return 127;
  }
  auto invocation = std::make_shared<clang::CompilerInvocation>();
  if (!clang::CompilerInvocation::CreateFromArgs(
          *invocation, llvm::ArrayRef(job_arguments).drop_front(), *engine)) return 1;
  invocation->getFrontendOpts().DisableFree = false;
  invocation->getCodeGenOpts().DisableFree = false;
  // CompilerInstance retains the BackendConsumer/module when cooperative
  // cancellation unwinds ExecuteAction. Its context must outlive that cleanup.
  llvm::LLVMContext context;
  clang::CompilerInstance compiler(invocation);
  compiler.setVirtualFileSystem(vfs);
  compiler.setVerboseOutputStream(diagnostics);
  compiler.createDiagnostics(&printer, false);
  compiler.createFileManager();
  compiler.createSourceManager();
  // LLD resets LLVM's global command-line options after every invocation.
  llvm::cl::ResetAllOptionOccurrences();
  const char *backend_args[] = {"forge-clang", "-wasm-enable-eh", "-wasm-enable-sjlj",
                                "-wasm-use-legacy-eh=false"};
  llvm::cl::ParseCommandLineOptions(4, backend_args, "", &diagnostics);
  context.setYieldCallback(
      [](llvm::LLVMContext *, void *opaque) {
        check_cancel(*static_cast<qfli_compiler_session *>(opaque));
      }, &session);
  ObjectAction action(context, session);
  const bool success = compiler.ExecuteAction(action);
  check_cancel(session);
  return success ? 0 : 1;
}

std::vector<std::string> base_arguments(const fs::path &sdk, bool cpp,
                                      bool threads, bool linking = false) {
  const std::string target = threads ? "wasm32-wasip1-threads" : "wasm32-wasip1";
  auto arguments = std::vector<std::string>{
      (sdk / "bin" / (cpp ? "clang++" : "clang")).string(),
      cpp ? "--driver-mode=g++" : "--driver-mode=gcc",
      "--no-default-config", threads ? "--target=wasm32-unknown-wasip1-threads" :
                                       "--target=wasm32-unknown-wasip1",
      "--sysroot=" + (sdk / "share/wasi-sysroot").string(),
      "-resource-dir", (sdk / "lib/clang/22").string(),
      "-fwasm-exceptions", "-fno-color-diagnostics",
      "-D_WASI_EMULATED_PROCESS_CLOCKS",
  };
  if (threads) arguments.push_back("-pthread");
  // SDK 33's EH resources use a layout newer than vanilla LLVM 22's driver.
  if (cpp && !linking) {
    arguments.insert(arguments.end(), {
        "-nostdinc++", "-isystem",
        (sdk / "share/wasi-sysroot/include" / target / "eh/c++/v1").string(),
    });
  }
  if (linking) {
    arguments.insert(arguments.end(), {
        "-L", (sdk / "share/wasi-sysroot/lib" / target / "eh").string(),
        "-Wl,--max-memory=" + std::to_string(QFLI_WASM_MAX_MEMORY_BYTES),
    });
    if (threads) {
      arguments.insert(arguments.end(), {"-Wl,--import-memory", "-Wl,--export=wasi_thread_start"});
    }
  }
  return arguments;
}
} // namespace

qfli_compiler_session *qfli_compiler_create(void) {
  return new (std::nothrow) qfli_compiler_session;
}

int qfli_compiler_set_threads(qfli_compiler_session *session, int enabled) {
  if (!session || session->used.load()) return 0;
  session->threads = enabled != 0;
  return 1;
}

int qfli_compiler_compile(qfli_compiler_session *session, const char *sdk_root,
                          const char *project_path, const char *output_directory,
                          const char *const *sources, size_t source_count,
                          int diagnostic_fd) {
  if (!session || !sdk_root || !project_path || !output_directory ||
      !sources || !source_count || session->used.exchange(true)) return 127;
  llvm::raw_fd_ostream diagnostics(diagnostic_fd, false);
  try {
    // Driver/LLVM option registries and LLD state belong to the bundled compiler.
    std::unique_lock<std::mutex> lock(compiler_mutex, std::defer_lock);
    while (!lock.try_lock()) {
      check_cancel(*session);
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    const fs::path sdk(sdk_root), project(project_path), output(output_directory);
    if (!output.is_absolute()) {
      diagnostics << "Missing absolute output directory.\n";
      return 127;
    }
    ModuleOutput module{output / "program.pending.wasm", output / "program.wasm"};
    fs::remove(module.published);
    check_cancel(*session);
    std::call_once(initialized, [&] {
      llvm::InitializeAllTargetInfos();
      llvm::InitializeAllTargets();
      llvm::InitializeAllTargetMCs();
      llvm::InitializeAllAsmParsers();
      llvm::InitializeAllAsmPrinters();
    });
    check_cancel(*session);
    if (!sdk.is_absolute() || !project.is_absolute() || !output.is_absolute() ||
        !fs::is_directory(project) ||
        !fs::is_regular_file(sdk / "share/wasi-sysroot/lib" /
            (session->threads ? "wasm32-wasip1-threads" : "wasm32-wasip1") / "eh/libunwind.a") ||
        !fs::is_directory(sdk / "lib/clang/22/include")) {
      diagnostics << "Missing absolute project paths or WASI SDK 33 resources.\n";
      return 127;
    }
    fs::create_directories(output);
    bool uses_cpp = false;
    std::vector<std::string> objects;
    for (size_t index = 0; index < source_count; ++index) {
      check_cancel(*session);
      if (!sources[index]) return 127;
      const fs::path source(sources[index]);
      if (!source.is_absolute() || !fs::is_regular_file(source)) {
        diagnostics << "Missing absolute source path.\n";
        return 127;
      }
      auto extension = source.extension().string();
      std::transform(extension.begin(), extension.end(), extension.begin(),
                     [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
      if (extension != ".c" && extension != ".cpp" && extension != ".cc" &&
          extension != ".cxx") {
        diagnostics << "Unsupported translation unit extension.\n";
        return 127;
      }
      const bool cpp = extension != ".c";
      uses_cpp = uses_cpp || cpp;
      const auto object = (output / ("unit_" + std::to_string(index) + ".o")).string();
      auto args = base_arguments(sdk, cpp, session->threads);
      args.insert(args.end(), {"-x", cpp ? "c++" : "c", cpp ? "-std=c++20" : "-std=c17",
                                "-I", project.string(), "-I", (project / "include").string(),
                                "-c", source.string(), "-o", object});
      const int code = execute(*session, std::move(args), diagnostics, false);
      if (code) return code;
      objects.push_back(object);
    }
    auto args = base_arguments(sdk, uses_cpp, session->threads, true);
    args.insert(args.end(), objects.begin(), objects.end());
    args.insert(args.end(), {"-lunwind", "-lsetjmp", "-lwasi-emulated-process-clocks",
                             "-lm", "-o", module.pending.string()});
    const int code = execute(*session, std::move(args), diagnostics, true);
    if (code) return code;
    check_cancel(*session);
    fs::rename(module.pending, module.published);
    check_cancel(*session);
    module.complete = true;
    return 0;
  } catch (const Cancelled &) {
    return kCancelled;
  } catch (const std::exception &error) {
    diagnostics << error.what() << '\n';
    return session->cancelled.load() ? kCancelled : 127;
  } catch (...) {
    diagnostics << "Unknown native compiler error.\n";
    return session->cancelled.load() ? kCancelled : 127;
  }
}

void qfli_compiler_cancel(qfli_compiler_session *session) {
  if (session) session->cancelled.store(true);
}

void qfli_compiler_destroy(qfli_compiler_session *session) { delete session; }

#include "compiler_analysis.inc"
