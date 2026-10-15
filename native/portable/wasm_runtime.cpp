#include "qfli_wasm.h"
#include "../include/qfli_wasm_limits.h"

#include <wasmedge/wasmedge.h>

#include <atomic>
#include <array>
#include <cerrno>
#include <climits>
#include <memory>
#include <mutex>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

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

void check(WasmEdge_Result result) {
  if (!WasmEdge_ResultOK(result)) {
    throw std::runtime_error(WasmEdge_ResultGetMessage(result));
  }
}

std::string text(WasmEdge_String value) {
  return std::string(value.Buf, value.Length);
}

// WASI threads instantiate the same module with one shared imported memory.
// Each guest thread owns its VM, interpreter stack and mutable Wasm globals.
// The WASI import module (including its descriptor table) is shared.
class ThreadGroup {
  using VM = Owned<WasmEdge_VMContext, WasmEdge_VMDelete>;
  using Async = Owned<WasmEdge_Async, WasmEdge_AsyncDelete>;
  using Module = Owned<WasmEdge_ModuleInstanceContext, WasmEdge_ModuleInstanceDelete>;
  static constexpr size_t kMaxThreads = 32;
  struct Worker {
    VM vm{nullptr, WasmEdge_VMDelete};
    Async execution{nullptr, WasmEdge_AsyncDelete};
  };

public:
  ThreadGroup(qfli_wasm_session &session, WasmEdge_ConfigureContext *configuration,
              WasmEdge_ASTModuleContext *module,
              WasmEdge_ModuleInstanceContext *wasi,
              const WasmEdge_MemoryTypeContext *memory_type, uint64_t cost_limit)
      : session_(session), configuration_(configuration), module_(module),
        wasi_(wasi), cost_limit_(cost_limit) {
    const auto *limit = WasmEdge_MemoryTypeGetLimit(memory_type);
    if (!WasmEdge_LimitIsShared(limit) || !WasmEdge_LimitHasMax(limit) ||
        WasmEdge_LimitGetMin(limit) > kMaxMemoryPages ||
        WasmEdge_LimitGetMax(limit) > kMaxMemoryPages) {
      throw std::runtime_error("Shared Wasm memory exceeds the runtime limit.");
    }
    environment_.reset(WasmEdge_ModuleInstanceCreate(WasmEdge_StringWrap("env", 3)));
    host_.reset(WasmEdge_ModuleInstanceCreate(WasmEdge_StringWrap("wasi", 4)));
    if (!environment_ || !host_) throw std::bad_alloc();
    Owned<WasmEdge_MemoryInstanceContext, WasmEdge_MemoryInstanceDelete> memory(
        WasmEdge_MemoryInstanceCreate(memory_type), WasmEdge_MemoryInstanceDelete);
    if (!memory) throw std::bad_alloc();
    check(WasmEdge_ModuleInstanceAddMemory(environment_.get(),
        WasmEdge_StringWrap("memory", 6), memory.get()));
    memory.release();
    add_function(host_.get(), "thread-spawn", Spawn, true);
    // Replace proc_exit before any VM finalizes the shared host module. Keep
    // the process status under our mutex instead of concurrently writing the
    // WASI module's ordinary (non-atomic) exit-code member from several VMs.
    add_function(wasi_, "proc_exit", ProcessExit, false);
  }

  ~ThreadGroup() {
    // Also covers partial startup and exception paths. Imported modules and
    // the AST remain alive until every asynchronous interpreter has joined.
    stop_and_join();
  }

  int run() {
    main_.vm = new_vm();
    main_.execution.reset(WasmEdge_VMAsyncRunWasmFromASTModule(
        main_.vm.get(), module_, WasmEdge_StringWrap("_start", 6), nullptr, 0));
    if (!main_.execution) throw std::bad_alloc();
    while (!WasmEdge_AsyncWaitFor(main_.execution.get(), 10)) {
      poll();
    }
    const auto result = WasmEdge_AsyncGet(main_.execution.get(), nullptr, 0);
    // Returning from _start ends detached guest threads as well. Completed
    // guest joins may still leave the host worker finishing its final frames.
    // Collect workers that finished since the last timed poll before cleanup
    // starts ignoring the interruptions produced by our own cancellation.
    poll();
    stop_and_join();
    if (session_.cancelled.load()) return kCancelled;
    if (!error_.empty()) return fail(session_, error_.c_str());
    if (exit_requested_) return static_cast<int>(exit_code_);
    if (!WasmEdge_ResultOK(result)) return fail(session_, WasmEdge_ResultGetMessage(result));
    return 0;
  }

private:
  void add_function(WasmEdge_ModuleInstanceContext *module, const char *name,
                     WasmEdge_HostFunc_t callback, bool returns_id) {
    const WasmEdge_ValType argument = WasmEdge_ValTypeGenI32();
    Owned<WasmEdge_FunctionTypeContext, WasmEdge_FunctionTypeDelete> type(
        WasmEdge_FunctionTypeCreate(&argument, 1, returns_id ? &argument : nullptr,
                                     returns_id ? 1 : 0), WasmEdge_FunctionTypeDelete);
    if (!type) throw std::bad_alloc();
    Owned<WasmEdge_FunctionInstanceContext, WasmEdge_FunctionInstanceDelete> function(
        WasmEdge_FunctionInstanceCreate(type.get(), callback, this, 0),
        WasmEdge_FunctionInstanceDelete);
    if (!function) throw std::bad_alloc();
    check(WasmEdge_ModuleInstanceAddFunction(module,
        WasmEdge_StringWrap(name, static_cast<uint32_t>(std::char_traits<char>::length(name))),
        function.get()));
    function.release();
  }

  VM new_vm() {
    VM vm(WasmEdge_VMCreate(configuration_, nullptr), WasmEdge_VMDelete);
    if (!vm) throw std::bad_alloc();
    check(WasmEdge_VMRegisterModuleFromImport(vm.get(), environment_.get()));
    check(WasmEdge_VMRegisterModuleFromImport(vm.get(), wasi_));
    check(WasmEdge_VMRegisterModuleFromImport(vm.get(), host_.get()));
    if (cost_limit_) {
      WasmEdge_StatisticsSetCostLimit(WasmEdge_VMGetStatisticsContext(vm.get()), cost_limit_);
    }
    return vm;
  }

  // Called with mutex_ held. A finished Async has joined its interpreter;
  // releasing its VM here cannot race a callback or shared-memory access.
  void collect(Worker &worker) {
    if (!worker.execution || !WasmEdge_AsyncWaitFor(worker.execution.get(), 0)) return;
    const auto result = WasmEdge_AsyncGet(worker.execution.get(), nullptr, 0);
    if (!stopping_ && !WasmEdge_ResultOK(result) && error_.empty()) {
      error_ = WasmEdge_ResultGetMessage(result);
      stopping_ = true;
    }
    worker.execution.reset();
    worker.vm.reset();
  }

  void cancel_locked() noexcept {
    if (main_.execution) WasmEdge_AsyncCancel(main_.execution.get());
    for (auto &worker : workers_) {
      if (worker.execution) WasmEdge_AsyncCancel(worker.execution.get());
    }
  }

  void poll() {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto &worker : workers_) collect(worker);
    if (session_.cancelled.load() || exit_requested_ || stopping_) {
      stopping_ = true;
      cancel_locked();
    }
  }

  void stop_and_join() noexcept {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      stopping_ = true;
      cancel_locked();
    }
    // Reissue cancellation through module startup, which can reset the
    // interpreter's stop token. Never hold the callback mutex while joining.
    if (main_.execution) {
      while (!WasmEdge_AsyncWaitFor(main_.execution.get(), 10)) {
        std::lock_guard<std::mutex> lock(mutex_);
        cancel_locked();
      }
    }
    for (auto &worker : workers_) {
      if (!worker.execution) continue;
      while (!WasmEdge_AsyncWaitFor(worker.execution.get(), 10)) {
        std::lock_guard<std::mutex> lock(mutex_);
        cancel_locked();
      }
      worker.execution.reset();
      worker.vm.reset();
    }
    main_.execution.reset();
    main_.vm.reset();
  }

  static WasmEdge_Result Spawn(void *data, const WasmEdge_CallingFrameContext *,
                                const WasmEdge_Value *arguments, WasmEdge_Value *returns) noexcept {
    auto &group = *static_cast<ThreadGroup *>(data);
    returns[0] = WasmEdge_ValueGenI32(-EAGAIN);
    try {
      std::lock_guard<std::mutex> lock(group.mutex_);
      if (group.stopping_ || group.exit_requested_ || group.session_.cancelled.load() ||
          group.next_id_ == INT_MAX) return WasmEdge_Result_Success;
      Worker *slot = nullptr;
      for (auto &worker : group.workers_) {
        group.collect(worker);
        if (!worker.execution && slot == nullptr) slot = &worker;
      }
      if (!slot || group.stopping_) return WasmEdge_Result_Success;
      auto vm = group.new_vm();
      const int id = group.next_id_++;
      const WasmEdge_Value parameters[] = {
          WasmEdge_ValueGenI32(id), arguments[0]};
      Async execution(WasmEdge_VMAsyncRunWasmFromASTModule(vm.get(), group.module_,
          WasmEdge_StringWrap("wasi_thread_start", 17), parameters, 2), WasmEdge_AsyncDelete);
      if (!execution) return WasmEdge_Result_Success;
      slot->vm = std::move(vm);
      slot->execution = std::move(execution);
      returns[0] = WasmEdge_ValueGenI32(id);
    } catch (...) {
      // WASI thread-spawn reports allocation/host-thread failure to the guest.
    }
    return WasmEdge_Result_Success;
  }

  static WasmEdge_Result ProcessExit(void *data, const WasmEdge_CallingFrameContext *,
                                      const WasmEdge_Value *arguments, WasmEdge_Value *) noexcept {
    auto &group = *static_cast<ThreadGroup *>(data);
    std::lock_guard<std::mutex> lock(group.mutex_);
    if (!group.exit_requested_) {
      group.exit_code_ = static_cast<uint32_t>(WasmEdge_ValueGetI32(arguments[0]));
      group.exit_requested_ = true;
    }
    return WasmEdge_Result_Terminate;
  }

  qfli_wasm_session &session_;
  WasmEdge_ConfigureContext *configuration_;
  WasmEdge_ASTModuleContext *module_;
  WasmEdge_ModuleInstanceContext *wasi_;
  uint64_t cost_limit_;
  Module environment_{nullptr, WasmEdge_ModuleInstanceDelete};
  Module host_{nullptr, WasmEdge_ModuleInstanceDelete};
  std::mutex mutex_;
  std::array<Worker, kMaxThreads> workers_;
  Worker main_;
  int next_id_ = 2;
  bool stopping_ = false;
  bool exit_requested_ = false;
  uint32_t exit_code_ = 0;
  std::string error_;
};
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
    WasmEdge_ConfigureAddProposal(config.get(), WasmEdge_Proposal_Threads);
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

    Owned<WasmEdge_LoaderContext, WasmEdge_LoaderDelete> loader(
        WasmEdge_LoaderCreate(config.get()), WasmEdge_LoaderDelete);
    if (!loader) return fail(*session, "Cannot create Wasm loader.");
    WasmEdge_ASTModuleContext *parsed = nullptr;
    const auto loaded = WasmEdge_LoaderParseFromFile(loader.get(), &parsed, module_path);
    Owned<WasmEdge_ASTModuleContext, WasmEdge_ASTModuleDelete> module(parsed, WasmEdge_ASTModuleDelete);
    if (!WasmEdge_ResultOK(loaded)) return fail(*session, WasmEdge_ResultGetMessage(loaded));
    std::vector<const WasmEdge_ImportTypeContext *> imports(WasmEdge_ASTModuleListImportsLength(module.get()));
    WasmEdge_ASTModuleListImports(module.get(), imports.data(), static_cast<uint32_t>(imports.size()));
    for (const auto *import : imports) {
      if (WasmEdge_ImportTypeGetExternalType(import) != WasmEdge_ExternalType_Memory) continue;
      const auto *type = WasmEdge_ImportTypeGetMemoryType(module.get(), import);
      if (WasmEdge_LimitIsShared(WasmEdge_MemoryTypeGetLimit(type))) {
        if (text(WasmEdge_ImportTypeGetModuleName(import)) != "env" ||
            text(WasmEdge_ImportTypeGetExternalName(import)) != "memory") {
          return fail(*session, "WASI threads require the env.memory shared import.");
        }
        ThreadGroup group(*session, config.get(), module.get(), wasi.get(), type, cost_limit);
        return group.run();
      }
    }

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
        WasmEdge_VMAsyncRunWasmFromASTModule(
            vm.get(), module.get(), WasmEdge_StringWrap("_start", 6), nullptr, 0),
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
