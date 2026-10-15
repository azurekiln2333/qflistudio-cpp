/* Exercise the actual ArkTS WASI-resource preparation and start path.
 * Usage: node ohos-arkts-native-path-regression.cjs <typescript.js>
 * The historical filename is retained for existing validation commands.
 */
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
if (!process.argv[2]) throw new Error('Pass the OHOS build tools typescript.js path.');
const ts = require(path.resolve(process.argv[2]));
const repo = path.resolve(__dirname, '../../..');
const file = path.join(repo, 'ohos/entry/src/main/ets/plugins/QfliCNative.ets');
const source = fs.readFileSync(file, 'utf8');
const compiled = ts.transpileModule(source + '\nexport { start, cancel };', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  reportDiagnostics: true,
});
assert.equal(compiled.diagnostics.filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);
const resources = [
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
const sha256 = data => crypto.createHash('sha256').update(data).digest('hex');
const root = '/files/forge-toolchain/ohos-wasi/1-1792074309446-wasi33-layout2';
const fixture = new Map(resources.map(name => [name, Buffer.from(`verified fixture ${name}`)]));
const manifest = {
  formatVersion: 2, llvmVersion: '22.1.0', llvmCommit: '4434dabb69916856b824f68a64b029c67175e532',
  wasiSdkVersion: '33.0', runtimeCommit: '845df599e7b71c98b0c77990c3aa3a10022bbaae',
  targetTriple: 'wasm32-unknown-wasip1', runtime: 'wasmedge-interpreter', execution: 'interpreter', jit: false,
  supportedTargets: ['wasm32-unknown-wasip1', 'wasm32-unknown-wasip1-threads'],
  threading: 'wasi-threads', maxWorkerThreads: 32,
  resources: resources.map(name => ({ path: name, size: fixture.get(name).length, sha256: sha256(fixture.get(name)) })),
};

async function scenario(options = {}) {
  const calls = [], replies = [], errors = [], logs = [], events = [];
  const files = new Map(), descriptors = new Map();
  const archive = Buffer.from('a signed resource ZIP fixture');
  const hapSlice = Buffer.concat([Buffer.alloc(17, 88), archive, Buffer.alloc(23, 99)]);
  let cursor = 0, nextFd = 101, extractionCount = 0, rawClosed = 0;
  function install() {
    for (const [name, bytes] of fixture) files.set(`${root}/${name}`, Buffer.from(bytes));
    files.set(`${root}/toolchain.json`, Buffer.from(JSON.stringify(manifest)));
  }
  if (options.cached !== false) {
    install();
    files.set(`${root}/.ready`, Buffer.from('ready\n'));
    if (options.staleManifest) {
      files.set(`${root}/toolchain.json`, Buffer.from(JSON.stringify({ ...manifest, ...options.staleManifest })));
    }
    if (options.corruptCache) files.get(`${root}/${resources[1]}`)[0] ^= 1;
  }
  const io = {
    OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 }, WhenceType: { SEEK_SET: 0 },
    accessSync: name => files.has(name),
    statSync: name => ({ isFile: () => files.has(name), size: files.get(name)?.length }),
    readTextSync: name => {
      if (!files.has(name)) throw new Error(`File not found: ${name}`);
      return files.get(name).toString('utf8');
    },
    rmdirSync(name) { for (const key of files.keys()) if (key.startsWith(name + '/')) files.delete(key); },
    mkdirSync() {},
    openSync(name) {
      files.set(name, Buffer.alloc(0));
      const fd = nextFd++;
      descriptors.set(fd, name);
      return { fd };
    },
    lseek(fd, offset) { assert.equal(fd, 99); cursor = offset; },
    async read(fd, buffer, { length }) {
      assert.equal(fd, 99);
      const count = Math.min(length, 7);
      new Uint8Array(buffer).set(hapSlice.subarray(cursor, cursor + count));
      cursor += count;
      return count;
    },
    async write(fd, buffer) {
      const bytes = Buffer.from(buffer), count = Math.min(bytes.length, 3), name = descriptors.get(fd);
      files.set(name, Buffer.concat([files.get(name), bytes.subarray(0, count)]));
      return count;
    },
    writeSync(fd, text) { files.set(descriptors.get(fd), Buffer.from(text)); },
    closeSync() {},
    unlinkSync(name) { files.delete(name); },
  };
  const native = {
    create(configuration) {
      calls.push(['create', configuration]);
      assert.equal(configuration.toolchainRoot, root);
      for (const key of ['executorPath', 'compilerPath', 'linkerPath', 'runtimeDirectory']) {
        assert.equal(configuration[key], undefined, `Portable startup must not require ${key}`);
      }
      if (options.nativeFailure) throw new Error(options.nativeFailure);
      return {};
    },
    run(...args) { calls.push(['run', ...args]); return true; },
    cancel() { calls.push(['cancel']); }, destroy() { calls.push(['destroy']); },
  };
  class MethodChannel { setMethodCallHandler() {} }
  class EventChannel {
    setStreamHandler(handler) { handler.onListen({}, { success: event => events.push(event) }); }
  }
  const context = {
    filesDir: '/files', cacheDir: '/cache', bundleCodeDir: options.bundleCodeDir,
    applicationInfo: { nativeLibraryPath: options.libraryPath },
    resourceManager: {
      async getRawFd(name) {
        assert.equal(name, 'qfli_toolchain/ohos-wasi.zip');
        return { fd: 99, offset: 17, length: archive.length };
      },
      async closeRawFd() { rawClosed++; },
      async getRawFileContent(name) {
        assert.equal(name, 'qfli_toolchain/ohos-wasi.zip.sha256');
        return new Uint8Array(Buffer.from((options.corruptArchive ? '0'.repeat(64) : sha256(archive)) + '\n'));
      },
    },
  };
  const sandbox = {
    exports: {}, console: { error: message => logs.push(message) },
    require(name) {
      if (name === 'libqfli_ohos_runner.so') return { default: native };
      if (name === '@ohos/flutter_ohos') return { MethodChannel, EventChannel };
      if (name === '@kit.CoreFileKit') return { fileIo: io };
      if (name === '@kit.AbilityKit') return { bundleManager: {
        getBundleInfoForSelfSync: () => ({ versionCode: 1, updateTime: 1792074309446 }),
      } };
      if (name === '@ohos.file.hash') return { default: { async hash(name, algorithm) {
        assert.equal(algorithm, 'sha256');
        if (!files.has(name)) throw new Error(`Missing digest input: ${name}`);
        return sha256(files.get(name)).toUpperCase();
      } } };
      if (name === '@ohos.zlib') return { default: { async decompressFile(name, destination) {
        assert.equal(destination, root);
        assert.deepEqual(files.get(name), archive, 'Read exactly the ZIP raw-FD slice, with partial writes');
        extractionCount++;
        if (options.cancelDuringPrepare) sandbox.exports.cancel({ argument: () => 'resource-check' });
        install();
        if (options.corruptExtraction) files.get(`${root}/${resources[1]}`)[0] ^= 1;
      } } };
      throw new Error(`Unexpected import ${name}`);
    },
  };
  vm.runInNewContext(compiled.outputText, sandbox, { filename: file });
  sandbox.exports.registerQfliNativeChannel({ dartExecutor: { getBinaryMessenger: () => ({}) } }, context);
  const args = { runId: 'resource-check', type: 'cpp', projectPath: '/project',
    entryFile: '/project/main.cpp', sources: ['/project/main.cpp'] };
  sandbox.exports.start({ argument: key => args[key], hasArgument: key => Object.hasOwn(args, key) },
    { success: value => replies.push(value), error: (...value) => errors.push(value) }, context);
  await new Promise(resolve => setImmediate(resolve));
  if (options.nativeFailure) {
    assert.equal(errors[0][0], 'QFLI_NATIVE_FAILED');
    assert.equal(errors[0][1], options.nativeFailure);
    assert.equal(replies.length, 0);
  } else if (options.corruptArchive || options.corruptExtraction) {
    assert.equal(replies[0].available, false);
    assert.equal(calls.length, 0);
    assert(logs.some(line => line.includes('QFLI_OHOS_TOOLCHAIN_PREPARE_FAILED') && line.includes('SHA256')));
    assert(!files.has(`${root}/.ready`));
  } else if (options.cancelDuringPrepare) {
    assert.equal(replies[0].available, true);
    assert.equal(calls.length, 0);
    assert.equal(events.at(-1).exitCode, 130);
  } else {
    assert.deepEqual(errors, []);
    assert.equal(replies[0].available, true);
    assert.equal(calls[1][0], 'run');
    assert.equal(calls[1][5], '/cache');
    calls[0][1].onEvent({ kind: 'stdout', text: 'one\n\npar' });
    calls[0][1].onEvent({ kind: 'stdout', text: 'tial' });
    calls[0][1].onEvent({ kind: 'exit', exitCode: 7 });
    assert.deepEqual(events.filter(event => event.kind === 'stdout').map(event => event.text), ['one', '', 'partial']);
    assert.equal(events.at(-1).exitCode, 7);
  }
  const expectedExtractions = options.cached === false || options.staleManifest || options.corruptCache ? 1 : 0;
  assert.equal(extractionCount, options.corruptArchive ? 0 : expectedExtractions);
  if (expectedExtractions) {
    assert.equal(rawClosed, 1);
    assert(!files.has('/cache/qfli-ohos-wasi.zip'));
  }
  if (options.corruptCache) assert(logs.some(line => line.includes('QFLI_OHOS_TOOLCHAIN_CACHE_INVALID')));
}

(async () => {
  for (const libraryPath of ['libs/arm64', './libs/arm64/', '/installed/libs', undefined, null, '']) {
    await scenario({ libraryPath });
  }
  await scenario({ cached: false });
  await scenario({ cached: false, corruptArchive: true });
  await scenario({ cached: false, corruptExtraction: true });
  await scenario({ corruptCache: true });
  for (const staleManifest of [{ llvmVersion: '15.0.7' }, { wasiSdkVersion: '32.0' },
    { targetTriple: 'aarch64-unknown-linux-ohos' }, { jit: true }, { execution: 'jit' }, { resources: [] },
    { supportedTargets: ['wasm32-unknown-wasip1'] }, { maxWorkerThreads: 0 }, { threading: 'disabled' }]) {
    await scenario({ staleManifest });
  }
  await scenario({ cached: false, cancelDuringPrepare: true });
  await scenario({ nativeFailure: 'native WASI initialization /files/resource: permission denied' });
  console.log('PASS: actual ArkTS WASI startup, signed archive/key-file SHA256, raw-FD slices, cache repair, cancellation, native errors and output/exit preservation.');
})().catch(error => { console.error(error); process.exitCode = 1; });
