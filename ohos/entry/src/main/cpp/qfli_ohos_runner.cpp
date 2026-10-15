/*
 * OHOS 原生编译运行桥（NAPI）。
 *
 * 职责：把「一组源文件 → 编译 → 链接 → 跑到独立进程 → 流式回传输出」这套流程
 * 暴露给 ArkTS。ArkTS 再通过 qfli_forge/native 通道转给 Dart。
 *
 * 完整链路：
 *
 *   Dart → MethodChannel(qfli_forge/native) → ArkTS → 本模块 → fork/exec → clang / 用户程序
 *
 * 为什么不用 Android 那套共享内存方案：OHOS 的 ArkTS childProcessManager 不支持
 * 在手机上启动任意可执行文件。但 NDK 层的 fork/exec 是可用的，所以这里直接在
 * native 侧 fork，用管道把 stdout/stderr 拉回来。
 *
 * 为什么编译要分两步（每个源文件单独 -c，再统一链接）：多个 .c/.cpp 混编时，
 * 语言模式必须按文件后缀逐个指定；一次性丢给 clang 会让 .c 文件被当成 C++ 编译。
 *
 * 线程模型：编译运行发生在一条后台线程上（不阻塞 ArkTS 主线程），
 * 输出通过 TSFN（线程安全函数）回到 JS 线程再派发事件。
 */
#include "napi/native_api.h"

#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <vector>

#include <dirent.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

namespace {

/* 工具链在 App 私有目录里的相对布局，由 ArkTS 侧解压资源后传入根目录。 */
struct Toolchain {
    std::string root;          /* 解压根目录 */
    std::string compiler;      /* bin/clang */
    std::string linker;        /* bin/ld.lld */
    std::string config;        /* bin/ohos.cfg */
    std::string sysroot;       /* sysroot */
    std::string resourceDir;   /* lib/clang/15.0.7 */
    std::string runtimeDir;    /* lib/aarch64-unknown-linux-ohos */
    std::string executor;      /* libqfli_executor.so 的绝对路径 */
};

std::string Join(const std::string &base, const std::string &part) {
    if (!base.empty() && base.back() == '/') return base + part;
    return base + "/" + part;
}

/*
 * fork + exec，把 stdout/stderr 接到管道上，边读边调 onOutput 回调。
 * 返回子进程退出状态；启动失败返回 125。
 *
 * 关键点：必须用 poll 同时读两个管道。如果先把 stdout 读干净再读 stderr，
 * 一旦子进程先写满 stderr 管道（64KB），它就会阻塞在写 stderr 上，
 * stdout 永远不会关闭，父进程也就永远等不到 EOF —— 死锁。
 */
int RunChild(const std::vector<std::string> &argv,
             const std::string &workDirectory,
             const std::string &inputPath,
             const std::string &ldLibraryPath,
             const std::string &temporaryDirectory,
             int cancelDescriptor,
             bool *cancelled,
             void (*onOutput)(void *context, bool isError, const char *text, size_t length),
             void *context) {
    if (argv.empty()) return 125;
    if (*cancelled) return 130;
    // Prepare allocations before fork: the application has other native threads.
    std::vector<char *> raw;
    for (const std::string &item : argv) raw.push_back(const_cast<char *>(item.c_str()));
    raw.push_back(nullptr);
    std::vector<std::string> environment;
    for (char **entry = environ; entry != nullptr && *entry != nullptr; ++entry) {
        const std::string variable(*entry);
        if (variable.compare(0, 16, "LD_LIBRARY_PATH=") != 0 &&
            variable.compare(0, 7, "TMPDIR=") != 0) environment.push_back(variable);
    }
    if (!ldLibraryPath.empty()) environment.push_back("LD_LIBRARY_PATH=" + ldLibraryPath);
    if (!temporaryDirectory.empty()) environment.push_back("TMPDIR=" + temporaryDirectory);
    std::vector<char *> rawEnvironment;
    for (std::string &variable : environment) rawEnvironment.push_back(&variable[0]);
    rawEnvironment.push_back(nullptr);
    int outputPipe[2];
    int errorPipe[2];
    if (pipe2(outputPipe, O_CLOEXEC) != 0) return 125;
    if (pipe2(errorPipe, O_CLOEXEC) != 0) {
        close(outputPipe[0]); close(outputPipe[1]);
        return 125;
    }

    pid_t child = fork();
    if (child < 0) {
        close(outputPipe[0]); close(outputPipe[1]);
        close(errorPipe[0]); close(errorPipe[1]);
        return 125;
    }

    if (child == 0) {
        // Only async-signal-safe operations belong between fork and execve.
        /* 子进程：把管道接到标准输出/错误上，另立进程组以便整组取消。 */
        if (setpgid(0, 0) != 0 || dup2(outputPipe[1], STDOUT_FILENO) < 0 ||
            dup2(errorPipe[1], STDERR_FILENO) < 0) _exit(125);
        close(outputPipe[0]); close(outputPipe[1]);
        close(errorPipe[0]); close(errorPipe[1]);

        const int input = open(inputPath.empty() ? "/dev/null" : inputPath.c_str(), O_RDONLY);
        if (input < 0 || dup2(input, STDIN_FILENO) < 0) {
            const char message[] = "Forge: cannot open program input\n";
            (void)write(STDERR_FILENO, message, sizeof(message) - 1);
            _exit(125);
        }
        if (input != STDIN_FILENO) close(input);
        /*
         * 不能把 SDK 的链接期桩库塞进 LD_LIBRARY_PATH，只能放运行时目录。
         * 见 native/toolchain/README.md 的说明。
         */
        if (!workDirectory.empty() && chdir(workDirectory.c_str()) != 0) _exit(125);
        execve(raw[0], raw.data(), rawEnvironment.data());
        const int executionError = errno;
        const char message[] = "Forge: cannot execute compiler or program: ";
        (void)write(STDERR_FILENO, message, sizeof(message) - 1);
        if (executionError == EACCES) {
            const char detail[] = "permission denied\n";
            (void)write(STDERR_FILENO, detail, sizeof(detail) - 1);
        } else if (executionError == ENOENT) {
            const char detail[] = "executable or dynamic loader missing\n";
            (void)write(STDERR_FILENO, detail, sizeof(detail) - 1);
        } else if (executionError == ENOEXEC) {
            const char detail[] = "unsupported executable format\n";
            (void)write(STDERR_FILENO, detail, sizeof(detail) - 1);
        } else {
            const char detail[] = "execve failed\n";
            (void)write(STDERR_FILENO, detail, sizeof(detail) - 1);
        }
        _exit(125);
    }

    // Close the race where cancellation arrives before the child sets its group.
    (void)setpgid(child, child);
    close(outputPipe[1]);
    close(errorPipe[1]);

    /* 父进程：同时排空两条管道；cancelDescriptor 一可读就杀掉整个进程组。 */
    struct pollfd descriptors[3];
    descriptors[0] = {outputPipe[0], POLLIN, 0};
    descriptors[1] = {errorPipe[0], POLLIN, 0};
    descriptors[2] = {cancelDescriptor, POLLIN, 0};
    int openCount = 2;
    bool exited = false;
    bool failed = false;
    int status = 0;
    char buffer[4096];

    while (openCount > 0 || !exited) {
        // A child may close both streams while remaining alive. Conversely, its
        // descendants may retain streams after it exits. Observe both states.
        if (!exited) {
            const pid_t result = waitpid(child, &status, WNOHANG);
            if (result == child || (result < 0 && errno != EINTR)) {
                exited = true;
                failed = result < 0;
                (void)kill(-child, SIGKILL);
            }
        }
        if (exited && openCount == 0) break;
        const int ready = poll(descriptors, 3, 50);
        if (ready < 0) {
            if (errno == EINTR) continue;
            kill(-child, SIGKILL);
            if (!exited) kill(child, SIGKILL);
            failed = true;
            break;
        }

        if (cancelDescriptor >= 0 && (descriptors[2].revents & (POLLIN | POLLHUP))) {
            *cancelled = true;
            kill(-child, SIGKILL);
            if (!exited) kill(child, SIGKILL);
            descriptors[2].fd = -1;
        }

        for (int index = 0; index < 2; ++index) {
            if (!(descriptors[index].revents & (POLLIN | POLLHUP | POLLERR))) continue;
            const ssize_t count = read(descriptors[index].fd, buffer, sizeof(buffer));
            if (count > 0) {
                onOutput(context, index == 1, buffer, (size_t)count);
            } else if (count == 0 || (errno != EINTR && errno != EAGAIN)) {
                close(descriptors[index].fd);
                descriptors[index].fd = -1;
                --openCount;
            }
        }
    }

    for (int index = 0; index < 2; ++index) {
        if (descriptors[index].fd >= 0) close(descriptors[index].fd);
    }

    if (!exited) {
        pid_t result;
        do { result = waitpid(child, &status, 0); } while (result < 0 && errno == EINTR);
        if (result != child) failed = true;
    }
    if (*cancelled) return 130;
    if (failed) return 125;
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 125;
}

/* ---- 编译流程编排 ---- */

/* 一个待编译的翻译单元：路径 + 是否按 C++ 处理。 */
struct Source { std::string path; bool cpp; };

std::string Extension(const std::string &path) {
    const size_t dot = path.find_last_of('.');
    if (dot == std::string::npos) return std::string();
    std::string extension = path.substr(dot + 1);
    for (char &character : extension) character = (char)tolower((unsigned char)character);
    return extension;
}

bool IsSource(const std::string &path) {
    const std::string extension = Extension(path);
    return extension == "c" || extension == "cpp" || extension == "cc" || extension == "cxx";
}

bool ResolvePath(const std::string &path, std::string *resolved) {
    if (path.empty() || path[0] != '/' || path.find('\0') != std::string::npos) return false;
    char *canonical = realpath(path.c_str(), nullptr);
    if (canonical == nullptr) return false;
    resolved->assign(canonical);
    free(canonical);
    return true;
}

bool ValidateSources(std::string *project, std::string *entry, std::vector<Source> *sources) {
    struct stat info;
    if (!ResolvePath(*project, project) || stat(project->c_str(), &info) != 0 ||
        !S_ISDIR(info.st_mode) || access(project->c_str(), R_OK | X_OK) != 0 ||
        !ResolvePath(*entry, entry) || !IsSource(*entry) || sources->empty()) return false;
    const std::string prefix = project->back() == '/' ? *project : *project + "/";
    std::set<std::string> paths;
    bool includesEntry = false;
    for (Source &source : *sources) {
        if (!ResolvePath(source.path, &source.path) || !IsSource(source.path) ||
            source.path.compare(0, prefix.size(), prefix) != 0 ||
            stat(source.path.c_str(), &info) != 0 || !S_ISREG(info.st_mode) ||
            access(source.path.c_str(), R_OK) != 0 || !paths.insert(source.path).second) return false;
        source.cpp = Extension(source.path) != "c";
        includesEntry = includesEntry || source.path == *entry;
    }
    return includesEntry;
}

// NAPI strings must receive whole UTF-8 characters even when read splits bytes.
size_t CompleteUtf8Length(const std::string &text) {
    if (text.empty()) return 0;
    size_t start = text.size() - 1;
    while (start > 0 && (static_cast<unsigned char>(text[start]) & 0xc0) == 0x80) --start;
    const unsigned char lead = static_cast<unsigned char>(text[start]);
    const size_t expected = lead >= 0xc2 && lead <= 0xdf ? 2 :
        (lead >= 0xe0 && lead <= 0xef ? 3 : (lead >= 0xf0 && lead <= 0xf4 ? 4 : 1));
    return text.size() - start < expected ? start : text.size();
}

/* Never follow symlinks planted by a generated program during cleanup. */
void RemoveTreeAt(int parent, const char *name) {
    const int descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    DIR *directory = descriptor < 0 ? nullptr : fdopendir(descriptor);
    if (directory != nullptr) {
        while (struct dirent *entry = readdir(directory)) {
            const std::string name = entry->d_name;
            if (name == "." || name == "..") continue;
            RemoveTreeAt(dirfd(directory), name.c_str());
        }
        closedir(directory);
        (void)unlinkat(parent, name, AT_REMOVEDIR);
    } else {
        if (descriptor >= 0) close(descriptor);
        (void)unlinkat(parent, name, 0);
    }
}

void RemoveTree(const std::string &path) { RemoveTreeAt(AT_FDCWD, path.c_str()); }

/*
 * clang 的公共参数：目标平台、sysroot、C++ 头文件、链接器等。
 * 用 --config 读 ohos.cfg（里面写好了 OHOS 宏、libc++、compiler-rt、LLD），
 * 这样参数一处维护，和命令行验证脚本保持一致。
 */
std::vector<std::string> CompilerArguments(const Toolchain &toolchain, bool cpp) {
    std::vector<std::string> arguments = {
        toolchain.compiler,
        "--config", toolchain.config,
        "-fno-color-diagnostics",
    };
    if (cpp) {
        arguments.push_back("--driver-mode=g++");
    }
    return arguments;
}

/*
 * 编译并运行一个工程。
 *
 * 返回程序退出码；任何编译/链接失败都会原样返回失败状态，并且不会去跑旧产物。
 * 这是刻意保证的：上一次成功的 program.so 若被拿来跑，用户看到的会是过期结果。
 */
int CompileAndRun(const Toolchain &toolchain,
                  const std::string &projectPath,
                  const std::string &entryFile,
                  const std::vector<Source> &sources,
                  const std::string &temporaryDirectory,
                  int cancelDescriptor,
                  bool *cancelled,
                  void (*onOutput)(void *, bool, const char *, size_t),
                  void *context) {
    /* include 路径固定两条：工程根 + include/，与其它平台一致。 */
    const std::vector<std::string> includes = {
        "-I", projectPath,
        "-I", Join(projectPath, "include"),
    };

    std::vector<std::string> objects;
    for (size_t index = 0; index < sources.size(); ++index) {
        if (*cancelled) return 130;
        const Source &source = sources[index];
        const std::string object = Join(temporaryDirectory, std::to_string(index) + ".o");
        std::vector<std::string> command = CompilerArguments(toolchain, source.cpp);
        command.insert(command.end(), includes.begin(), includes.end());
        command.push_back(source.cpp ? "-std=c++20" : "-std=c17");
        command.push_back("-fPIC");
        command.push_back("-x");
        command.push_back(source.cpp ? "c++" : "c");
        command.push_back("-c");
        command.push_back(source.path);
        command.push_back("-o");
        command.push_back(object);

        /* 每次编译都通过 executor 起独立进程，用户代码的崩溃不会带走 App。 */
        std::vector<std::string> wrapped = {
            toolchain.executor, "--exec", Join(temporaryDirectory, "compile-" + std::to_string(index) + ".pid"),
        };
        wrapped.insert(wrapped.end(), command.begin(), command.end());
        const int code = RunChild(wrapped, projectPath, std::string(), toolchain.runtimeDir,
                                  temporaryDirectory, cancelDescriptor, cancelled, onOutput, context);
        if (code != 0) return *cancelled ? 130 : code;
        objects.push_back(object);
    }
    if (*cancelled) return 130;

    /* 只要有一个 C++ 单元，就用 C++ 链接（包括 C main 调 C++ 辅助函数的情况）。 */
    bool linkCpp = false;
    for (const Source &source : sources) {
        if (source.cpp) { linkCpp = true; break; }
    }

    const std::string program = Join(temporaryDirectory, "program.so");
    std::vector<std::string> link = CompilerArguments(toolchain, linkCpp);
    // Installed LLD is signed alongside the app. Only linking needs the path;
    // passing it to -c would produce an unused-argument warning for every unit.
    if (!toolchain.linker.empty()) link.push_back("--ld-path=" + toolchain.linker);
    /*
     * -shared 让产物可直接被 dlopen；-z,defs 保证未定义符号在链接期就报错，
     * 而不是拖到运行时才崩。16KB 页对齐是 OHOS 的强制要求。
     */
    link.push_back("-shared");
    link.push_back("-Wl,-z,defs");
    link.push_back("-Wl,-z,max-page-size=16384,-z,common-page-size=16384");
    link.insert(link.end(), objects.begin(), objects.end());
    // OHOS supplies atomic builtins through compiler-rt; its SDK has no
    // standalone libatomic (unlike the Android package).
    link.push_back("-lm");
    link.push_back("-o");
    link.push_back(program);

    std::vector<std::string> linkWrapped = {
        toolchain.executor, "--exec", Join(temporaryDirectory, "link.pid"),
    };
    linkWrapped.insert(linkWrapped.end(), link.begin(), link.end());
    const int linkCode = RunChild(linkWrapped, projectPath, std::string(), toolchain.runtimeDir,
                                  temporaryDirectory, cancelDescriptor, cancelled, onOutput, context);
    if (linkCode != 0 || *cancelled) return *cancelled ? 130 : linkCode;

    /* 程序文件设为只读，防止用户代码运行期间被改写。 */
    if (chmod(program.c_str(), 0555) != 0) {
        const char message[] = "Forge: cannot mark compiled program read-only\n";
        onOutput(context, true, message, sizeof(message) - 1);
        return 125;
    }

    /* 跑程序。input.txt 存在就作为标准输入。 */
    const std::string input = Join(projectPath, "input.txt");
    struct stat inputStat;
    const bool hasInput = stat(input.c_str(), &inputStat) == 0 && S_ISREG(inputStat.st_mode);

    const std::string entryName = entryFile.substr(entryFile.find_last_of('/') + 1);
    std::vector<std::string> run = {
        toolchain.executor, "--run", Join(temporaryDirectory, "run.pid"), program, entryName,
    };
    return RunChild(run, projectPath, hasInput ? input : std::string(), toolchain.runtimeDir,
                    temporaryDirectory, cancelDescriptor, cancelled, onOutput, context);
}

}  // namespace

/* ---- NAPI 接口层 ---- */

namespace {

/*
 * 一次运行的完整状态。生命周期：start_run 创建 → 后台线程跑完 → 回调里释放。
 * ArkTS 侧持有一个句柄（外部指针）用于取消。
 */
struct RunState {
    napi_env env = nullptr;
    napi_threadsafe_function events = nullptr;
    Toolchain toolchain;
    std::string projectPath;
    std::string entryFile;
    std::vector<Source> sources;
    std::string temporaryDirectory;
    int cancelPipe[2] = {-1, -1};
    bool cancelled = false;
    bool accepted = false;
    std::mutex mutex;
    std::string pendingOutput[2];

    ~RunState() {
        if (cancelPipe[0] >= 0) close(cancelPipe[0]);
        if (cancelPipe[1] >= 0) close(cancelPipe[1]);
        if (events != nullptr) napi_release_threadsafe_function(events, napi_tsfn_release);
    }
};

// The external handle remains valid until JS garbage collection, including
// repeated destroy/cancel calls. The worker separately owns its run state.
struct RunHandle { std::shared_ptr<RunState> state; };

void RequestCancel(RunState *state) {
    if (state == nullptr) return;
    std::lock_guard<std::mutex> lock(state->mutex);
    if (state->cancelPipe[1] >= 0) {
        const char signal = 1;
        ssize_t written;
        do { written = write(state->cancelPipe[1], &signal, 1); } while (written < 0 && errno == EINTR);
    }
}

void FinalizeHandle(napi_env, void *data, void *) {
    RunHandle *handle = static_cast<RunHandle *>(data);
    RequestCancel(handle->state.get());
    delete handle;
}

std::shared_ptr<RunState> ReadHandle(napi_env env, napi_value value) {
    void *raw = nullptr;
    if (napi_get_value_external(env, value, &raw) != napi_ok || raw == nullptr) return nullptr;
    return static_cast<RunHandle *>(raw)->state;
}

/* 从 TSFN 派发到 JS 线程的事件：一段 stdout/stderr 文本，或最终退出码。 */
struct EventPayload {
    bool isExit = false;
    bool isError = false;
    int exitCode = 0;
    std::string text;
};

/* JS 线程上执行：把事件转成 JS 对象并调用回调。 */
void CallJsEvent(napi_env env, napi_value jsCallback, void * /*context*/, void *data) {
    EventPayload *payload = static_cast<EventPayload *>(data);
    if (env != nullptr && jsCallback != nullptr) {
        napi_value event = nullptr;
        if (napi_create_object(env, &event) == napi_ok) {
            napi_value kind = nullptr;
            const char *kindText = payload->isExit ? "exit" : (payload->isError ? "stderr" : "stdout");
            napi_create_string_utf8(env, kindText, NAPI_AUTO_LENGTH, &kind);
            napi_set_named_property(env, event, "kind", kind);

            if (payload->isExit) {
                napi_value code = nullptr;
                napi_create_int32(env, payload->exitCode, &code);
                napi_set_named_property(env, event, "exitCode", code);
            } else {
                napi_value text = nullptr;
                napi_create_string_utf8(env, payload->text.c_str(), payload->text.size(), &text);
                napi_set_named_property(env, event, "text", text);
            }
            napi_value receiver = nullptr;
            if (napi_get_undefined(env, &receiver) == napi_ok) {
                napi_call_function(env, receiver, jsCallback, 1, &event, nullptr);
            }
        }
    }
    delete payload;
}

/* 把一段输出或退出事件送到 JS 线程。 */
void EmitEvent(RunState *state, EventPayload *payload) {
    if (state->events == nullptr) { delete payload; return; }
    if (napi_call_threadsafe_function(state->events, payload, napi_tsfn_nonblocking) != napi_ok) {
        delete payload;
    }
}

/*
 * RunChild 的输出回调。注意它可能收到半行甚至半个 UTF-8 字符：
 * 管道读取是按块来的，不保证边界落在字符或行上。保留不完整 UTF-8 尾部，
 * 确保 NAPI 转成字符串时不会把中文/emoji 拆坏；分行交给 ArkTS。
 */
void OnOutput(void *context, bool isError, const char *text, size_t length) {
    RunState *state = static_cast<RunState *>(context);
    std::string &pending = state->pendingOutput[isError ? 1 : 0];
    pending.append(text, length);
    const size_t complete = CompleteUtf8Length(pending);
    if (complete == 0) return;
    EventPayload *payload = new EventPayload();
    payload->isError = isError;
    payload->text.assign(pending, 0, complete);
    pending.erase(0, complete);
    EmitEvent(state, payload);
}

/* 后台线程主体。 */
void RunOnWorker(std::shared_ptr<RunState> ownedState) {
    RunState *state = ownedState.get();
    const std::string module = state->temporaryDirectory + "/program-XXXXXX";
    std::vector<char> templateBuffer(module.begin(), module.end());
    templateBuffer.push_back('\0');
    int status = 125;
    // mkdtemp creates the private directory atomically without a symlink window.
    if (mkdtemp(templateBuffer.data()) != nullptr) {
        std::string temporaryDirectory = templateBuffer.data();
        state->temporaryDirectory = temporaryDirectory;
        try {
            status = CompileAndRun(state->toolchain, state->projectPath, state->entryFile,
                                   state->sources, temporaryDirectory, state->cancelPipe[0],
                                   &state->cancelled, OnOutput, state);
        } catch (const std::exception &) {
            const char message[] = "Forge: native compilation failed unexpectedly\n";
            OnOutput(state, true, message, sizeof(message) - 1);
        }
        RemoveTree(temporaryDirectory);
    } else {
        const char message[] = "Forge: cannot create compiler temporary directory\n";
        OnOutput(state, true, message, sizeof(message) - 1);
    }
    for (int index = 0; index < 2; ++index) {
        if (state->pendingOutput[index].empty()) continue;
        EventPayload *tail = new EventPayload();
        tail->isError = index == 1;
        tail->text.swap(state->pendingOutput[index]);
        EmitEvent(state, tail);
    }

    EventPayload *finalEvent = new EventPayload();
    finalEvent->isExit = true;
    finalEvent->exitCode = state->cancelled ? 130 : status;
    EmitEvent(state, finalEvent);

    if (state->events != nullptr) {
        napi_release_threadsafe_function(state->events, napi_tsfn_release);
        state->events = nullptr;
    }
    {
        std::lock_guard<std::mutex> lock(state->mutex);
        if (state->cancelPipe[0] >= 0) { close(state->cancelPipe[0]); state->cancelPipe[0] = -1; }
        if (state->cancelPipe[1] >= 0) { close(state->cancelPipe[1]); state->cancelPipe[1] = -1; }
    }

}

}  // namespace

/* ---- 导出的 NAPI 接口 ---- */

namespace {

/* 读一个必填字符串参数。 */
bool ReadString(napi_env env, napi_value value, std::string *out) {
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok || type != napi_string) return false;
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) return false;
    std::vector<char> buffer(length + 1);
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &length) != napi_ok) {
        return false;
    }
    out->assign(buffer.data(), length);
    return out->find('\0') == std::string::npos;
}

napi_value MakeBoolean(napi_env env, bool value) {
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

/*
 * create(options) -> handle | null
 *
 * options = {
 *   toolchainRoot: string,  解压后的工具链根目录
 *   executorPath: string,   libqfli_executor.so 绝对路径
 *   compilerPath?: string,  安装目录中的 libqfli_clang.so
 *   linkerPath?: string,    安装目录中的 libqfli-ld.lld-.so
 *   runtimeDirectory?: string, 安装目录（含 libc++_shared.so）
 *   onEvent: (event) => void
 * }
 * event = { kind: 'stdout'|'stderr', text } | { kind: 'exit', exitCode }
 */
napi_value Create(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc < 1) {
        return nullptr;
    }

    napi_value rootValue = nullptr;
    napi_value executorValue = nullptr;
    napi_value callback = nullptr;
    if (napi_get_named_property(env, args[0], "toolchainRoot", &rootValue) != napi_ok ||
        napi_get_named_property(env, args[0], "executorPath", &executorValue) != napi_ok ||
        napi_get_named_property(env, args[0], "onEvent", &callback) != napi_ok) {
        return nullptr;
    }

    auto state = std::make_shared<RunState>();
    if (!ReadString(env, rootValue, &state->toolchain.root) ||
        !ReadString(env, executorValue, &state->toolchain.executor) ||
        !ResolvePath(state->toolchain.root, &state->toolchain.root) ||
        !ResolvePath(state->toolchain.executor, &state->toolchain.executor)) {
        return nullptr;
    }

    /* 工具链内部布局由打包脚本固定，这里按约定拼出来。 */
    const std::string &root = state->toolchain.root;
    state->toolchain.compiler = Join(root, "bin/clang");
    state->toolchain.linker = Join(root, "bin/ld.lld");
    state->toolchain.config = Join(root, "bin/ohos.cfg");
    state->toolchain.sysroot = Join(root, "sysroot");
    state->toolchain.resourceDir = Join(root, "lib/clang/15.0.7");
    state->toolchain.runtimeDir = Join(root, "lib/aarch64-unknown-linux-ohos");
    // Production supplies signed native-library paths; overrides also keep the
    // standalone packaged-toolchain layout usable for local compiler checks.
    auto readOverride = [&](const char *name, std::string *path) {
        bool present = false;
        napi_value value = nullptr;
        return napi_has_named_property(env, args[0], name, &present) == napi_ok &&
            (!present || (napi_get_named_property(env, args[0], name, &value) == napi_ok &&
                          ReadString(env, value, path)));
    };
    if (!readOverride("compilerPath", &state->toolchain.compiler) ||
        !readOverride("linkerPath", &state->toolchain.linker) ||
        !readOverride("runtimeDirectory", &state->toolchain.runtimeDir) ||
        !ResolvePath(state->toolchain.compiler, &state->toolchain.compiler) ||
        !ResolvePath(state->toolchain.linker, &state->toolchain.linker) ||
        !ResolvePath(state->toolchain.runtimeDir, &state->toolchain.runtimeDir) ||
        access(state->toolchain.compiler.c_str(), X_OK) != 0 ||
        access(state->toolchain.linker.c_str(), X_OK) != 0 ||
        access(state->toolchain.executor.c_str(), X_OK) != 0) return nullptr;
    state->env = env;

    napi_value name = nullptr;
    napi_create_string_utf8(env, "qfli_ohos_events", NAPI_AUTO_LENGTH, &name);
    if (napi_create_threadsafe_function(env, callback, nullptr, name, 0, 1, nullptr, nullptr,
                                        nullptr, CallJsEvent, &state->events) != napi_ok) {
        return nullptr;
    }

    if (pipe2(state->cancelPipe, O_NONBLOCK | O_CLOEXEC) != 0) return nullptr;

    napi_value handle = nullptr;
    auto *external = new RunHandle{state};
    if (napi_create_external(env, external, FinalizeHandle, nullptr, &handle) != napi_ok) {
        delete external;
        return nullptr;
    }
    return handle;
}

/*
 * run(handle, projectPath, entryFile, sources: string[], cacheDirectory) -> boolean
 *
 * 立即返回；编译/运行的进展通过 onEvent 回调异步回传。
 * 同一句柄只能跑一次（与 Android/iOS 的会话语义一致）。
 */
napi_value Run(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5] = {nullptr, nullptr, nullptr, nullptr, nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc < 5) {
        return MakeBoolean(env, false);
    }

    auto state = ReadHandle(env, args[0]);
    if (state == nullptr || state->accepted) return MakeBoolean(env, false);

    std::string project, entry, temporary;
    if (!ReadString(env, args[1], &project) || !ReadString(env, args[2], &entry) ||
        !ReadString(env, args[4], &temporary) || !ResolvePath(temporary, &temporary)) {
        return MakeBoolean(env, false);
    }

    uint32_t count = 0;
    bool isArray = false;
    if (napi_is_array(env, args[3], &isArray) != napi_ok || !isArray ||
        napi_get_array_length(env, args[3], &count) != napi_ok || count == 0) {
        return MakeBoolean(env, false);
    }
    std::vector<Source> sources;
    for (uint32_t index = 0; index < count; ++index) {
        napi_value element = nullptr;
        if (napi_get_element(env, args[3], index, &element) != napi_ok) return MakeBoolean(env, false);
        Source source;
        if (!ReadString(env, element, &source.path)) return MakeBoolean(env, false);
        if (!IsSource(source.path)) return MakeBoolean(env, false);
        source.cpp = Extension(source.path) != "c";
        sources.push_back(source);
    }

    struct stat temporaryInfo;
    if (!ValidateSources(&project, &entry, &sources) ||
        stat(temporary.c_str(), &temporaryInfo) != 0 || !S_ISDIR(temporaryInfo.st_mode) ||
        access(temporary.c_str(), W_OK | X_OK) != 0) return MakeBoolean(env, false);
    state->projectPath = std::move(project);
    state->entryFile = std::move(entry);
    state->sources = std::move(sources);
    state->temporaryDirectory = std::move(temporary);

    state->accepted = true;
    /* 交给后台线程，绝不阻塞 ArkTS 主线程（编译可能要几十秒）。 */
    try {
        std::thread(RunOnWorker, state).detach();
    } catch (const std::exception &) {
        state->accepted = false;
        return MakeBoolean(env, false);
    }
    return MakeBoolean(env, true);
}

/* cancel(handle) -> void：请求取消；实际清理在后台线程里做。 */
napi_value Cancel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) == napi_ok && argc >= 1) {
        auto state = ReadHandle(env, args[0]);
        RequestCancel(state.get());
    }
    return nullptr;
}

/*
 * destroy(handle) -> void
 *
 * 取消并释放句柄的所有权；worker 持有独立 shared_ptr，清理完毕后自行释放。
 * external 包装本身保留到 GC，所以重复 destroy/cancel 不会读已释放的内存。
 */
napi_value Destroy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) == napi_ok && argc >= 1) {
        void *raw = nullptr;
        if (napi_get_value_external(env, args[0], &raw) == napi_ok && raw != nullptr) {
            auto *handle = static_cast<RunHandle *>(raw);
            RequestCancel(handle->state.get());
            handle->state.reset();
        }
    }
    return nullptr;
}

}  // namespace

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"create", nullptr, Create, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cancel", nullptr, Cancel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroy", nullptr, Destroy, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
    return exports;
}

static napi_module qfliOhosRunnerModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "qfli_ohos_runner",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterQfliOhosRunnerModule(void) {
    napi_module_register(&qfliOhosRunnerModule);
}
