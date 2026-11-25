import {
  WASI, File, Directory, OpenFile, PreopenDirectory, ConsoleStdout,
} from "../native/web/node_modules/@bjorn3/browser_wasi_shim/dist/index.js";

export class OutputLines {
  constructor(emit) {
    this.emit = emit;
    this.decoder = new TextDecoder();
    this.pending = "";
  }
  write(bytes) {
    this.pending += this.decoder.decode(bytes, { stream: true });
    for (;;) {
      const end = this.pending.indexOf("\n");
      if (end < 0) break;
      const line = this.pending.slice(0, end);
      this.emit(line.endsWith("\r") ? line.slice(0, -1) : line);
      this.pending = this.pending.slice(end + 1);
    }
  }
  flush() {
    this.pending += this.decoder.decode();
    if (this.pending.length) this.emit(this.pending);
    this.pending = "";
  }
}

export function relativePath(path) {
  if (typeof path !== "string" || !path.length || path.includes("\0") ||
      path.startsWith("/") || path.includes("\\") ||
      path.split("/").some((part) => !part.length || part === "." || part === "..")) {
    throw new Error(`Invalid project-relative path: ${path}`);
  }
  return path;
}

export function projectTree(files) {
  const root = new Map();
  for (const { path, bytes, directory: isDirectory } of files) {
    const parts = relativePath(path).split("/");
    let parent = root;
    for (const name of isDirectory ? parts : parts.slice(0, -1)) {
      if (!parent.has(name)) parent.set(name, new Directory(new Map()));
      const directory = parent.get(name);
      if (!(directory instanceof Directory)) throw new Error(`Not a directory: ${path}`);
      parent = directory.contents;
    }
    if (isDirectory) continue;
    const name = parts.at(-1);
    if (parent.has(name)) throw new Error(`Duplicate project file: ${path}`);
    parent.set(name, new File(new Uint8Array(bytes)));
  }
  return root;
}

export function collectFiles(tree, prefix = "") {
  const files = [];
  for (const [name, entry] of tree) {
    const path = prefix + name;
    if (entry instanceof Directory) {
      files.push({ path, directory: true });
      files.push(...collectFiles(entry.contents, `${path}/`));
    }
    else if (entry instanceof File) files.push({ path, bytes: entry.data.slice() });
  }
  return files;
}

export async function executeWasm(bytes, files, emit) {
  const tree = projectTree(files);
  const stdout = new OutputLines((text) => emit({ kind: "stdout", text }));
  const stderr = new OutputLines((text) => emit({ kind: "stderr", text }));
  const stdin = tree.get("input.txt");
  const wasi = new WASI(["program.wasm"], ["PWD=/project"], [
    new OpenFile(stdin instanceof File ? stdin : new File([])),
    new ConsoleStdout((chunk) => stdout.write(chunk)),
    new ConsoleStdout((chunk) => stderr.write(chunk)),
    new PreopenDirectory("/project", tree),
    new PreopenDirectory(".", tree),
  ], { debug: false });
  let exitCode;
  try {
    const { instance } = await WebAssembly.instantiate(bytes, {
      wasi_snapshot_preview1: wasi.wasiImport,
    });
    exitCode = wasi.start(instance);
  } catch (error) {
    stderr.write(new TextEncoder().encode(`WebAssembly runtime: ${error}\n`));
    exitCode = error instanceof WebAssembly.RuntimeError ? 134 : 127;
  } finally {
    stdout.flush();
    stderr.flush();
  }
  return { exitCode, files: collectFiles(tree) };
}
