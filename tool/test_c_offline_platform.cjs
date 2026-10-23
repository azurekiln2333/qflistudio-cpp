#!/usr/bin/env node
'use strict';

// Adapted from Python's real-handler platform check. These local doubles give
// host behavioral evidence; they do not replace ArkTS or installed OHOS tests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const propertiesPath = path.join(root, 'ohos/local.properties');
const properties = fs.existsSync(propertiesPath) ? fs.readFileSync(propertiesPath, 'utf8') : '';
const sdkProperty = /^(?:sdk|hwsdk)\.dir\s*=\s*(.+)$/m.exec(properties);
const sdk = process.env.DEVECO_SDK_HOME || process.env.OHOS_SDK_HOME
  || (sdkProperty && sdkProperty[1].trim().replace(/\\([\\: ])/g, '$1'));
const suffix = 'openharmony/ets/build-tools/ets-loader/node_modules/typescript';
const candidates = [process.env.QFLI_ARKTS_TYPESCRIPT,
  sdk && path.join(sdk, 'default', suffix), sdk && path.join(sdk, suffix)]
  .filter(Boolean);
const compiler = candidates.find(candidate => fs.existsSync(candidate));
assert.ok(compiler, 'Use installed SDK TypeScript or QFLI_ARKTS_TYPESCRIPT; no downloads');
const ts = require(path.resolve(compiler));
const requireStartup = process.argv.includes('--require-startup');
const sourceArguments = process.argv.slice(2).filter(value => value !== '--require-startup');
assert.ok(sourceArguments.length <= 1,
  'Usage: node tool/test_c_offline_platform.cjs [EntryAbility.ets] [--require-startup]');
// An explicit source supports the staged-old-source and policy-disabled
// negative controls without changing the working-tree production handler.
const sourcePath = sourceArguments[0] ? path.resolve(sourceArguments[0])
  : path.join(root, 'ohos/entry/src/main/ets/entryability/EntryAbility.ets');
const source = fs.readFileSync(sourcePath, 'utf8').replace(/^import[\s\S]*?;\r?$/gm, '');
const compiled = ts.transpileModule(source, {
  fileName: 'EntryAbility.ts', reportDiagnostics: true,
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
});
assert.deepEqual((compiled.diagnostics || [])
  .filter(diagnostic => diagnostic.category === ts.DiagnosticCategory.Error), []);

const handlers = new Map();
const observed = {
  external: [], nativeRegistrations: [], engines: 0, plugins: 0,
  shares: [], picker: [], progress: [], backgrounds: [], windowStages: 0,
};
const external = name => { observed.external.push(name); throw new Error(`Unexpected ${name}`); };
const abilityContext = {
  config: { colorMode: 0 },
  startAbility: () => external('browser'),
  eventHub: { emit: (...values) => observed.progress.push(values) },
};
const engine = { dartExecutor: { getBinaryMessenger: () => ({}) } };
const context = {
  exports: {},
  FlutterAbility: class {
    context = abilityContext;
    configureFlutterEngine() { observed.engines++; }
    onWindowStageCreate() { observed.windowStages++; }
  },
  MethodChannel: class {
    constructor(_messenger, name) { this.name = name; }
    setMethodCallHandler(handler) { handlers.set(this.name, handler); }
  },
  ConfigurationConstant: { ColorMode: { COLOR_MODE_DARK: 0 } },
  GeneratedPluginRegistrant: { registerWith: () => observed.plugins++ },
  registerQfliNativeChannel: (registeredEngine, registeredContext) => {
    observed.nativeRegistrations.push({ engine: registeredEngine, context: registeredContext });
  },
  authentication: { HuaweiIDProvider: class { constructor() { external('account'); } } },
  router: { pushUrl: () => external('remote agreement') },
  systemShare: {
    SharedData: class { constructor(record) { this.record = record; } },
    ShareController: class {
      constructor(data) { this.data = data; }
      show() { observed.shares.push(this.data.record); return Promise.resolve(); }
    },
  },
  isPickerMethod: method => method === 'pickFile',
  handlePickerCall: (_ability, call, result) => {
    observed.picker.push(call.method);
    result.success('local-file');
  },
};
vm.runInNewContext(compiled.outputText, context, { filename: sourcePath });
const ability = new context.exports.default();
ability.configureFlutterEngine(engine);
assert.equal(observed.engines, 1);
assert.equal(observed.plugins, 1);
assert.equal(observed.nativeRegistrations.length, 1);
assert.equal(observed.nativeRegistrations[0].engine, engine);
assert.equal(observed.nativeRegistrations[0].context, abilityContext);
assert.equal(observed.external.length, 0, 'Engine setup must not invoke a remote entry point');

async function invoke(channel, method, args = {}) {
  const results = [];
  let argumentReads = 0;
  assert.ok(handlers.has(channel), `Missing channel ${channel}`);
  handlers.get(channel).onMethodCall({ method, argument: key => {
    argumentReads++;
    return args[key];
  } }, {
    success: value => results.push({ kind: 'success', value }),
    error: (code, message) => results.push({ kind: 'error', code, message }),
    notImplemented: () => results.push({ kind: 'notImplemented' }),
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(results.length, 1, `${method} must complete exactly once`);
  return { ...results[0], argumentReads };
}

(async () => {
  const platform = 'qflistudio/platform';
  for (const url of ['https://example.invalid/privacy', 'http://127.0.0.1:8080',
    'file:///data/local/tmp/example.html', 'custom://action', undefined]) {
    for (const method of ['openUrl', 'openAgreement']) {
      const denied = await invoke(platform, method, { url });
      assert.equal(denied.kind, 'error');
      assert.equal(denied.code, 'OFFLINE_ONLY');
      assert.equal(denied.argumentReads, 0, `${method} must reject before reading arguments`);
    }
  }
  const deniedLogin = await invoke('qflistudio/huawei_account', 'login');
  assert.equal(deniedLogin.kind, 'error');
  assert.equal(deniedLogin.code, 'OFFLINE_ONLY');
  assert.equal(deniedLogin.argumentReads, 0);
  assert.deepEqual(observed.external, [], 'Rejected requests must never invoke platform providers');

  const stage = {
    getMainWindowSync: () => ({
      setWindowBackgroundColor: color => observed.backgrounds.push(color),
    }),
  };
  ability.onWindowStageCreate(stage);
  abilityContext.config.colorMode = 1;
  ability.onWindowStageCreate(stage);
  assert.deepEqual(observed.backgrounds, ['#FF111418', '#FFF8F9FF']);
  assert.equal(observed.windowStages, 2);
  const startup = await invoke(platform, 'startupProgress', { progress: 0.5 });
  if (requireStartup || startup.kind !== 'notImplemented') {
    assert.equal(startup.kind, 'success');
    for (const progress of [1.5, -2]) {
      assert.equal((await invoke(platform, 'startupProgress', { progress })).kind, 'success');
    }
    assert.deepEqual(observed.progress, [
      ['EVENT_STARTUP_PROGRESS', 0.5], ['EVENT_STARTUP_PROGRESS', 1], ['EVENT_STARTUP_PROGRESS', 0],
    ]);
    for (const progress of [NaN, Infinity, '0.5', undefined]) {
      assert.equal((await invoke(platform, 'startupProgress', { progress })).code, 'INVALID_PROGRESS');
    }
    assert.equal(observed.progress.length, 3);
  } else {
    // The separately owned startup-progress patch is absent in the published
    // base edition. Policy-only staged validation must retain that older API.
    assert.deepEqual(observed.progress, []);
    console.log('INFO: inspected edition has no startupProgress handler');
  }
  assert.equal((await invoke(platform, 'pickFile')).value, 'local-file');
  assert.deepEqual(observed.picker, ['pickFile']);
  const text = 'int main(void) { return 0; }';
  assert.equal((await invoke(platform, 'shareText', { title: 'Code', text })).kind, 'success');
  assert.equal(observed.shares[0].content, text);
  assert.equal(observed.shares[0].title, 'Code');
  assert.equal((await invoke(platform, 'unknown')).kind, 'notImplemented');
  assert.equal((await invoke('qflistudio/huawei_account', 'unknown')).kind, 'notImplemented');
  const moduleSource = fs.readFileSync(path.join(root, 'ohos/entry/src/main/module.json5'), 'utf8');
  assert.doesNotMatch(moduleSource, /ohos\.permission\.INTERNET/,
    'The standalone C/C++ module has no network permission requirement');
  console.log('PASS: real C EntryAbility offline refusal, native registration, startup, picker and local share');
})().catch(error => { console.error(error); process.exitCode = 1; });
