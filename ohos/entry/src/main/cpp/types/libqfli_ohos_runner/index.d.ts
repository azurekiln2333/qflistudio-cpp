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

interface QfliOhosRunner {
  create(options: RunnerOptions): RunnerHandle | null;
  run(handle: RunnerHandle, projectPath: string, entryFile: string,
    sources: string[], temporaryDirectory: string): boolean;
  cancel(handle: RunnerHandle): void;
  destroy(handle: RunnerHandle): void;
}

declare const qfliRunner: QfliOhosRunner;
export default qfliRunner;
