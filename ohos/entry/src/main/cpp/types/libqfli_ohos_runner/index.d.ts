/** The opaque napi_external returned by create. */
export type RunnerHandle = object;

export interface RunnerEvent {
  kind: 'stdout' | 'stderr' | 'exit';
  text?: string;
  exitCode?: number;
}

export interface RunnerOptions {
  toolchainRoot: string;
  /** Legacy native-executable options are ignored by the WASI interpreter backend. */
  executorPath?: string;
  compilerPath?: string;
  linkerPath?: string;
  runtimeDirectory?: string;
  onEvent: (event: RunnerEvent) => void;
}

export interface AnalysisDocument {
  path: string;
  text: string;
}

interface QfliOhosRunner {
  create(options: RunnerOptions): RunnerHandle | null;
  run(handle: RunnerHandle, projectPath: string, entryFile: string,
    sources: string[], temporaryDirectory: string): boolean;
  /** Syntax/type-check exact unsaved buffers; emits structured UTF-8 byte ranges. */
  analyze(handle: RunnerHandle, projectPath: string, activeFile: string,
    isCpp: boolean, documents: AnalysisDocument[], cacheDirectory: string): boolean;
  cancel(handle: RunnerHandle): void;
  destroy(handle: RunnerHandle): void;
}

declare const qfliRunner: QfliOhosRunner;
export default qfliRunner;
