// OHOS C/C++: signed in-process Clang -> WASI data -> signed interpreter.
// No subprocesses, generated native code, JIT, or process-wide stdio changes.
#include "napi/native_api.h"
#include "../../../../../native/compiler/include/qfli_compiler.h"
#include "../../../../../native/compiler/include/qfli_code_analysis.h"
#include "../../../../../native/portable/include/qfli_wasm.h"

#include <atomic>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <mutex>
#include <new>
#include <set>
#include <string>
#include <system_error>
#include <thread>
#include <utility>
#include <vector>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {
std::string Join(const std::string &base, const std::string &part) {
    return base + (base.empty() || base.back() != '/' ? "/" : "") + part;
}

bool ResolvePath(const std::string &path, std::string *resolved) {
    if (path.empty() || path.front() != '/' || path.find('\0') != std::string::npos) return false;
    char *canonical = realpath(path.c_str(), nullptr);
    if (canonical == nullptr) return false;
    resolved->assign(canonical);
    free(canonical);
    return true;
}

bool IsRegular(const std::string &path) {
    struct stat info;
    return stat(path.c_str(), &info) == 0 && S_ISREG(info.st_mode) && access(path.c_str(), R_OK) == 0;
}

bool IsSource(const std::string &path) {
    const size_t dot = path.find_last_of('.');
    if (dot == std::string::npos) return false;
    std::string extension = path.substr(dot);
    for (char &character : extension) character = static_cast<char>(tolower(static_cast<unsigned char>(character)));
    return extension == ".c" || extension == ".cpp" || extension == ".cc" || extension == ".cxx";
}

bool ValidateSources(std::string *project, std::string *entry, std::vector<std::string> *sources) {
    struct stat info;
    if (!ResolvePath(*project, project) || stat(project->c_str(), &info) != 0 ||
        !S_ISDIR(info.st_mode) || access(project->c_str(), R_OK | X_OK) != 0 ||
        !ResolvePath(*entry, entry) || !IsSource(*entry) || sources->empty()) return false;
    const std::string prefix = Join(*project, "");
    bool includesEntry = false;
    std::set<std::string> unique;
    for (std::string &source : *sources) {
        if (!ResolvePath(source, &source) || !IsSource(source) ||
            source.compare(0, prefix.size(), prefix) != 0 || !IsRegular(source) ||
            !unique.insert(source).second) return false;
        includesEntry = includesEntry || source == *entry;
    }
    return includesEntry;
}

// Do not follow program-created symlinks while removing the private run tree.
void RemoveTreeAt(int parent, const char *name) {
    const int descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    DIR *directory = descriptor < 0 ? nullptr : fdopendir(descriptor);
    if (directory != nullptr) {
        while (struct dirent *entry = readdir(directory)) {
            if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
            RemoveTreeAt(dirfd(directory), entry->d_name);
        }
        closedir(directory);
        (void)unlinkat(parent, name, AT_REMOVEDIR);
    } else {
        if (descriptor >= 0) close(descriptor);
        (void)unlinkat(parent, name, 0);
    }
}

struct OwnedFd {
    int value = -1;
    OwnedFd() = default;
    explicit OwnedFd(int descriptor) : value(descriptor) {}
    OwnedFd(const OwnedFd &) = delete;
    OwnedFd &operator=(const OwnedFd &) = delete;
    ~OwnedFd() { Reset(); }
    void Reset(int descriptor = -1) {
        if (value >= 0) close(value);
        value = descriptor;
    }
};

struct Pipe {
    OwnedFd reader;
    OwnedFd writer;
    Pipe() {
        int descriptors[2];
        if (pipe2(descriptors, O_CLOEXEC) != 0) throw std::system_error(errno, std::generic_category(), "Cannot create output pipe");
        reader.value = descriptors[0];
        writer.value = descriptors[1];
    }
};

struct RunState {
    napi_threadsafe_function events = nullptr;
    std::string sdkRoot;
    std::string project;
    std::string entry;
    std::vector<std::string> sources;
    bool analyzing = false;
    bool analysisCpp = false;
    std::vector<std::string> analysisText;
    std::string cache;
    bool accepted = false; // JS-thread owned; never reopened after acceptance.
    std::atomic<bool> cancelled{false};
    std::mutex sessionMutex;
    qfli_compiler_session *compiler = nullptr;
    qfli_wasm_session *runtime = nullptr;
    std::string pending[2]; // One reader owns each stream, then the joined worker.
    ~RunState() {
        if (events != nullptr) napi_release_threadsafe_function(events, napi_tsfn_release);
    }
};

struct RunHandle { std::shared_ptr<RunState> state; };

void RequestCancel(RunState *state) {
    if (state == nullptr) return;
    state->cancelled.store(true);
    std::lock_guard<std::mutex> lock(state->sessionMutex);
    qfli_compiler_cancel(state->compiler);
    qfli_wasm_cancel(state->runtime);
}

void DestroySessions(RunState *state) {
    // Both API calls have returned. Holding the lock excludes concurrent cancel.
    std::lock_guard<std::mutex> lock(state->sessionMutex);
    qfli_compiler_destroy(state->compiler);
    state->compiler = nullptr;
    qfli_wasm_destroy(state->runtime);
    state->runtime = nullptr;
}

struct EventPayload {
    bool isExit = false;
    bool isError = false;
    int exitCode = 0;
    std::string text;
};

void CallJsEvent(napi_env env, napi_value callback, void *, void *data) {
    std::unique_ptr<EventPayload> payload(static_cast<EventPayload *>(data));
    if (env == nullptr || callback == nullptr) return;
    napi_value event = nullptr, kind = nullptr, value = nullptr, receiver = nullptr;
    if (napi_create_object(env, &event) != napi_ok) return;
    const char *kindText = payload->isExit ? "exit" : (payload->isError ? "stderr" : "stdout");
    if (napi_create_string_utf8(env, kindText, NAPI_AUTO_LENGTH, &kind) != napi_ok ||
        napi_set_named_property(env, event, "kind", kind) != napi_ok) return;
    if (payload->isExit) {
        if (napi_create_int32(env, payload->exitCode, &value) != napi_ok ||
            napi_set_named_property(env, event, "exitCode", value) != napi_ok) return;
    } else {
        if (napi_create_string_utf8(env, payload->text.data(), payload->text.size(), &value) != napi_ok ||
            napi_set_named_property(env, event, "text", value) != napi_ok) return;
    }
    if (napi_get_undefined(env, &receiver) == napi_ok) napi_call_function(env, receiver, callback, 1, &event, nullptr);
}

void EmitEvent(RunState *state, std::unique_ptr<EventPayload> payload) {
    if (state->events != nullptr &&
        napi_call_threadsafe_function(state->events, payload.get(), napi_tsfn_nonblocking) == napi_ok) {
        payload.release();
    } else {
        RequestCancel(state);
    }
}

size_t CompleteUtf8Length(const std::string &text) {
    if (text.empty()) return 0;
    size_t start = text.size() - 1;
    while (start > 0 && (static_cast<unsigned char>(text[start]) & 0xc0) == 0x80) --start;
    const unsigned char lead = static_cast<unsigned char>(text[start]);
    const size_t expected = lead >= 0xc2 && lead <= 0xdf ? 2 :
        (lead >= 0xe0 && lead <= 0xef ? 3 : (lead >= 0xf0 && lead <= 0xf4 ? 4 : 1));
    return text.size() - start < expected ? start : text.size();
}

void OnOutput(RunState *state, bool error, const char *text, size_t length) {
    std::string &pending = state->pending[error ? 1 : 0];
    pending.append(text, length);
    const size_t complete = CompleteUtf8Length(pending);
    if (complete == 0) return;
    auto payload = std::make_unique<EventPayload>();
    payload->isError = error;
    payload->text.assign(pending, 0, complete);
    pending.erase(0, complete);
    EmitEvent(state, std::move(payload));
}

void DrainPipe(RunState *state, int descriptor, bool error) noexcept {
    bool discard = false;
    char buffer[8192];
    for (;;) {
        const ssize_t length = read(descriptor, buffer, sizeof(buffer));
        if (length < 0 && errno == EINTR) continue;
        if (length <= 0) {
            if (length < 0) RequestCancel(state);
            return;
        }
        if (discard) continue;
        try {
            OnOutput(state, error, buffer, static_cast<size_t>(length));
        } catch (...) {
            // Continue draining until the compiler/interpreter joins, so a
            // failed consumer cannot deadlock a writer or trigger SIGPIPE.
            discard = true;
            RequestCancel(state);
        }
    }
}

void WriteDiagnostic(int descriptor, const std::string &message) {
    size_t offset = 0;
    while (offset < message.size()) {
        const ssize_t count = write(descriptor, message.data() + offset, message.size() - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return;
        offset += static_cast<size_t>(count);
    }
}

void ReportFailure(RunState *state, int descriptor, bool readerStarted, const char *message) noexcept {
    try {
        if (readerStarted) {
            WriteDiagnostic(descriptor, std::string("Forge: ") + message + "\n");
        } else {
            OnOutput(state, true, message, strlen(message));
            OnOutput(state, true, "\n", 1);
        }
    } catch (...) {
        RequestCancel(state);
    }
}

int Execute(RunState *state, const std::string &directory) {
    if (state->cancelled.load()) return 130;
    Pipe output, errors;
    std::thread outputReader, errorReader;
    OwnedFd input;
    int code = 127;
    try {
        outputReader = std::thread(DrainPipe, state, output.reader.value, false);
        errorReader = std::thread(DrainPipe, state, errors.reader.value, true);
        {
            std::lock_guard<std::mutex> lock(state->sessionMutex);
            state->compiler = qfli_compiler_create();
            qfli_compiler_set_threads(state->compiler, 1);
            if (state->cancelled.load()) qfli_compiler_cancel(state->compiler);
        }
        if (state->compiler != nullptr && state->analyzing) {
            std::vector<qfli_source_snapshot> snapshots;
            for (size_t index = 0; index < state->sources.size(); ++index) {
                snapshots.push_back({state->sources[index].c_str(),
                    state->analysisText[index].data(), state->analysisText[index].size()});
            }
            code = qfli_compiler_analyze(state->compiler, state->sdkRoot.c_str(),
                state->project.c_str(), state->entry.c_str(), state->analysisCpp,
                snapshots.data(), snapshots.size(), output.writer.value, errors.writer.value);
        } else if (state->compiler != nullptr) {
            std::vector<const char *> sources;
            for (const std::string &source : state->sources) sources.push_back(source.c_str());
            code = qfli_compiler_compile(state->compiler, state->sdkRoot.c_str(), state->project.c_str(),
                directory.c_str(), sources.data(), sources.size(), errors.writer.value);
        } else {
            WriteDiagnostic(errors.writer.value, "Forge: cannot create compiler session\n");
        }
        DestroySessions(state);
        if (code == 0 && !state->analyzing && !state->cancelled.load()) {
            input.Reset(open(Join(state->project, "input.txt").c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK));
            const bool missingInput = input.value < 0 && errno == ENOENT;
            if (missingInput) input.Reset(open("/dev/null", O_RDONLY | O_CLOEXEC));
            struct stat info;
            if (input.value < 0 || fstat(input.value, &info) != 0 ||
                (!S_ISREG(info.st_mode) && !(missingInput && S_ISCHR(info.st_mode)))) {
                WriteDiagnostic(errors.writer.value, "Forge: input.txt must be a readable regular file\n");
                code = 127;
            } else {
                {
                    std::lock_guard<std::mutex> lock(state->sessionMutex);
                    state->runtime = qfli_wasm_create();
                    if (state->cancelled.load()) qfli_wasm_cancel(state->runtime);
                }
                if (state->runtime != nullptr) {
                    code = qfli_wasm_run(state->runtime, Join(directory, "program.wasm").c_str(),
                        state->project.c_str(), input.value, output.writer.value, errors.writer.value, 0);
                    const char *message = qfli_wasm_error(state->runtime);
                    if (message != nullptr && *message && !state->cancelled.load()) {
                        WriteDiagnostic(errors.writer.value, std::string("Forge: ") + message + "\n");
                    }
                } else {
                    WriteDiagnostic(errors.writer.value, "Forge: cannot create interpreter session\n");
                    code = 127;
                }
            }
        }
    } catch (const std::exception &error) {
        ReportFailure(state, errors.writer.value, errorReader.joinable(), error.what());
        code = 127;
    } catch (...) {
        ReportFailure(state, errors.writer.value, errorReader.joinable(), "Unknown compiler/interpreter error");
        code = 127;
    }
    DestroySessions(state);
    input.Reset();
    output.writer.Reset();
    errors.writer.Reset();
    if (outputReader.joinable()) outputReader.join();
    if (errorReader.joinable()) errorReader.join();
    return state->cancelled.load() ? 130 : code;
}

void RunOnWorker(std::shared_ptr<RunState> state) {
    int code = 127;
    std::string directory;
    try {
        const std::string pattern = Join(state->cache, "qfli-wasi-XXXXXX");
        std::vector<char> buffer(pattern.begin(), pattern.end());
        buffer.push_back('\0');
        if (mkdtemp(buffer.data()) == nullptr) throw std::system_error(errno, std::generic_category(), "Cannot create compiler temporary directory");
        directory = buffer.data();
        code = Execute(state.get(), directory);
    } catch (const std::exception &error) {
        ReportFailure(state.get(), -1, false, error.what());
    } catch (...) {
        ReportFailure(state.get(), -1, false, "Portable runtime failed unexpectedly");
    }
    DestroySessions(state.get());
    if (!directory.empty()) RemoveTreeAt(AT_FDCWD, directory.c_str());
    try {
        for (int index = 0; index < 2; ++index) {
            if (state->pending[index].empty()) continue;
            auto tail = std::make_unique<EventPayload>();
            tail->isError = index == 1;
            tail->text.swap(state->pending[index]);
            EmitEvent(state.get(), std::move(tail));
        }
    } catch (...) {
        RequestCancel(state.get());
    }
    std::unique_ptr<EventPayload> terminal(new (std::nothrow) EventPayload());
    if (terminal) {
        terminal->isExit = true;
        terminal->exitCode = state->cancelled.load() ? 130 : code;
        EmitEvent(state.get(), std::move(terminal));
    }
    napi_release_threadsafe_function(state->events, napi_tsfn_release);
    state->events = nullptr;
}

bool ReadString(napi_env env, napi_value value, std::string *output, size_t maximum = 16 * 1024 * 1024) {
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok || type != napi_string) return false;
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok || length > maximum) return false;
    std::vector<char> buffer(length + 1);
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &length) != napi_ok) return false;
    output->assign(buffer.data(), length);
    return output->find('\0') == std::string::npos;
}

napi_value Boolean(napi_env env, bool value) {
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

bool InitFailure(napi_env env, const std::string &message) {
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok || !pending) {
        napi_throw_error(env, "QFLI_NATIVE_INIT", message.c_str());
    }
    return false;
}

void FinalizeHandle(napi_env, void *data, void *) {
    auto *handle = static_cast<RunHandle *>(data);
    RequestCancel(handle->state.get());
    delete handle;
}

std::shared_ptr<RunState> ReadHandle(napi_env env, napi_value value) {
    void *raw = nullptr;
    if (napi_get_value_external(env, value, &raw) != napi_ok || raw == nullptr) return nullptr;
    return static_cast<RunHandle *>(raw)->state;
}

napi_value Create(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr}, root = nullptr, callback = nullptr;
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc != 1 ||
        napi_get_named_property(env, args[0], "toolchainRoot", &root) != napi_ok ||
        napi_get_named_property(env, args[0], "onEvent", &callback) != napi_ok) {
        InitFailure(env, "Forge: create requires toolchainRoot and onEvent");
        return nullptr;
    }
    auto state = std::make_shared<RunState>();
    napi_valuetype type = napi_undefined;
    if (!ReadString(env, root, &state->sdkRoot) || !ResolvePath(state->sdkRoot, &state->sdkRoot) ||
        napi_typeof(env, callback, &type) != napi_ok || type != napi_function) {
        InitFailure(env, "Forge: toolchainRoot must be an absolute WASI SDK path and onEvent must be a function");
        return nullptr;
    }
    for (const char *relative : {
        "toolchain.json", "share/wasi-sysroot/include/wasm32-wasip1/stdio.h",
        "share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/vector",
        "share/wasi-sysroot/lib/wasm32-wasip1/libc.a",
        "share/wasi-sysroot/lib/wasm32-wasip1/libsetjmp.a",
        "share/wasi-sysroot/lib/wasm32-wasip1/libwasi-emulated-process-clocks.a",
        "share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++.a",
        "share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++abi.a",
        "share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a",
        "share/wasi-sysroot/include/wasm32-wasip1-threads/pthread.h",
        "share/wasi-sysroot/include/wasm32-wasip1-threads/eh/c++/v1/vector",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/libc.a",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/libsetjmp.a",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/libwasi-emulated-process-clocks.a",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++.a",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++abi.a",
        "share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libunwind.a",
        "lib/clang/22/include/stddef.h",
        "lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a",
        "lib/clang/22/lib/wasm32-unknown-wasip1-threads/libclang_rt.builtins.a",
    }) {
        if (!IsRegular(Join(state->sdkRoot, relative))) {
            InitFailure(env, "Forge: missing readable WASI SDK resource '" + Join(state->sdkRoot, relative) + "'");
            return nullptr;
        }
    }
    napi_value name = nullptr;
    if (napi_create_string_utf8(env, "qfli_ohos_portable_events", NAPI_AUTO_LENGTH, &name) != napi_ok ||
        napi_create_threadsafe_function(env, callback, nullptr, name, 0, 1, nullptr, nullptr,
            nullptr, CallJsEvent, &state->events) != napi_ok) {
        InitFailure(env, "Forge: cannot create portable runtime event callback");
        return nullptr;
    }
    auto handle = std::make_unique<RunHandle>();
    handle->state = state;
    napi_value external = nullptr;
    if (napi_create_external(env, handle.get(), FinalizeHandle, nullptr, &external) != napi_ok) {
        InitFailure(env, "Forge: cannot create portable runtime handle");
        return nullptr;
    }
    handle.release();
    return external;
}

napi_value Run(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5] = {nullptr, nullptr, nullptr, nullptr, nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc != 5) return Boolean(env, false);
    auto state = ReadHandle(env, args[0]);
    if (state == nullptr || state->accepted) return Boolean(env, false);
    std::string project, entry, cache;
    if (!ReadString(env, args[1], &project) || !ReadString(env, args[2], &entry) ||
        !ReadString(env, args[4], &cache) || !ResolvePath(cache, &cache)) return Boolean(env, false);
    bool array = false;
    uint32_t length = 0;
    if (napi_is_array(env, args[3], &array) != napi_ok || !array ||
        napi_get_array_length(env, args[3], &length) != napi_ok || length == 0) return Boolean(env, false);
    std::vector<std::string> sources;
    for (uint32_t index = 0; index < length; ++index) {
        napi_value value = nullptr;
        std::string source;
        if (napi_get_element(env, args[3], index, &value) != napi_ok || !ReadString(env, value, &source)) return Boolean(env, false);
        sources.push_back(std::move(source));
    }
    struct stat cacheInfo;
    if (!ValidateSources(&project, &entry, &sources) || stat(cache.c_str(), &cacheInfo) != 0 ||
        !S_ISDIR(cacheInfo.st_mode) || access(cache.c_str(), W_OK | X_OK) != 0) return Boolean(env, false);
    state->project = std::move(project);
    state->entry = std::move(entry);
    state->cache = std::move(cache);
    state->sources = std::move(sources);
    state->accepted = true;
    try {
        std::thread(RunOnWorker, state).detach();
    } catch (const std::exception &) {
        state->accepted = false;
        return Boolean(env, false);
    }
    return Boolean(env, true);
}

napi_value Analyze(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value args[6] = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc != 6) return Boolean(env, false);
    auto state = ReadHandle(env, args[0]);
    if (state == nullptr || state->accepted) return Boolean(env, false);
    std::string project, active, cache;
    bool cpp = false, array = false;
    uint32_t length = 0;
    if (!ReadString(env, args[1], &project, 16384) || !ResolvePath(project, &project) ||
        !ReadString(env, args[2], &active, 16384) || active.empty() || active.front() != '/' ||
        !ReadString(env, args[5], &cache, 16384) || !ResolvePath(cache, &cache) ||
        napi_get_value_bool(env, args[3], &cpp) != napi_ok ||
        napi_is_array(env, args[4], &array) != napi_ok || !array ||
        napi_get_array_length(env, args[4], &length) != napi_ok || length == 0 || length > 64) return Boolean(env, false);
    std::vector<std::string> paths, texts;
    size_t bytes = 0;
    for (uint32_t index = 0; index < length; ++index) {
        napi_value document = nullptr, pathValue = nullptr, textValue = nullptr;
        std::string path, text;
        if (napi_get_element(env, args[4], index, &document) != napi_ok ||
            napi_get_named_property(env, document, "path", &pathValue) != napi_ok ||
            napi_get_named_property(env, document, "text", &textValue) != napi_ok ||
            !ReadString(env, pathValue, &path, 16384) || path.empty() || path.front() != '/' ||
            !ReadString(env, textValue, &text, 16 * 1024 * 1024 - bytes)) return Boolean(env, false);
        bytes += text.size();
        paths.push_back(std::move(path));
        texts.push_back(std::move(text));
    }
    state->analyzing = true;
    state->analysisCpp = cpp;
    state->project = std::move(project);
    state->entry = std::move(active);
    state->sources = std::move(paths);
    state->analysisText = std::move(texts);
    state->cache = std::move(cache);
    state->accepted = true;
    try {
        std::thread(RunOnWorker, state).detach();
    } catch (const std::exception &) {
        state->accepted = false;
        return Boolean(env, false);
    }
    return Boolean(env, true);
}

napi_value Cancel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) == napi_ok && argc == 1) {
        RequestCancel(ReadHandle(env, args[0]).get());
    }
    return nullptr;
}

napi_value Destroy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    void *raw = nullptr;
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) == napi_ok && argc == 1 &&
        napi_get_value_external(env, args[0], &raw) == napi_ok && raw != nullptr) {
        auto *handle = static_cast<RunHandle *>(raw);
        RequestCancel(handle->state.get());
        handle->state.reset();
    }
    return nullptr;
}
} // namespace

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"create", nullptr, Create, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"analyze", nullptr, Analyze, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cancel", nullptr, Cancel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroy", nullptr, Destroy, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
    return exports;
}

static napi_module qfliOhosPortableModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "qfli_ohos_runner",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterQfliOhosPortableModule(void) {
    napi_module_register(&qfliOhosPortableModule);
}
