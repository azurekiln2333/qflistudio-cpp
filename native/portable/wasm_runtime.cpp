#include "qfli_wasm.h"
#include "../include/qfli_wasm_limits.h"

#include <wasmedge/wasmedge.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <new>
#include <string>

struct qfli_wasm_session {
  std::atomic<bool> cancelled{false};
  std::atomic<bool> used{false};
  std::string error;
};

namespace {
template <typename T, void (*Delete)(T *)>
using Owned = std::unique_ptr<T, decltype(Delete)>;

constexpr int kRuntimeError = 125;
constexpr int kCancelled = 130;
constexpr uint32_t kMaxMemoryPages = QFLI_WASM_MAX_MEMORY_PAGES;
std::once_flag initialized;

int fail(qfli_wasm_session &session, const char *message) {
  session.error = message;
  return session.cancelled.load() ? kCancelled : kRuntimeError;
}
} // namespace

qfli_wasm_session *qfli_wasm_create(void) {
  return new (std::nothrow) qfli_wasm_session;
}

int qfli_wasm_run(qfli_wasm_session *session, const char *module_path,
                  const char *project_path, int input_fd, int output_fd,
                  int error_fd, uint64_t cost_limit) {
  if (!session || !module_path || !project_path) return kRuntimeError;
  if (session->used.exchange(true)) return kRuntimeError;
  if (session->cancelled.load()) return kCancelled;
  try {
    // Engine diagnostics are returned per session; keep process stdio private.
    std::call_once(initialized, WasmEdge_LogOff);
    Owned<WasmEdge_ConfigureContext, WasmEdge_ConfigureDelete> config(
        WasmEdge_ConfigureCreate(), WasmEdge_ConfigureDelete);
    if (!config) return fail(*session, "Cannot create Wasm configuration.");
    WasmEdge_ConfigureAddProposal(config.get(), WasmEdge_Proposal_ExceptionHandling);
    WasmEdge_ConfigureSetForceInterpreter(config.get(), true);
    WasmEdge_ConfigureSetMaxMemoryPage(config.get(), kMaxMemoryPages);
    WasmEdge_ConfigureStatisticsSetCostMeasuring(config.get(), cost_limit != 0);

    // WASI borrows these FDs without changing the app's process-wide stdio.
    const char *args[] = {module_path};
    const std::string mapping = std::string("/:") + project_path;
    const char *preopens[] = {mapping.c_str()};
    Owned<WasmEdge_ModuleInstanceContext, WasmEdge_ModuleInstanceDelete> wasi(
        WasmEdge_ModuleInstanceCreateWASIWithFds(args, 1, nullptr, 0, preopens,
                                                 1, input_fd, output_fd, error_fd),
        WasmEdge_ModuleInstanceDelete);
    if (!wasi) return fail(*session, "Cannot initialize WASI input/output.");

    // Destroy the VM before its borrowed WASI import module.
    Owned<WasmEdge_VMContext, WasmEdge_VMDelete> vm(
        WasmEdge_VMCreate(config.get(), nullptr), WasmEdge_VMDelete);
    if (!vm) return fail(*session, "Cannot create Wasm interpreter.");
    auto result = WasmEdge_VMRegisterModuleFromImport(vm.get(), wasi.get());
    if (!WasmEdge_ResultOK(result)) {
      return fail(*session, WasmEdge_ResultGetMessage(result));
    }
    if (cost_limit) {
      WasmEdge_StatisticsSetCostLimit(WasmEdge_VMGetStatisticsContext(vm.get()),
                                      cost_limit);
    }

    Owned<WasmEdge_Async, WasmEdge_AsyncDelete> execution(
        WasmEdge_VMAsyncRunWasmFromFile(
            vm.get(), module_path, WasmEdge_StringWrap("_start", 6), nullptr, 0),
        WasmEdge_AsyncDelete);
    if (!execution) return fail(*session, "Cannot start Wasm execution.");
    while (!WasmEdge_AsyncWaitFor(execution.get(), 10)) {
      // Repeat until joined: cancellation can arrive before VM startup resets
      // the engine's interrupt flag, including during module instantiation.
      if (session->cancelled.load()) WasmEdge_AsyncCancel(execution.get());
    }
    result = WasmEdge_AsyncGet(execution.get(), nullptr, 0);
    if (session->cancelled.load()) return kCancelled;
    if (!WasmEdge_ResultOK(result)) {
      return fail(*session, WasmEdge_ResultGetMessage(result));
    }
    return static_cast<int>(WasmEdge_ModuleInstanceWASIGetExitCode(wasi.get()));
  } catch (const std::exception &error) {
    return fail(*session, error.what());
  } catch (...) {
    return fail(*session, "Unknown Wasm runtime error.");
  }
}

void qfli_wasm_cancel(qfli_wasm_session *session) {
  if (session) session->cancelled.store(true);
}

const char *qfli_wasm_error(const qfli_wasm_session *session) {
  return session ? session->error.c_str() : "Missing Wasm session.";
}

void qfli_wasm_destroy(qfli_wasm_session *session) { delete session; }
