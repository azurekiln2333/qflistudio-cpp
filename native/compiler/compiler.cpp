#include "qfli_compiler.h"
#include "../include/qfli_wasm_limits.h"

#include <clang/Basic/CodeGenOptions.h>
#include <clang/Frontend/FrontendOptions.h>
#include <clang/Basic/Version.h>
#include <clang/CodeGen/CodeGenAction.h>
#include <clang/Driver/Compilation.h>
#include <clang/Driver/Driver.h>
#include <clang/Driver/Job.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/CompilerInvocation.h>
#include <clang/Frontend/FrontendActions.h>
#include <clang/Frontend/TextDiagnosticPrinter.h>
#include <clang/Lex/Preprocessor.h>
#include <lld/Common/Driver.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/Option/OptTable.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/VirtualFileSystem.h>
#include <llvm/Support/raw_ostream.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <system_error>
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
constexpr int kInvalid = 127;
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

// EmitObjAction / EmitAssemblyAction derive from CodeGenAction and need a
// context; the token watcher gives cooperative cancellation while parsing.
template <class Base>
class CodeGenCancellableAction final : public Base {
public:
  CodeGenCancellableAction(llvm::LLVMContext &context, qfli_compiler_session &session)
      : Base(&context), session(session) {}

protected:
  bool BeginSourceFileAction(clang::CompilerInstance &compiler) override {
    if (!Base::BeginSourceFileAction(compiler)) return false;
    compiler.getPreprocessor().setTokenWatcher(
        [this](const clang::Token &) { check_cancel(session); });
    return true;
  }

private:
  qfli_compiler_session &session;
};

class PreprocessCancellableAction final : public clang::PrintPreprocessedAction {
public:
  explicit PreprocessCancellableAction(qfli_compiler_session &session)
      : session(session) {}

protected:
  bool BeginSourceFileAction(clang::CompilerInstance &compiler) override {
    if (!clang::PrintPreprocessedAction::BeginSourceFileAction(compiler)) return false;
    compiler.getPreprocessor().setTokenWatcher(
        [this](const clang::Token &) { check_cancel(session); });
    return true;
  }

private:
  qfli_compiler_session &session;
};

std::unique_ptr<clang::FrontendAction> create_action(
    clang::frontend::ActionKind kind, llvm::LLVMContext &context,
    qfli_compiler_session &session) {
  switch (kind) {
  case clang::frontend::EmitObj:
    return std::make_unique<CodeGenCancellableAction<clang::EmitObjAction>>(context,
                                                                           session);
  case clang::frontend::EmitAssembly:
    return std::make_unique<
        CodeGenCancellableAction<clang::EmitAssemblyAction>>(context, session);
  case clang::frontend::PrintPreprocessedInput:
    return std::make_unique<PreprocessCancellableAction>(session);
  default:
    return nullptr;
  }
}

int execute(qfli_compiler_session &session, std::vector<std::string> arguments,
            llvm::raw_ostream &diagnostics, bool linking,
            clang::frontend::ActionKind kind = clang::frontend::EmitObj) {
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
  auto action = create_action(kind, context, session);
  if (!action) {
    diagnostics << "Unsupported compiler action.\n";
    return 127;
  }
  const bool success = compiler.ExecuteAction(*action);
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

// ---------------------------------------------------------------------------
// qfli_compiler_command support
// ---------------------------------------------------------------------------

bool is_within(const fs::path &candidate, const fs::path &root) {
  auto candidate_part = candidate.begin();
  for (auto root_part = root.begin(); root_part != root.end();
       ++root_part, ++candidate_part) {
    if (candidate_part == candidate.end() || *candidate_part != *root_part) {
      return false;
    }
  }
  return true;
}

// Resolve an operand (possibly relative to the borrowed working directory)
// through symlinks and require the result under the canonical project root.
bool resolve_confined(const fs::path &base, const std::string &operand,
                      const fs::path &project, fs::path &resolved,
                      std::string &error) {
  std::error_code code;
  fs::path candidate(operand);
  if (candidate.is_relative()) candidate = base / candidate;
  resolved = fs::weakly_canonical(candidate, code);
  if (code) {
    error = "Cannot resolve path: " + operand + "\n";
    return false;
  }
  if (!is_within(resolved, project)) {
    error = "Path escapes the project sandbox: " + operand + "\n";
    return false;
  }
  return true;
}

std::string lower_extension(const fs::path &path) {
  auto extension = path.extension().string();
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
  return extension;
}

bool is_translation_unit(const fs::path &path) {
  const auto extension = lower_extension(path);
  return extension == ".c" || extension == ".cpp" || extension == ".cc" ||
         extension == ".cxx";
}

struct CommandSpec {
  bool preprocess = false;
  bool assemble = false;
  bool compile_only = false;
  bool has_output = false;
  fs::path output;
  std::string standard;
  std::vector<std::string> defines;
  std::vector<std::string> includes;   // resolved absolute directories
  std::vector<std::string> extra;      // warnings/`-g` passed through
  std::string optimize;
  std::vector<fs::path> sources;
};

bool parse_command(const fs::path &base, const fs::path &project,
                   const char *const *arguments, size_t count, CommandSpec &spec,
                   std::string &error) {
  for (size_t index = 0; index < count; ++index) {
    const std::string argument = arguments[index] ? arguments[index] : "";
    if (argument.empty()) {
      error = "Empty compiler argument.\n";
      return false;
    }
    if (argument == "-c") {
      spec.compile_only = true;
    } else if (argument == "-E") {
      spec.preprocess = true;
    } else if (argument == "-S") {
      spec.assemble = true;
    } else if (argument == "-o" || argument.rfind("-o", 0) == 0) {
      std::string value = argument == "-o" ? "" : argument.substr(2);
      if (value.empty()) {
        if (index + 1 >= count || !arguments[index + 1]) {
          error = "Missing operand for -o.\n";
          return false;
        }
        value = arguments[++index];
      }
      if (value.empty() || value[0] == '-') {
        error = "Invalid -o operand: " + value + "\n";
        return false;
      }
      if (!resolve_confined(base, value, project, spec.output, error)) return false;
      spec.has_output = true;
    } else if (argument.rfind("-std=", 0) == 0 || argument == "-std") {
      std::string value = argument == "-std" ? "" : argument.substr(5);
      if (value.empty()) {
        if (index + 1 >= count || !arguments[index + 1]) {
          error = "Missing operand for -std.\n";
          return false;
        }
        value = arguments[++index];
      }
      if (value.empty()) {
        error = "Invalid -std operand.\n";
        return false;
      }
      spec.standard = value;
    } else if (argument == "-I" || argument.rfind("-I", 0) == 0) {
      std::string value = argument == "-I" ? "" : argument.substr(2);
      if (value.empty()) {
        if (index + 1 >= count || !arguments[index + 1]) {
          error = "Missing operand for -I.\n";
          return false;
        }
        value = arguments[++index];
      }
      fs::path resolved;
      if (!resolve_confined(base, value, project, resolved, error)) return false;
      spec.includes.push_back(resolved.string());
    } else if (argument == "-D" || argument.rfind("-D", 0) == 0) {
      std::string value = argument == "-D" ? "" : argument.substr(2);
      if (value.empty()) {
        if (index + 1 >= count || !arguments[index + 1]) {
          error = "Missing operand for -D.\n";
          return false;
        }
        value = arguments[++index];
      }
      if (value.empty()) {
        error = "Invalid -D operand.\n";
        return false;
      }
      spec.defines.push_back(value);
    } else if (argument == "-O" || argument.rfind("-O", 0) == 0) {
      if (argument == "-O") {
        spec.optimize = "-O1";
        continue;
      }
      const std::string level = argument.substr(2);
      if (level == "0" || level == "1" || level == "2" || level == "3" ||
          level == "s" || level == "z" || level == "fast") {
        spec.optimize = argument;
      } else {
        error = "Unsupported optimization flag: " + argument + "\n";
        return false;
      }
    } else if (argument == "-pthread" || argument == "-lm") {
      // The OHOS target already enables threads and links the math library.
    } else if (argument == "-g" || argument == "-g0" || argument == "-g1" ||
               argument == "-g2" || argument == "-g3" || argument == "-w" ||
               (argument.rfind("-W", 0) == 0 && argument.find(',') == std::string::npos) ||
               argument == "-pedantic" || argument == "-pedantic-errors") {
      spec.extra.push_back(argument);
    } else if (!argument.empty() && argument[0] == '-') {
      error = "Unsupported compiler flag: " + argument + "\n";
      return false;
    } else {
      fs::path resolved;
      if (!resolve_confined(base, argument, project, resolved, error)) return false;
      if (!is_translation_unit(resolved) && lower_extension(resolved) != ".o" &&
          lower_extension(resolved) != ".a") {
        error = "Unsupported compiler input: " + argument + "\n";
        return false;
      }
      spec.sources.push_back(resolved);
    }
  }
  if (spec.preprocess && spec.compile_only) {
    error = "-E and -c cannot be combined.\n";
    return false;
  }
  if (spec.assemble && spec.compile_only) {
    error = "-S and -c cannot be combined.\n";
    return false;
  }
  if (spec.sources.empty()) {
    error = "No input files.\n";
    return false;
  }
  if (spec.has_output && spec.sources.size() > 1 &&
      (spec.compile_only || spec.assemble || spec.preprocess)) {
    error = "Cannot use -o with multiple inputs in this mode.\n";
    return false;
  }
  for (const auto &input : spec.sources) {
    if (spec.has_output && spec.output == input) {
      error = "Input and output must be different files.\n";
      return false;
    }
    if ((spec.preprocess || spec.assemble || spec.compile_only) &&
        !is_translation_unit(input)) {
      error = "This compilation mode requires a source file.\n";
      return false;
    }
  }
  return true;
}

int run_command(qfli_compiler_session &session, const fs::path &sdk,
                const fs::path &project, const fs::path &base,
                const fs::path &temporary, bool cpp, const CommandSpec &spec,
                llvm::raw_ostream &diagnostics, llvm::raw_ostream &stdout_stream) {
  const bool direct = spec.compile_only || spec.assemble || spec.preprocess;
  const clang::frontend::ActionKind kind = spec.preprocess
                                               ? clang::frontend::PrintPreprocessedInput
                                               : (spec.assemble
                                                      ? clang::frontend::EmitAssembly
                                                      : clang::frontend::EmitObj);
  std::vector<fs::path> objects;
  bool uses_cpp = cpp;

  for (size_t index = 0; index < spec.sources.size(); ++index) {
    check_cancel(session);
    const fs::path &source = spec.sources[index];
    if (!is_translation_unit(source)) {
      objects.push_back(source);
      continue;
    }
    const bool source_cpp = cpp || lower_extension(source) != ".c";
    uses_cpp = uses_cpp || source_cpp;
    auto args = base_arguments(sdk, source_cpp, session.threads, false);
    args.push_back("-x");
    args.push_back(source_cpp ? "c++" : "c");
    args.push_back("-std=" + (spec.standard.empty()
                                  ? (source_cpp ? std::string("c++20")
                                                : std::string("c17"))
                                  : spec.standard));
    args.push_back("-I");
    args.push_back(project.string());
    args.push_back("-I");
    args.push_back((project / "include").string());
    for (const auto &include : spec.includes) {
      args.push_back("-I");
      args.push_back(include);
    }
    for (const auto &define : spec.defines) args.push_back("-D" + define);
    if (!spec.optimize.empty()) args.push_back(spec.optimize);
    for (const auto &extra : spec.extra) args.push_back(extra);

    const fs::path output = temporary / ("unit_" + std::to_string(index));

    const char *mode = spec.preprocess ? "-E" : (spec.assemble ? "-S" : "-c");
    args.push_back(mode);
    args.push_back(source.string());
    args.push_back("-o");
    args.push_back(output.string());
    const int result = execute(session, std::move(args), diagnostics, false, kind);
    if (result) return result;
    check_cancel(session);
    if (!direct) {
      objects.push_back(output);
    } else if (spec.preprocess && !spec.has_output) {
      std::ifstream preprocessed(output, std::ios::binary);
      if (!preprocessed) return kInvalid;
      char buffer[8192];
      while (preprocessed) {
        check_cancel(session);
        preprocessed.read(buffer, sizeof(buffer));
        stdout_stream.write(buffer, preprocessed.gcount());
      }
      if (!preprocessed.eof()) return kInvalid;
    } else {
      const auto destination = spec.has_output ? spec.output :
          base / (source.stem().string() + (spec.assemble ? ".s" : ".o"));
      fs::rename(output, destination);
    }
  }

  if (direct) return 0;

  check_cancel(session);
  const auto output = temporary / "program.pending.wasm";
  auto args = base_arguments(sdk, uses_cpp, session.threads, true);
  for (const auto &object : objects) args.push_back(object.string());
  args.insert(args.end(), {"-lunwind", "-lsetjmp", "-lwasi-emulated-process-clocks",
                           "-lm", "-o", output.string()});
  const int result = execute(session, std::move(args), diagnostics, true);
  if (result) return result;
  check_cancel(session);
  fs::rename(output, spec.has_output ? spec.output : (base / "a.out"));
  return 0;
}

int print_version(const fs::path &sdk, llvm::raw_ostream &output) {
  output << clang::getClangFullVersion() << '\n';
  output << "Target: wasm32-unknown-wasip1\n";
  output << "Thread model: posix\n";
  output << "InstalledDir: " << (sdk / "bin").string() << '\n';
  output.flush();
  return 0;
}

int print_help(const std::string &compiler_name, llvm::raw_ostream &output) {
  clang::DiagnosticOptions options;
  clang::TextDiagnosticPrinter printer(output, options);
  const auto vfs = llvm::vfs::getRealFileSystem();
  auto engine = clang::CompilerInstance::createDiagnostics(*vfs, options,
                                                           &printer, false);
  clang::driver::Driver driver(compiler_name, "wasm32-unknown-wasip1", *engine,
                               "clang LLVM compiler", vfs);
  std::string usage = compiler_name + " [options] file...";
  driver.getOpts().printHelp(output, usage.c_str(), "clang LLVM compiler",
                             /*ShowHidden=*/false, /*ShowAllAliases=*/false);
  output.flush();
  return 0;
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

int qfli_compiler_command(qfli_compiler_session *session, const char *sdk_root,
                          const char *project_root, const char *working_directory,
                          const char *temporary_directory, const char *compiler_name,
                          const char *const *arguments, size_t argument_count,
                          int output_fd, int diagnostic_fd) {
  if (!session || !sdk_root || !project_root || !working_directory ||
      !temporary_directory || !compiler_name || (!arguments && argument_count) ||
      output_fd < 0 || diagnostic_fd < 0 || session->used.exchange(true)) {
    return kInvalid;
  }
  llvm::raw_fd_ostream diagnostics(diagnostic_fd, false);
  llvm::raw_fd_ostream output(output_fd, false);
  try {
    std::unique_lock<std::mutex> lock(compiler_mutex, std::defer_lock);
    while (!lock.try_lock()) {
      check_cancel(*session);
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    const fs::path sdk(sdk_root), project(project_root), working(working_directory),
        temporary(temporary_directory);
    if (!sdk.is_absolute() || !project.is_absolute() || !working.is_absolute() ||
        !temporary.is_absolute()) {
      diagnostics << "All command paths must be absolute.\n";
      return kInvalid;
    }
    std::error_code code;
    const fs::path canonical_project = fs::canonical(project, code);
    if (code || !fs::is_directory(canonical_project)) {
      diagnostics << "Missing project root.\n";
      return kInvalid;
    }
    const fs::path canonical_working = fs::weakly_canonical(working, code);
    if (code || !is_within(canonical_working, canonical_project) ||
        !fs::is_directory(canonical_working)) {
      diagnostics << "Working directory must exist under the project root.\n";
      return kInvalid;
    }
    if (!fs::is_directory(sdk / "lib/clang/22/include")) {
      diagnostics << "Missing WASI SDK 33 resources.\n";
      return kInvalid;
    }
    const std::string name(compiler_name);
    if (name != "clang" && name != "clang++") {
      diagnostics << "Unsupported compiler name: " << name << '\n';
      return kInvalid;
    }
    fs::create_directories(temporary, code);
    if (code || !fs::is_directory(temporary)) {
      diagnostics << "Cannot create temporary directory.\n";
      return kInvalid;
    }

    std::vector<std::string> operands;
    for (size_t index = 0; index < argument_count; ++index) {
      if (!arguments[index]) {
        diagnostics << "Null compiler argument.\n";
        return kInvalid;
      }
      operands.emplace_back(arguments[index]);
    }
    if (operands.empty()) {
      diagnostics << "No compiler arguments.\n";
      return kInvalid;
    }
    if (operands.size() == 1 &&
        (operands[0] == "--version" || operands[0] == "-version" ||
         operands[0] == "-v")) {
      return print_version(sdk, output);
    }
    if (operands.size() == 1 &&
        (operands[0] == "--help" || operands[0] == "-help")) {
      return print_help(name, output);
    }
    if (operands.size() == 1 &&
        (operands[0] == "--help-hidden" || operands[0] == "-help-hidden")) {
      // Hidden help is intentionally unsupported; report honestly.
      diagnostics << "Unsupported compiler flag: " << operands[0] << '\n';
      return kInvalid;
    }

    std::call_once(initialized, [] {
      llvm::InitializeAllTargetInfos();
      llvm::InitializeAllTargets();
      llvm::InitializeAllTargetMCs();
      llvm::InitializeAllAsmParsers();
      llvm::InitializeAllAsmPrinters();
    });
    check_cancel(*session);

    CommandSpec spec;
    std::string error;
    if (!parse_command(canonical_working, canonical_project, arguments,
                       argument_count, spec, error)) {
      diagnostics << error;
      return kInvalid;
    }
    const bool cpp = name == "clang++";
    return run_command(*session, sdk, canonical_project, canonical_working,
                       temporary, cpp, spec, diagnostics, output);
  } catch (const Cancelled &) {
    return kCancelled;
  } catch (const std::exception &exception) {
    diagnostics << exception.what() << '\n';
    return session->cancelled.load() ? kCancelled : kInvalid;
  } catch (...) {
    diagnostics << "Unknown native compiler error.\n";
    return session->cancelled.load() ? kCancelled : kInvalid;
  }
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
