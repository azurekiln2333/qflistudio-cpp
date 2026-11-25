import { executeWasm, OutputLines, relativePath } from "./forge-wasi.js";

let active = false;
self.onmessage = async ({ data }) => {
  if (active) return;
  active = true;
  const { runId, entryFile, files } = data;
  const emit = (event) => self.postMessage({ runId, ...event });
  const diagnostics = new OutputLines((text) => emit({ kind: "stderr", text }));
  try {
    if (typeof runId !== "string" || !Array.isArray(files)) throw new Error("Invalid run request");
    relativePath(entryFile);
    // Every accepted run gets a new worker and compiler filesystem.
    const { default: createCompiler } = await import("./toolchain/qfli-compiler.js");
    const compiler = await createCompiler({
      locateFile: (path) => new URL(`toolchain/${path}`, import.meta.url).href,
      print: (text) => emit({ kind: "stderr", text }),
      printErr: (text) => emit({ kind: "stderr", text }),
    });
    compiler.FS.mkdirTree("/project");
    compiler.FS.mkdirTree("/output");
    for (const { path, bytes, directory } of files) {
      const name = relativePath(path);
      const fullPath = `/project/${name}`;
      if (directory) {
        compiler.FS.mkdirTree(fullPath);
        continue;
      }
      compiler.FS.mkdirTree(fullPath.slice(0, fullPath.lastIndexOf("/")));
      compiler.FS.writeFile(fullPath, new Uint8Array(bytes));
    }
    const sources = files.filter((entry) => !entry.directory).map(({ path }) => relativePath(path))
      .filter((path) => /\.(c|cpp|cc|cxx)$/i.test(path))
      .sort((a, b) => a === entryFile ? -1 : b === entryFile ? 1 : a.localeCompare(b));
    if (!sources.includes(entryFile)) throw new Error("Entry file is not a project translation unit");
    const allocated = [];
    const string = (value) => {
      const size = compiler.lengthBytesUTF8(value) + 1;
      const pointer = compiler._malloc(size);
      if (!pointer) throw new Error("Compiler allocation failed");
      allocated.push(pointer);
      compiler.stringToUTF8(value, pointer, size);
      return pointer;
    };
    const pointers = sources.map((path) => string(`/project/${path}`));
    const array = compiler._malloc(pointers.length * 4);
    if (!array) throw new Error("Compiler source allocation failed");
    allocated.push(array);
    new Uint32Array(compiler.HEAPU8.buffer, array, pointers.length).set(pointers);
    let status;
    try {
      status = compiler.ccall("qfli_web_compile", "number",
        ["string", "string", "number", "number"], ["/project", "/output", array, pointers.length]);
    } finally {
      for (const pointer of allocated) compiler._free(pointer);
    }
    if (status !== 0) {
      emit({ kind: "exit", exitCode: status });
      return;
    }
    const module = compiler.FS.readFile("/output/program.wasm");
    const result = await executeWasm(module, files, emit);
    emit({ kind: "files", files: result.files });
    emit({ kind: "exit", exitCode: result.exitCode });
  } catch (error) {
    diagnostics.write(new TextEncoder().encode(`Browser compiler unavailable: ${error}\n`));
    diagnostics.flush();
    emit({ kind: "exit", exitCode: 127 });
  }
};
