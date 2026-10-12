import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { OutputLines, relativePath } from '../../../../web/forge-wasi.js';

const workerUrl = new URL('../../../../web/forge-worker.js', import.meta.url);
const code = fs.readFileSync(workerUrl, 'utf8');
const bytes = (text) => new TextEncoder().encode(text);
const files = [
  { path: 'main.c', bytes: bytes('int main(void){return 1;}') },
  { path: 'main2.c', bytes: bytes('int main(void){return 2;}') },
  { path: 'helper.c', bytes: bytes('int answer(void){return 42;}') },
  { path: 'include/helper.h', bytes: bytes('int answer(void);') },
  { path: 'input.txt', bytes: bytes('42') },
  { path: 'assets', directory: true },
  { path: 'assets/data.bin', bytes: new Uint8Array([0, 255, 13]) },
];

async function run(payload) {
  const events = [];
  const uploaded = new Map();
  const state = { compiled: null, runtimeFiles: null };
  const context = vm.createContext({ self: { postMessage: (event) => events.push(event) }, TextEncoder, TextDecoder, Uint8Array, Uint32Array, URL });
  const memory = new Uint8Array(8192);
  const strings = new Map();
  let offset = 8;
  const compiler = {
    FS: { mkdirTree() {}, writeFile: (path, data) => uploaded.set(path, data), readFile: () => new Uint8Array([0]) },
    HEAPU8: memory,
    lengthBytesUTF8: (value) => bytes(value).length,
    _malloc: (length) => { const result = offset; offset += (length + 3) & ~3; return result; },
    _free() {},
    stringToUTF8: (value, pointer) => strings.set(pointer, value),
    ccall: (_name, _returnType, _argumentTypes, args) => {
      state.compiled = [...new Uint32Array(memory.buffer, args[2], args[3])].map((pointer) => strings.get(pointer));
      return 0;
    },
  };
  const wasi = new vm.SyntheticModule(['OutputLines', 'relativePath', 'executeWasm'], function () {
    this.setExport('OutputLines', OutputLines);
    this.setExport('relativePath', relativePath);
    this.setExport('executeWasm', async (_module, runtimeFiles) => { state.runtimeFiles = runtimeFiles; return { exitCode: 0, files: runtimeFiles }; });
  }, { context });
  const toolchain = new vm.SyntheticModule(['default'], function () { this.setExport('default', async () => compiler); }, { context });
  await toolchain.link(() => { throw new Error('Unexpected compiler import'); });
  await toolchain.evaluate();
  const worker = new vm.SourceTextModule(code, {
    context,
    identifier: fileURLToPath(workerUrl),
    initializeImportMeta: (meta) => { meta.url = workerUrl.href; },
    importModuleDynamically: async () => toolchain,
  });
  await worker.link((specifier) => {
    assert.equal(specifier, './forge-wasi.js');
    return wasi;
  });
  await worker.evaluate();
  await context.self.onmessage({ data: { runId: 'review', entryFile: 'main2.c', files, ...payload } });
  return { events, uploaded, ...state };
}

const explicit = await run({ sources: ['main2.c', 'helper.c'] });
assert.deepEqual(explicit.compiled, ['/project/main2.c', '/project/helper.c']);
assert.equal(explicit.runtimeFiles, files);
assert.equal(explicit.uploaded.size, files.filter((entry) => !entry.directory).length);
assert.ok(explicit.uploaded.has('/project/main.c'));
assert.ok(explicit.uploaded.has('/project/include/helper.h'));
assert.ok(explicit.uploaded.has('/project/input.txt'));
assert.equal(explicit.events.find((event) => event.kind === 'files').files, files);
assert.equal(explicit.events.at(-1).exitCode, 0);
console.log('PASS explicit compilation selection preserves all uploaded/runtime/writeback files');

const legacy = await run({});
assert.equal(legacy.compiled.length, 3);
assert.equal(legacy.events.at(-1).exitCode, 0);
console.log('PASS omitted sources preserves legacy discovery');

for (const [name, sources] of [
  ['empty', []], ['null', null], ['non-list', 'main2.c'], ['non-string', [42]],
  ['missing entry', ['helper.c']], ['outside project', ['main2.c', '../helper.c']],
  ['unuploaded file', ['main2.c', 'other.c']], ['header', ['main2.c', 'include/helper.h']],
]) {
  const result = await run({ sources });
  assert.equal(result.compiled, null, name);
  assert.equal(result.runtimeFiles, null, name);
  assert.equal(result.events.at(-1).exitCode, 127, name);
  console.log(`PASS rejects ${name} without compiling or executing`);
}
