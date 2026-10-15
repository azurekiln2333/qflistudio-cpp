#include <AbilityKit/native_child_process.h>
#include <napi/native_api.h>
#include <hilog/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

namespace {
constexpr unsigned kDomain = 0xD003F00;
constexpr const char *kTag = "QfliChildProbe";
using StartChild = Ability_NativeChildProcess_ErrCode (*)(
    const char *, NativeChildProcess_Args, NativeChildProcess_Options, int32_t *);

napi_value Start(napi_env env, napi_callback_info info) {
    char reportPath[4096] = {};
    size_t argc = 1;
    napi_value argument = nullptr;
    napi_get_cb_info(env, info, &argc, &argument, nullptr, nullptr);
    size_t pathLength = 0;
    if (argc != 1 || napi_get_value_string_utf8(env, argument, reportPath,
            sizeof(reportPath), &pathLength) != napi_ok ||
            pathLength == 0 || pathLength >= sizeof(reportPath) - 1 || reportPath[0] != '/') {
        napi_throw_type_error(env, nullptr, "start requires an absolute writable report path");
        return nullptr;
    }

    int report = open(reportPath, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    int openError = report < 0 ? errno : 0;
    void *library = dlopen("libchild_process.so", RTLD_NOW | RTLD_LOCAL);
    StartChild start = library == nullptr ? nullptr :
        reinterpret_cast<StartChild>(dlsym(library, "OH_Ability_StartNativeChildProcess"));
    const char *loaderError = start == nullptr ? dlerror() : nullptr;
    char loaderMessage[256] = {};
    if (loaderError != nullptr) snprintf(loaderMessage, sizeof(loaderMessage), "%s", loaderError);

    int32_t pid = -1;
    int error = -1;
    if (start != nullptr && report >= 0) {
        char fdName[] = "report";
        char params[] = "qfli-native-child-capability-probe";
        NativeChildProcess_Fd fd{fdName, report, nullptr};
        NativeChildProcess_Args args{params, {&fd}};
        NativeChildProcess_Options options{NCP_ISOLATION_MODE_NORMAL, 0};
        error = start("libqfli_native_probe.so:QfliProbeMain", args, options, &pid);
    }
    if (report >= 0) close(report);
    // Keep the library loaded: an API implementation may retain worker callbacks.
    char result[768];
    snprintf(result, sizeof(result),
        "apiAvailable=%d errorCode=%d pid=%d openErrno=%d loaderError=%s report=%s",
        start != nullptr, error, pid, openError, loaderMessage, reportPath);
    OH_LOG_Print(LOG_APP, LOG_INFO, kDomain, kTag,
        "QFLI_NATIVE_CHILD_START %{public}s", result);
    napi_value value = nullptr;
    napi_create_string_utf8(env, result, NAPI_AUTO_LENGTH, &value);
    return value;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor property = {
        "start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &property);
    return exports;
}
napi_module module = {1, 0, nullptr, Init, "qfli_native_probe", nullptr, {nullptr}};
} // namespace

extern "C" __attribute__((visibility("default")))
void QfliProbeMain(NativeChildProcess_Args args) {
    char message[256];
    int length = snprintf(message, sizeof(message),
        "QFLI_NATIVE_CHILD_ENTERED pid=%d ppid=%d uid=%d entryParams=%s\n",
        getpid(), getppid(), getuid(), args.entryParams == nullptr ? "" : args.entryParams);
    OH_LOG_Print(LOG_APP, LOG_INFO, kDomain, kTag, "%{public}s", message);
    for (NativeChildProcess_Fd *fd = args.fdList.head; fd != nullptr; fd = fd->next) {
        if (fd->fdName != nullptr && strcmp(fd->fdName, "report") == 0 && fd->fd >= 0) {
            if (length > 0) write(fd->fd, message, static_cast<size_t>(length));
            fsync(fd->fd);
            close(fd->fd);
            break;
        }
    }
}

extern "C" __attribute__((constructor)) void RegisterQfliNativeProbe() {
    napi_module_register(&module);
}
