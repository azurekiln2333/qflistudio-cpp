/* Exercise the production ArkTS start path with realistic bundle metadata.
 * Usage: node ohos-arkts-native-path-regression.cjs <typescript.js>
 * TypeScript is supplied by the installed OHOS build tools; no npm install.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

if (!process.argv[2]) {
  throw new Error('Pass the OHOS build tools typescript.js path as the first argument.');
}
const ts = require(path.resolve(process.argv[2]));
const repo = path.resolve(__dirname, '../../..');
const file = path.join(repo, 'ohos/entry/src/main/ets/plugins/QfliCNative.ets');
const source = fs.readFileSync(file, 'utf8');
const compiled = ts.transpileModule(source + '\nexport { start };', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  reportDiagnostics: true,
});
assert.equal(compiled.diagnostics.filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);

async function startWith(libraryPath, bundleCodeDir, expectedDirectory, missingFile, nativeFailure) {
  const calls = [], replies = [], errors = [], logs = [], events = [];
  const installed = new Set([
    'libqfli_executor.so', 'libqfli_clang.so', 'libqfli-ld.lld-.so', 'libc++_shared.so',
  ].filter(name => name !== missingFile).map(name => `${expectedDirectory}/${name}`));
  const manifest = { formatVersion: 1, llvmVersion: '15.0.7', architecture: 'arm64-v8a',
    targetTriple: 'aarch64-unknown-linux-ohos' };
  const io = {
    // In the app cwd, relative paths can pass access but still fail native
    // canonical-path validation. The bridge must resolve before create.
    accessSync: p => p.startsWith('/files/forge-toolchain/') || installed.has(p) ||
      installed.has(`${String(bundleCodeDir).replace(/\/+$/, '')}/${p}`),
    statSync: () => ({ isFile: () => true }),
    readTextSync: () => JSON.stringify(manifest),
  };
  const native = {
    create: options => {
      calls.push(['create', options]);
      for (const key of ['executorPath', 'compilerPath', 'linkerPath', 'runtimeDirectory']) {
        if (!options[key].startsWith('/')) throw new Error(`native ${key} requires an absolute path`);
      }
      if (nativeFailure) throw new Error(nativeFailure);
      return {};
    },
    run: (...args) => { calls.push(['run', ...args]); return true; },
    cancel() {},
    destroy() {},
  };
  class MethodChannel { setMethodCallHandler() {} }
  class EventChannel {
    setStreamHandler(handler) { handler.onListen({}, { success: event => events.push(event) }); }
  }
  const context = { filesDir: '/files', cacheDir: '/cache', bundleCodeDir,
    applicationInfo: { nativeLibraryPath: libraryPath } };
  const sandbox = {
    exports: {}, console: { error: message => logs.push(message) },
    require(name) {
      if (name === 'libqfli_ohos_runner.so') return { default: native };
      if (name === '@ohos/flutter_ohos') return { MethodChannel, EventChannel };
      if (name === '@kit.CoreFileKit') return { fileIo: io };
      if (name === '@kit.AbilityKit') return { bundleManager: {
        getBundleInfoForSelfSync: () => ({ versionCode: 1, updateTime: 1792074309446 }),
      } };
      if (name === '@ohos.zlib') return { default: {} };
      throw new Error(`Unexpected import ${name}`);
    },
  };
  vm.runInNewContext(compiled.outputText, sandbox, { filename: file });
  sandbox.exports.registerQfliNativeChannel({ dartExecutor: { getBinaryMessenger: () => ({}) } }, context);
  const args = { runId: 'path-check', type: 'cpp', projectPath: '/project',
    entryFile: '/project/main.cpp', sources: ['/project/main.cpp'] };
  sandbox.exports.start({ argument: key => args[key], hasArgument: key => Object.hasOwn(args, key) },
    { success: value => replies.push(value), error: (...value) => errors.push(value) }, context);
  await new Promise(resolve => setImmediate(resolve));
  if (nativeFailure) {
    assert.equal(errors[0][0], 'QFLI_NATIVE_FAILED');
    assert.equal(errors[0][1], nativeFailure);
    assert.equal(replies.length, 0);
    return;
  }
  assert.deepEqual(errors, []);
  if (!expectedDirectory || missingFile) {
    assert.equal(replies[0].available, false);
    assert.equal(calls.length, 0);
    assert(logs.some(message => message.includes(missingFile ?
      `QFLI_OHOS_NATIVE_FILE_MISSING ${expectedDirectory}/${missingFile}` :
      'QFLI_OHOS_NATIVE_DIRECTORY_FAILED')));
    return;
  }
  assert.equal(replies[0].available, true);
  assert.equal(calls[0][0], 'create');
  const options = calls[0][1];
  assert.equal(options.compilerPath, `${expectedDirectory}/libqfli_clang.so`);
  assert.equal(options.linkerPath, `${expectedDirectory}/libqfli-ld.lld-.so`);
  assert.equal(options.executorPath, `${expectedDirectory}/libqfli_executor.so`);
  assert.equal(options.runtimeDirectory, expectedDirectory);
  assert.equal(calls[1][0], 'run');
  assert.equal(calls[1][5], '/cache');
  options.onEvent({ kind: 'exit', exitCode: 0 });
  assert.equal(events.at(-1).exitCode, 0);
}

(async () => {
  await startWith('libs/arm64', '/data/storage/el1/bundle', '/data/storage/el1/bundle/libs/arm64');
  await startWith('./libs/arm64/', '/data/storage/el1/bundle/', '/data/storage/el1/bundle/libs/arm64');
  await startWith('/installed/libs/', '/data/storage/el1/bundle', '/installed/libs');
  await startWith('libs/arm64', '/data/storage/el1/bundle', '/data/storage/el1/bundle/libs/arm64', 'libqfli_clang.so');
  await startWith('libs/arm64', '/data/storage/el1/bundle', '/data/storage/el1/bundle/libs/arm64',
    undefined, 'native compiler access /data/storage/el1/bundle/libs/arm64/libqfli_clang.so: Permission denied');
  for (const invalid of [undefined, null, '', 'libs/\0arm64']) {
    await startWith(invalid, '/data/storage/el1/bundle');
  }
  await startWith('libs/arm64', 'relative/bundle');
  console.log('PASS: actual ArkTS start resolves relative and absolute installed-library metadata; missing files and invalid metadata report diagnostics.');
})().catch(error => { console.error(error); process.exitCode = 1; });
