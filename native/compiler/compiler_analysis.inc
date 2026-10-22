// Included by compiler.cpp so analysis shares the existing compiler/LLVM lock
// and session cancellation state. It deliberately has no code-generation path.
#include "include/qfli_code_analysis.h"
#include <clang/Basic/SourceManager.h>
#include <clang/Frontend/FrontendActions.h>
#include <clang/Lex/Lexer.h>
#include <clang/Lex/PPCallbacks.h>
#include <llvm/Support/JSON.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/VirtualFileSystem.h>
#include <map>
#include <set>

namespace {
bool analysis_within(const fs::path &candidate, const fs::path &root) {
  auto part = candidate.begin();
  for (const auto &component : root) {
    if (part == candidate.end() || *part++ != component) return false;
  }
  return part != candidate.end();
}

// Resolve before overlay lookup: an in-project symlink must read the canonical
// unsaved buffer, not fall through to its older contents on the real filesystem.
// Only this wrapper is exposed to Clang. All delegated paths are absolute and
// physically confined, and its cwd never propagates to the process filesystem.
class AnalysisFileSystem final : public llvm::vfs::ProxyFileSystem {
public:
  AnalysisFileSystem(llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> underlying,
                     std::vector<fs::path> roots, const fs::path &project)
      : ProxyFileSystem(std::move(underlying)), roots(std::move(roots)),
        workingDirectory(project.string()) {}

  llvm::ErrorOr<llvm::vfs::Status> status(const llvm::Twine &requested) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    return getUnderlyingFS().status(path);
  }

  llvm::ErrorOr<std::unique_ptr<llvm::vfs::File>>
  openFileForRead(const llvm::Twine &requested) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    return getUnderlyingFS().openFileForRead(path);
  }

  llvm::ErrorOr<std::unique_ptr<llvm::vfs::File>>
  openFileForReadBinary(const llvm::Twine &requested) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    return getUnderlyingFS().openFileForReadBinary(path);
  }

  bool exists(const llvm::Twine &requested) override {
    return static_cast<bool>(status(requested));
  }

  llvm::vfs::directory_iterator dir_begin(const llvm::Twine &requested,
                                         std::error_code &error) override {
    std::string path;
    error = resolve(requested, path);
    if (error) return {};
    return getUnderlyingFS().dir_begin(path, error);
  }

  llvm::ErrorOr<std::string> getCurrentWorkingDirectory() const override {
    return workingDirectory;
  }

  std::error_code setCurrentWorkingDirectory(const llvm::Twine &requested) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    auto entry = getUnderlyingFS().status(path);
    if (!entry) return entry.getError();
    if (!entry->isDirectory()) return std::make_error_code(std::errc::not_a_directory);
    workingDirectory = path;
    return {};
  }

  std::error_code getRealPath(const llvm::Twine &requested,
                              llvm::SmallVectorImpl<char> &output) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    if (!getUnderlyingFS().exists(path)) {
      return std::make_error_code(std::errc::no_such_file_or_directory);
    }
    output.assign(path.begin(), path.end());
    return {};
  }

  std::error_code isLocal(const llvm::Twine &requested, bool &result) override {
    std::string path;
    if (auto error = resolve(requested, path)) return error;
    return getUnderlyingFS().isLocal(path, result);
  }

private:
  std::error_code resolve(const llvm::Twine &requested, std::string &result) const {
    const auto spelling = requested.str();
    if (spelling.find('\0') != std::string::npos) {
      return std::make_error_code(std::errc::invalid_argument);
    }
    fs::path path(spelling);
    if (!path.is_absolute()) path = fs::path(workingDirectory) / path;
    std::error_code error;
    path = fs::weakly_canonical(path, error);
    if (error) return error;
    for (const auto &root : roots) {
      if (path == root || analysis_within(path, root)) {
        result = path.string();
        return {};
      }
    }
    return std::make_error_code(std::errc::permission_denied);
  }

  std::vector<fs::path> roots;
  std::string workingDirectory;
};

std::string analysis_extension(const std::string &path) {
  auto extension = fs::path(path).extension().string();
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return extension;
}

bool analysis_source(const std::string &extension) {
  return extension == ".c" || extension == ".cpp" || extension == ".cc" ||
         extension == ".cxx";
}

struct AnalysisDocument {
  std::string original;
  size_t length;
};

class AnalysisDiagnostics final : public clang::DiagnosticConsumer {
public:
  const clang::LangOptions *language = nullptr;
  std::map<std::string, AnalysisDocument> documents;
  llvm::json::Array entries;
  std::set<std::string> enteredFiles;
  bool unmappedErrors = false;

  void HandleDiagnostic(clang::DiagnosticsEngine::Level level,
                        const clang::Diagnostic &info) override {
    clang::DiagnosticConsumer::HandleDiagnostic(level, info);
    if (level == clang::DiagnosticsEngine::Ignored ||
        level == clang::DiagnosticsEngine::Remark) return;
    const bool error = level >= clang::DiagnosticsEngine::Error;
    if (!info.hasSourceManager() || info.getLocation().isInvalid()) {
      unmappedErrors = unmappedErrors || error;
      return;
    }
    const auto &manager = info.getSourceManager();
    const auto location = manager.getExpansionLoc(info.getLocation());
    std::error_code pathError;
    const auto path = fs::weakly_canonical(
        manager.getFilename(location).str(), pathError).string();
    const auto document = documents.find(path);
    if (pathError || document == documents.end() || !language) {
      unmappedErrors = unmappedErrors || error;
      return;
    }
    size_t begin = manager.getFileOffset(location);
    size_t end = begin + clang::Lexer::MeasureTokenLength(location, manager, *language);
    for (const auto &range : info.getRanges()) {
      auto first = manager.getExpansionLoc(range.getBegin());
      auto last = manager.getExpansionLoc(range.getEnd());
      if (first.isInvalid() || last.isInvalid() ||
          manager.getFileID(first) != manager.getFileID(location) ||
          manager.getFileID(last) != manager.getFileID(location)) continue;
      if (range.isTokenRange()) {
        last = clang::Lexer::getLocForEndOfToken(last, 0, manager, *language);
      }
      if (last.isInvalid()) continue;
      const size_t rangeBegin = manager.getFileOffset(first);
      const size_t rangeEnd = manager.getFileOffset(last);
      if (rangeBegin <= begin && begin <= rangeEnd) {
        begin = rangeBegin;
        end = rangeEnd;
        break;
      }
    }
    begin = std::min(begin, document->second.length);
    end = std::max(begin, std::min(end, document->second.length));
    llvm::SmallString<256> formatted;
    info.FormatDiagnostic(formatted);
    size_t length = std::min<size_t>(formatted.size(), 4096);
    while (length < formatted.size() && length > 0 &&
           (static_cast<unsigned char>(formatted[length]) & 0xc0) == 0x80) --length;
    const std::string message(formatted.data(), length);
    const std::string identity = path + ':' + std::to_string(begin) + ':' +
        std::to_string(end) + ':' + std::to_string(info.getID()) + ':' + message;
    if (!seen.insert(identity).second) return;
    if (entries.size() >= 1000) {
      unmappedErrors = true;
      return;
    }
    entries.push_back(llvm::json::Object{
        {"filePath", document->second.original},
        {"startByte", static_cast<int64_t>(begin)},
        {"endByte", static_cast<int64_t>(end)},
        {"severity", error ? "error" :
            level == clang::DiagnosticsEngine::Warning ? "warning" : "info"},
        {"message", message}, {"code", std::to_string(info.getID())}});
  }

private:
  std::set<std::string> seen;
};

class AnalysisEnteredFiles final : public clang::PPCallbacks {
public:
  AnalysisEnteredFiles(clang::SourceManager &manager, AnalysisDiagnostics &collector)
      : manager(manager), collector(collector) {}

  void LexedFileChanged(clang::FileID file, LexedFileChangeReason reason,
                        clang::SrcMgr::CharacteristicKind,
                        clang::FileID, clang::SourceLocation) override {
    if (reason != LexedFileChangeReason::EnterFile || file.isInvalid()) return;
    std::error_code error;
    const auto path = fs::weakly_canonical(
        manager.getFilename(manager.getLocForStartOfFile(file)).str(), error).string();
    if (!error && collector.documents.count(path)) collector.enteredFiles.insert(path);
  }

private:
  clang::SourceManager &manager;
  AnalysisDiagnostics &collector;
};

class SyntaxCancellableAction final : public clang::SyntaxOnlyAction {
public:
  SyntaxCancellableAction(qfli_compiler_session &session, AnalysisDiagnostics &collector)
      : session(session), collector(collector) {}
protected:
  bool BeginSourceFileAction(clang::CompilerInstance &compiler) override {
    if (!clang::SyntaxOnlyAction::BeginSourceFileAction(compiler)) return false;
    compiler.getPreprocessor().addPPCallbacks(std::make_unique<AnalysisEnteredFiles>(
        compiler.getSourceManager(), collector));
    compiler.getPreprocessor().setTokenWatcher(
        [this](const clang::Token &) { check_cancel(session); });
    return true;
  }
private:
  qfli_compiler_session &session;
  AnalysisDiagnostics &collector;
};

int analyze_document(qfli_compiler_session &session, const fs::path &sdk,
                     const fs::path &project, const std::string &source, bool cpp,
                     llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> vfs,
                     AnalysisDiagnostics &collector) {
  auto args = base_arguments(sdk, cpp, session.threads);
  args.insert(args.end(), {"-x", cpp ? "c++" : "c", cpp ? "-std=c++20" : "-std=c17",
      "-I", project.string(), "-I", (project / "include").string(),
      "-fsyntax-only", "-ferror-limit=100", "-Wall", source});
  clang::DiagnosticOptions options;
  auto engine = clang::CompilerInstance::createDiagnostics(*vfs, options, &collector, false);
  clang::driver::Driver driver(args.front(), "wasm32-unknown-wasip1", *engine,
                              "Forge syntax analysis", vfs);
  std::vector<const char *> argv;
  for (const auto &argument : args) argv.push_back(argument.c_str());
  std::unique_ptr<clang::driver::Compilation> compilation(driver.BuildCompilation(argv));
  if (!compilation || engine->hasErrorOccurred() || compilation->getJobs().size() != 1) {
    return 127;
  }
  const auto &job = *compilation->getJobs().begin();
  const auto &arguments = job.getArguments();
  if (arguments.empty() || std::string(arguments.front()) != "-cc1") return 127;
  auto invocation = std::make_shared<clang::CompilerInvocation>();
  if (!clang::CompilerInvocation::CreateFromArgs(
      *invocation, llvm::ArrayRef(arguments).drop_front(), *engine)) return 127;
  if (invocation->getFrontendOpts().ProgramAction != clang::frontend::ParseSyntaxOnly) return 127;
  invocation->getFrontendOpts().DisableFree = false;
  // Diagnostics already have a structured consumer; suppress the text summary
  // that CompilerInstance otherwise sends to its process stderr stream.
  invocation->getDiagnosticOpts().ShowCarets = false;
  clang::CompilerInstance compiler(invocation);
  compiler.setVirtualFileSystem(vfs);
  compiler.createDiagnostics(&collector, false);
  compiler.createFileManager();
  compiler.createSourceManager();
  collector.language = &compiler.getLangOpts();
  SyntaxCancellableAction action(session, collector);
  const bool success = compiler.ExecuteAction(action);
  collector.language = nullptr;
  check_cancel(session);
  return success ? 0 : 1;
}
} // namespace

int qfli_compiler_analyze(qfli_compiler_session *session, const char *sdk_root,
                          const char *project_root, const char *active_file,
                          int active_is_cpp, const qfli_source_snapshot *snapshots,
                          size_t snapshot_count, int output_fd, int diagnostic_fd) {
  if (!session || !sdk_root || !project_root || !active_file || !snapshots ||
      snapshot_count == 0 || snapshot_count > 64 || output_fd < 0 ||
      diagnostic_fd < 0 || session->used.exchange(true)) return 127;
  llvm::raw_fd_ostream errors(diagnostic_fd, false), output(output_fd, false);
  try {
    std::unique_lock<std::mutex> lock(compiler_mutex, std::defer_lock);
    while (!lock.try_lock()) {
      check_cancel(*session);
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    check_cancel(*session);
    const fs::path sdk(sdk_root), root(project_root), active(active_file);
    std::error_code error;
    if (!sdk.is_absolute() || !root.is_absolute() || !active.is_absolute() ||
        !fs::is_directory(root) || !fs::is_directory(sdk / "lib/clang/22/include")) return 127;
    const auto project = fs::canonical(root, error);
    if (error) return 127;
    const auto sdkContainer = fs::canonical(sdk, error);
    if (error) return 127;
    // Packaged SDK fixture roots may be links into a verified SDK installation.
    // Allow exactly their physical resource subtrees, never their broad parents.
    std::vector<fs::path> allowedRoots{project, sdkContainer};
    for (const auto &relative : {"share/wasi-sysroot", "lib/clang/22"}) {
      const auto resource = fs::canonical(sdk / relative, error);
      if (error || !fs::is_directory(resource)) return 127;
      allowedRoots.push_back(resource);
    }
    const auto activePath = fs::weakly_canonical(active, error).string();
    if (error || !analysis_within(activePath, project)) return 127;
    auto memory = llvm::makeIntrusiveRefCnt<llvm::vfs::InMemoryFileSystem>();
    llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> physical(
        llvm::vfs::createPhysicalFileSystem().release());
    auto overlay = llvm::makeIntrusiveRefCnt<llvm::vfs::OverlayFileSystem>(physical);
    overlay->pushOverlay(memory);
    auto confined = llvm::makeIntrusiveRefCnt<AnalysisFileSystem>(
        overlay, std::move(allowedRoots), project);
    AnalysisDiagnostics collector;
    size_t bytes = 0;
    std::vector<std::string> sources;
    for (size_t index = 0; index < snapshot_count; ++index) {
      const auto &snapshot = snapshots[index];
      if (!snapshot.path || !snapshot.text || !fs::path(snapshot.path).is_absolute() ||
          snapshot.length > 16 * 1024 * 1024 - bytes) return 127;
      bytes += snapshot.length;
      const auto path = fs::weakly_canonical(snapshot.path, error).string();
      const auto extension = analysis_extension(path);
      if (error || !analysis_within(path, project) ||
          (!analysis_source(extension) && extension != ".h" &&
           extension != ".hpp" && extension != ".hh" && extension != ".hxx" &&
           extension != ".inl") ||
          !collector.documents.emplace(path,
              AnalysisDocument{snapshot.path, snapshot.length}).second) return 127;
      if (!memory->addFile(path, 0, llvm::MemoryBuffer::getMemBufferCopy(
          llvm::StringRef(snapshot.text, snapshot.length), path))) return 127;
      if (analysis_source(extension)) sources.push_back(path);
    }
    if (!collector.documents.count(activePath)) return 127;
    if (sources.empty()) sources.push_back(activePath);
    int result = 0;
    for (const auto &source : sources) {
      check_cancel(*session);
      const auto extension = analysis_extension(source);
      const bool cpp = analysis_source(extension) ? extension != ".c" : active_is_cpp != 0;
      const int code = analyze_document(*session, sdk, project, source, cpp, confined, collector);
      if (code == 127) return code;
      result = std::max(result, code);
    }
    // Included headers have already been checked in their real TU context.
    // Only disconnected active headers need a standalone parse; rechecking a
    // contextual header independently can otherwise manufacture false errors.
    if (!collector.enteredFiles.count(activePath)) {
      check_cancel(*session);
      const int code = analyze_document(*session, sdk, project, activePath,
          active_is_cpp != 0, confined, collector);
      if (code == 127) return code;
      result = std::max(result, code);
    }
    output << llvm::json::Value(llvm::json::Object{
        {"diagnostics", std::move(collector.entries)},
        {"unmappedErrors", collector.unmappedErrors}}) << '\n';
    return result;
  } catch (const Cancelled &) {
    return 130;
  } catch (const std::exception &error) {
    errors << "Forge syntax analysis: " << error.what() << '\n';
    return session->cancelled.load() ? 130 : 127;
  } catch (...) {
    errors << "Forge syntax analysis failed.\n";
    return session->cancelled.load() ? 130 : 127;
  }
}
