/*
 * ArkTS 接线：把 OHOS 原生编译运行桥挂到 Flutter 的 MethodChannel 上。
 *
 * 为什么需要这一层：Flutter 的 Dart 代码不能直接调 NAPI，链路必须是
 *
 *   Dart → MethodChannel(qfli_forge/native) → ArkTS（本文件）
 *        → libqfli_ohos_runner.so → LLVM 22 / WASI 33 / Wasm 解释执行
 *
 * 通道协议与 Android 的 NativeCompilerBridge.kt 完全一致（方法名、参数、
 * 事件形状都相同），所以 Dart 侧 lib/native_clang_runner.dart 无需任何改动，
 * 两个平台共用同一份上层逻辑。
 *
 * 与旧版 QfliCNative.ets 的区别：旧版接的是 native/src 里的 picoc（只能解释 C），
 * 本文件接的是 LLVM 编译运行桥；平台能力以 App 内验证结果为准。
 *
 * 用法（在 EntryAbility.ets 的 onWindowStageCreate 之后 / Flutter 引擎起来时）：
 *
 *   registerQfliNativeChannel(flutterEngine);
 */
import qfliRunner, { RunnerHandle, RunnerOptions, RunnerEvent, AnalysisDocument } from 'libqfli_ohos_runner.so';
import {
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
  EventChannel,
  EventSink,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { bundleManager } from '@kit.AbilityKit';
import zlib from '@ohos.zlib';
import fileHash from '@ohos.file.hash';

/** 与 Dart 侧 RunnerService 约定的通道名，和 Android 保持一致。 */
const CHANNEL_METHODS = 'qfli_forge/native';
const CHANNEL_EVENTS = 'qfli_forge/native/events';

/** 工具链压缩包在 resources 里的位置。
 *  名字必须与 package-ohos-portable.ps1 的资源产物一致。
 */
const TOOLCHAIN_ARCHIVE = 'qfli_toolchain/ohos-wasi.zip';

const REQUIRED_RESOURCES: string[] = [
  'share/wasi-sysroot/include/wasm32-wasip1/stdio.h',
  'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/vector',
  'share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/stdexcept',
  'share/wasi-sysroot/lib/wasm32-wasip1/crt1-command.o',
  'share/wasi-sysroot/lib/wasm32-wasip1/libc.a',
  'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++.a',
  'share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++abi.a',
  'share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a',
  'share/wasi-sysroot/lib/wasm32-wasip1/libsetjmp.a',
  'share/wasi-sysroot/lib/wasm32-wasip1/libwasi-emulated-process-clocks.a',
  'lib/clang/22/include/stddef.h',
  'lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a',
  'share/wasi-sysroot/include/wasm32-wasip1-threads/stdio.h',
  'share/wasi-sysroot/include/wasm32-wasip1-threads/pthread.h',
  'share/wasi-sysroot/include/wasm32-wasip1-threads/eh/c++/v1/vector',
  'share/wasi-sysroot/include/wasm32-wasip1-threads/eh/c++/v1/stdexcept',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/crt1-command.o',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/libc.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/libpthread.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libc++abi.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/eh/libunwind.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/libsetjmp.a',
  'share/wasi-sysroot/lib/wasm32-wasip1-threads/libwasi-emulated-process-clocks.a',
  'lib/clang/22/lib/wasm32-unknown-wasip1-threads/libclang_rt.builtins.a',
];

interface ResourceDigest {
  path: string;
  sha256: string;
  size: number;
}

interface ToolchainManifest {
  formatVersion: number;
  llvmVersion: string;
  llvmCommit: string;
  wasiSdkVersion: string;
  runtimeCommit: string;
  targetTriple: string;
  supportedTargets: string[];
  threading: string;
  maxWorkerThreads: number;
  runtime: string;
  execution: string;
  jit: boolean;
  resources: ResourceDigest[];
}

/** 一个正在进行的运行。 */
class ActiveRun {
  runId: string;
  handle: RunnerHandle | null = null;
  cancelled = false;
  /** destroy 必须在 exit 事件之后调用，这里记录状态防止过早释放。 */
  finished = false;
  stdoutTail = '';
  stderrTail = '';

  constructor(runId: string) {
    this.runId = runId;
  }
}

/** 安全的存在性检查：accessSync 在路径非法时会抛而不是返回 false。 */
function exists(path: string): boolean {
  try {
    return fs.accessSync(path);
  } catch (error) {
    return false;
  }
}

/**
 * 把压缩包里的工具链解到 App 私有目录，返回根目录。
 *
 * 注意事项：
 *   - zlib.decompressFile 是异步的（Promise），所以整个准备过程也是异步的。
 *   - App 每次升级后要重新解压，用版本号和安装时间做目录名。
 *   - 目录不完整就整个重来，避免半截解压留下坏文件。
 */
async function prepareToolchain(context: common.Context): Promise<string> {
  const root = `${context.filesDir}/forge-toolchain/ohos-wasi/${toolchainVersion()}`;
  const ready = `${root}/.ready`;

  if (isToolchainReady(root)) {
    try {
      await verifyToolchainResources(root);
      return root;
    } catch (error) {
      const failure = error as Error;
      console.error(`QFLI_OHOS_TOOLCHAIN_CACHE_INVALID ${failure.message}`);
    }
  }

  // 上一轮可能只解了一半；整目录删掉重来，不要试图逐文件补救。
  try {
    if (exists(root)) {
      fs.rmdirSync(root);
    }
    fs.mkdirSync(root, true);
    const archive = `${context.cacheDir}/qfli-ohos-wasi.zip`;
    try {
      await copyToolchainArchive(context, archive);
      await verifyToolchainArchive(context, archive);
      await zlib.decompressFile(archive, root);
    } finally {
      if (exists(archive)) {
        fs.unlinkSync(archive);
      }
    }
    if (!hasToolchainFiles(root)) {
      throw new Error('解压后的工具链文件或清单不完整。');
    }
    await verifyToolchainResources(root);
    writeText(ready, 'ready\n');
  } catch (error) {
    // 解压失败就抛出，由调用方转成 available:false（保留回退路径）。
    const failure = error as Error;
    throw new Error(`工具链解压失败：${failure.message}`);
  }
  return root;
}

/** 当前 App 版本号，用于隔离不同版本的解压目录。 */
function toolchainVersion(): string {
  try {
    const info = bundleManager.getBundleInfoForSelfSync(0);
    // Reinstalling a changed HAP can preserve versionName/versionCode.
    return `${info.versionCode}-${info.updateTime}-wasi33-layout2`;
  } catch (error) {
    // 拿不到版本号不影响使用，退化成固定目录。
    return '0-wasi33-layout2';
  }
}

/** The expected digest is a small ASCII resource protected by the signed HAP. */
async function verifyToolchainArchive(context: common.Context, archive: string): Promise<void> {
  const data = await context.resourceManager.getRawFileContent(`${TOOLCHAIN_ARCHIVE}.sha256`);
  let expected = '';
  for (let index = 0; index < data.length; index++) {
    expected += String.fromCharCode(data[index]);
  }
  expected = expected.trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(expected) ||
      (await fileHash.hash(archive, 'sha256')).toLowerCase() !== expected) {
    throw new Error('WASI 工具链资源包 SHA256 校验失败。');
  }
}

/** Stream the stored raw ZIP from its HAP slice without allocating the whole archive. */
async function copyToolchainArchive(context: common.Context, archive: string): Promise<void> {
  const raw = await context.resourceManager.getRawFd(TOOLCHAIN_ARCHIVE);
  try {
    const file = fs.openSync(archive, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      const buffer = new ArrayBuffer(1024 * 1024);
      let copied = 0;
      while (copied < raw.length) {
        fs.lseek(raw.fd, raw.offset + copied, fs.WhenceType.SEEK_SET);
        const length = await fs.read(raw.fd, buffer, { length: Math.min(buffer.byteLength, raw.length - copied) });
        if (length <= 0) {
          throw new Error('工具链资源读取提前结束。');
        }
        let written = 0;
        while (written < length) {
          const chunk = buffer.slice(written, length);
          const count = await fs.write(file.fd, chunk);
          if (count <= 0) {
            throw new Error('工具链资源写入失败。');
          }
          written += count;
        }
        copied += length;
      }
    } finally {
      fs.closeSync(file);
    }
  } finally {
    await context.resourceManager.closeRawFd(TOOLCHAIN_ARCHIVE);
  }
}

/** 写入一个小文本文件（fs 没有路径版的 writeTextSync，需要自己开关 fd）。 */
function writeText(path: string, text: string): void {
  const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, text);
  } finally {
    fs.closeSync(file);
  }
}

/** 校验工具链完整性：标记文件存在且关键二进制都在。 */
function isToolchainReady(root: string): boolean {
  return exists(`${root}/.ready`) && hasToolchainFiles(root);
}

function hasToolchainFiles(root: string): boolean {
  try {
    const manifest = JSON.parse(fs.readTextSync(`${root}/toolchain.json`)) as ToolchainManifest;
    if (manifest.formatVersion !== 2 || manifest.llvmVersion !== '22.1.0' ||
        manifest.llvmCommit !== '4434dabb69916856b824f68a64b029c67175e532' ||
        manifest.wasiSdkVersion !== '33.0' ||
        manifest.runtimeCommit !== '845df599e7b71c98b0c77990c3aa3a10022bbaae' ||
        manifest.targetTriple !== 'wasm32-unknown-wasip1' ||
        !Array.isArray(manifest.supportedTargets) || manifest.supportedTargets.length !== 2 ||
        manifest.supportedTargets.indexOf('wasm32-unknown-wasip1') < 0 ||
        manifest.supportedTargets.indexOf('wasm32-unknown-wasip1-threads') < 0 ||
        manifest.threading !== 'wasi-threads' || manifest.maxWorkerThreads !== 32 ||
        manifest.runtime !== 'wasmedge-interpreter' || manifest.execution !== 'interpreter' ||
        manifest.jit !== false || !Array.isArray(manifest.resources) ||
        manifest.resources.length !== REQUIRED_RESOURCES.length) {
      return false;
    }
    for (const required of REQUIRED_RESOURCES) {
      const resource = manifest.resources.find((item: ResourceDigest) => item.path === required);
      if (resource === undefined || !/^[0-9a-f]{64}$/.test(resource.sha256) || resource.size <= 0 ||
          !exists(`${root}/${required}`)) {
        return false;
      }
      const information = fs.statSync(`${root}/${required}`);
      if (!information.isFile() || information.size !== resource.size) {
        return false;
      }
    }
    return true;
  } catch (error) {
    return false;
  }
}

/** Check cached key headers/libraries once per app session, before using .ready. */
async function verifyToolchainResources(root: string): Promise<void> {
  const manifest = JSON.parse(fs.readTextSync(`${root}/toolchain.json`)) as ToolchainManifest;
  for (const resource of manifest.resources) {
    if ((await fileHash.hash(`${root}/${resource.path}`, 'sha256')).toLowerCase() !== resource.sha256) {
      throw new Error(`WASI 工具链文件 SHA256 校验失败：${resource.path}`);
    }
  }
}

/**
 * 一次只允许一个运行，与 Android 的 runner_busy 语义一致。
 */
let activeRun: ActiveRun | null = null;
let eventSink: EventSink | null = null;
let toolchainRoot: string | null = null;

/** 把原生事件派发到 Flutter 的 EventChannel 上，带上 runId 让 Dart 端过滤。 */
function emit(runId: string, event: RunnerEvent): void {
  if (eventSink === null) {
    return;
  }
  if (event.kind === 'exit') {
    eventSink.success({
      'runId': runId,
      'kind': 'exit',
      'exitCode': event.exitCode ?? 127,
    });
    return;
  }
  eventSink.success({
    'runId': runId,
    'kind': event.kind,
    'text': event.text ?? '',
  });
}

/** 把原生返回的输出按行拆分，和 Android 的 readLine 行为对齐。 */
function emitLines(run: ActiveRun, kind: 'stdout' | 'stderr', text: string): void {
  const buffered = (kind === 'stdout' ? run.stdoutTail : run.stderrTail) + text;
  const lines = buffered.split('\n');
  const tail = lines.pop() ?? '';
  if (kind === 'stdout') {
    run.stdoutTail = tail;
  } else {
    run.stderrTail = tail;
  }
  for (const line of lines) {
    emit(run.runId, { kind, text: line.endsWith('\r') ? line.slice(0, -1) : line });
  }
}

function finishRun(run: ActiveRun, exitCode: number): void {
  if (run.finished) {
    return;
  }
  run.finished = true;
  if (run.stdoutTail.length > 0) {
    emit(run.runId, { kind: 'stdout', text: run.stdoutTail });
    run.stdoutTail = '';
  }
  if (run.stderrTail.length > 0) {
    emit(run.runId, { kind: 'stderr', text: run.stderrTail });
    run.stderrTail = '';
  }
  emit(run.runId, { kind: 'exit', exitCode });
  releaseRun(run);
}

/** Only older callers which omit sources use full project discovery. */
function discoverSources(projectPath: string): string[] {
  const names = fs.listFileSync(projectPath, { recursion: true });
  const sources: string[] = [];
  for (const name of names) {
    const path = `${projectPath.replace(/\/+$/, '')}/${name.replace(/^\/+/, '')}`;
    if (/\.(c|cpp|cc|cxx)$/i.test(path) && fs.statSync(path).isFile()) {
      sources.push(path);
    }
  }
  return sources.sort();
}

/** start：接受一次运行请求，立即返回 available，进度走事件通道。 */
function start(call: MethodCall, result: MethodResult, context: common.Context): void {
  const runId = call.argument('runId') as string | undefined;
  const type = call.argument('type') as string | undefined;
  const projectPath = call.argument('projectPath') as string | undefined;
  const entryFile = call.argument('entryFile') as string | undefined;

  if (
    typeof runId !== 'string' || runId.length === 0 ||
    (type !== 'c' && type !== 'cpp') ||
    typeof projectPath !== 'string' || !projectPath.startsWith('/') || projectPath.indexOf('\0') >= 0 ||
    typeof entryFile !== 'string' || !entryFile.startsWith('/') || entryFile.indexOf('\0') >= 0
  ) {
    result.error('invalid_run', '编译运行参数不完整。', null);
    return;
  }

  let sources: string[];
  try {
    if (call.hasArgument('sources')) {
      const selected = call.argument('sources') as string[] | null;
      if (!Array.isArray(selected) || selected.length === 0) {
        result.error('invalid_run', '选择的源文件列表无效或为空。', null);
        return;
      }
      sources = selected;
    } else {
      sources = discoverSources(projectPath);
    }
    for (const source of sources) {
      if (typeof source !== 'string' || !source.startsWith('/') || source.indexOf('\0') >= 0) {
        result.error('invalid_run', '选择的源文件路径无效。', null);
        return;
      }
    }
    if (sources.length === 0) {
      result.error('invalid_run', '项目中没有可编译的源文件。', null);
      return;
    }
  } catch (error) {
    const failure = error as Error;
    result.error('invalid_run', `无法读取项目源文件：${failure.message}`, null);
    return;
  }

  if (eventSink === null) {
    result.error('missing_listener', '编译运行输出通道未连接。', null);
    return;
  }
  if (activeRun !== null) {
    result.error('runner_busy', '已有程序正在编译或运行。', null);
    return;
  }

  // 工具链首次使用需要解压（可能几十秒）。整个准备过程异步进行，
  // 避免阻塞 ArkTS 主线程；结果回来之前先把 run 占住，防止并发 start。
  const run = new ActiveRun(runId);
  activeRun = run;
  startAfterPrepare(run, result, context, (handle: RunnerHandle) =>
    qfliRunner.run(handle, projectPath, entryFile, sources, context.cacheDir) as boolean);
}

/**
 * 只分析传入的未保存文档，返回结构化诊断；与运行共享工具链占用和清理。
 */
function analyzeStart(call: MethodCall, result: MethodResult, context: common.Context): void {
  const runId = call.argument('runId') as string | undefined;
  const projectPath = call.argument('projectPath') as string | undefined;
  const activeFile = call.argument('activeFilePath') as string | undefined;
  const language = call.argument('language') as string | undefined;
  const raw = call.argument('documents') as Map<string, Object>[] | null;
  if (typeof runId !== 'string' || runId.length === 0 ||
      typeof projectPath !== 'string' || !projectPath.startsWith('/') || projectPath.indexOf('\0') >= 0 ||
      typeof activeFile !== 'string' || !activeFile.startsWith('/') || activeFile.indexOf('\0') >= 0 ||
      (language !== 'c' && language !== 'cpp') ||
      !Array.isArray(raw) || raw.length === 0 || raw.length > 64) {
    result.error('invalid_analysis', '语法检查参数无效。', null);
    return;
  }
  const documents: AnalysisDocument[] = [];
  let units = 0;
  for (const item of raw) {
    if (!(item instanceof Map)) {
      result.error('invalid_analysis', '语法检查文档无效。', null);
      return;
    }
    const path = item.get('path') as string;
    const text = item.get('text') as string;
    if (typeof path !== 'string' || !path.startsWith('/') || path.indexOf('\0') >= 0 ||
        typeof text !== 'string' || text.indexOf('\0') >= 0) {
      result.error('invalid_analysis', '语法检查文档无效。', null);
      return;
    }
    units += text.length;
    if (units > 4 * 1024 * 1024) {
      result.error('invalid_analysis', '语法检查文档超过大小限制。', null);
      return;
    }
    documents.push({ path, text });
  }
  if (eventSink === null) {
    result.error('missing_listener', '语法检查通道未连接。', null);
    return;
  }
  if (activeRun !== null) {
    result.error('runner_busy', '编译工具链正在使用中。', null);
    return;
  }
  const run = new ActiveRun(runId);
  activeRun = run;
  startAfterPrepare(run, result, context, (handle: RunnerHandle) =>
    qfliRunner.analyze(handle, projectPath, activeFile, language === 'cpp', documents, context.cacheDir) as boolean);
}

/**
 * 抢占一次运行，等待工具链准备/创建句柄后再执行 [launch]。
 *
 * [launch] 拿到的句柄已经被记录在 [run] 上，因此取消路径无需区分 start 与
 * analyzeStart：两者共享同一套事件、exit 和 destroy 收尾。
 */
async function startAfterPrepare(
  run: ActiveRun,
  result: MethodResult,
  context: common.Context,
  launch: (handle: RunnerHandle) => boolean,
): Promise<void> {
  // 工具链准备可能失败（资源缺失/解压失败）。这种情况按 available:false 处理，
  // 让 Dart 侧保留既有回退路径，而不是报一个无法恢复的错误。
  try {
    if (toolchainRoot === null || !isToolchainReady(toolchainRoot)) {
      toolchainRoot = await prepareToolchain(context);
    }
    if (!isToolchainReady(toolchainRoot)) {
      activeRun = null;
      result.success({ 'available': false });
      return;
    }
  } catch (error) {
    if (run.cancelled) {
      result.success({ 'available': true });
      finishRun(run, 130);
      return;
    }
    const failure = error as Error;
    console.error(`QFLI_OHOS_TOOLCHAIN_PREPARE_FAILED ${failure.message}`);
    activeRun = null;
    result.success({ 'available': false });
    return;
  }

  // 解压期间可能已经收到 cancel，这时直接报成已取消的运行。
  if (run.cancelled) {
    result.success({ 'available': true });
    finishRun(run, 130);
    return;
  }

  try {
    const handle = qfliRunner.create({
      toolchainRoot,
      onEvent: (event: RunnerEvent) => {
        if (run.finished) {
          return;
        }
        if (event.kind === 'exit') {
          finishRun(run, event.exitCode ?? 127);
        } else {
          emitLines(run, event.kind, event.text ?? '');
        }
      },
    } as RunnerOptions);
    if (handle === null || handle === undefined) {
      throw new Error('原生运行时初始化失败（工具链权限或句柄创建失败）。');
    }
    run.handle = handle;
  } catch (error) {
    const failure = error as Error;
    activeRun = null;
    result.error('QFLI_NATIVE_FAILED', failure.message, null);
    return;
  }

  result.success({ 'available': true });

  try {
    const accepted = launch(run.handle as RunnerHandle);
    if (!accepted) {
      emit(run.runId, { kind: 'stderr', text: '原生桥拒绝了这次请求。' });
      finishRun(run, 127);
    }
  } catch (error) {
    const failure = error as Error;
    emit(run.runId, { kind: 'stderr', text: failure.message });
    finishRun(run, 127);
  }
}

/** cancel：请求停止当前运行。 */
function cancel(call: MethodCall): void {
  const runId = call.argument('runId') as string | undefined;
  const run = activeRun;
  if (run === null || run.runId !== runId) {
    return;
  }
  run.cancelled = true;
  if (run.handle === null) {
    return;
  }
  try {
    qfliRunner.cancel(run.handle);
  } catch (error) {
    // 取消本身失败不该再抛，Dart 侧会等 exit 事件。
  }
  // 不能在这里 releaseRun：后台线程还在跑，它仍会回调 onEvent。
  // 原生侧保证取消后一定会发出 exit（exitCode 130），那时才释放句柄。
}

/** 释放一次运行的句柄并允许下一次 start。 */
function releaseRun(run: ActiveRun): void {
  if (run.handle !== null) {
    try {
      qfliRunner.destroy(run.handle);
    } catch (error) {
      // 句柄已经失效，忽略。
    }
    run.handle = null;
  }
  if (activeRun === run) {
    activeRun = null;
  }
}

/** 把原生编译运行后端注册到 Flutter 引擎上。 */
export function registerQfliNativeChannel(
  flutterEngine: FlutterEngine,
  context: common.Context,
): void {
  const messenger = flutterEngine.dartExecutor.getBinaryMessenger();

  const methods = new MethodChannel(messenger, CHANNEL_METHODS);
  methods.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      if (call.method === 'start') {
        start(call, result, context);
        return;
      }
      if (call.method === 'analyzeStart') {
        analyzeStart(call, result, context);
        return;
      }
      if (call.method === 'cancel') {
        cancel(call);
        result.success(null);
        return;
      }
      result.notImplemented();
    },
  });

  const events = new EventChannel(messenger, CHANNEL_EVENTS);
  events.setStreamHandler({
    onListen(args: object, sink: EventSink): void {
      eventSink = sink;
    },
    onCancel(args: object): void {
      eventSink = null;
      const run = activeRun;
      if (run !== null) {
        run.cancelled = true;
      }
      if (run !== null && run.handle !== null) {
        try {
          qfliRunner.cancel(run.handle);
        } catch (error) {
          // 同上：让 exit 事件来收尾。
        }
      }
    },
  });
}
