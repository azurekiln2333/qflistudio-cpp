const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('D:/ProgramFiles/Huawei/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const file = 'ohos/entry/src/main/ets/plugins/QfliCNative.ets';
const source = fs.readFileSync(file, 'utf8') + '\nexport {ActiveRun, emitLines, finishRun, start, cancel, copyToolchainArchive, hasToolchainFiles};';
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }, reportDiagnostics: true });
assert.equal(compiled.diagnostics.filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);
function create(options = {}) {
  const events = [], calls = [], errors = [], replies = [], destroyed = [];
  let sink;
  const native = { create(o) { calls.push(['create',o]); return {}; }, run(...args) { calls.push(['run',...args]); return options.accepted !== false; }, cancel(h) { calls.push(['cancel',h]); }, destroy(h) { destroyed.push(h); } };
  const io = { accessSync: p => options.unready && p.endsWith('/.ready') ? false : true, statSync: p => ({ isFile: () => true }), readTextSync: () => JSON.stringify({ formatVersion:1, llvmVersion:'15.0.7', architecture:'arm64-v8a', targetTriple:'aarch64-unknown-linux-ohos' }), listFileSync: () => ['src/main.c', '/helper.CPP'], mkdirSync(){}, rmdirSync(){}, OpenMode:{CREATE:1,WRITE_ONLY:2,TRUNC:4}, WhenceType:{SEEK_SET:0}, ...options.io };
  class MethodChannel { setMethodCallHandler(h) { this.handler=h; } }
  class EventChannel { setStreamHandler(h) { sink=h; h.onListen({}, {success:e=>events.push(e)}); } }
  const context = {filesDir:'/files',cacheDir:'/cache',applicationInfo:{nativeLibraryPath:'/installed/libs'},resourceManager:options.resources || {}};
  const sandbox = {exports:{},require(name){ if (name==='libqfli_ohos_runner.so') return {default:native}; if(name==='@ohos/flutter_ohos') return {MethodChannel,EventChannel}; if(name==='@kit.CoreFileKit') return {fileIo:io}; if(name==='@kit.AbilityKit') return {bundleManager:{getBundleInfoForSelfSync:()=>({versionCode:1,updateTime:9})}}; if(name==='@ohos.zlib') return {default:{decompressFile:async()=>{}}}; throw Error(name); }, ArrayBuffer, Uint8Array};
  vm.runInNewContext(compiled.outputText,sandbox,{filename:file});
  const bridge=sandbox.exports;
  bridge.registerQfliNativeChannel({dartExecutor:{getBinaryMessenger:()=>({})}},context);
  const result={error:(...e)=>errors.push(e),success:r=>replies.push(r)};
  const call=args=>({argument:k=>args[k],hasArgument:k=>Object.hasOwn(args,k)});
  const args={runId:'test-1',type:'cpp',projectPath:'/project',entryFile:'/project/src/main.c',sources:['/project/src/main.c','/project/helper.CPP']};
  return {bridge,events,calls,errors,replies,destroyed,context,result,call,args,native};
}
const tick=()=>new Promise(r=>setImmediate(r));
(async()=>{
  const a=create();
  a.bridge.start(a.call(a.args),a.result,a.context); await tick();
  const onEvent=a.calls.find(c=>c[0]==='create')[1].onEvent;
  onEvent({kind:'stdout',text:'hel'}); onEvent({kind:'stderr',text:'warn'}); onEvent({kind:'stdout',text:'lo\r\n\nlast'}); onEvent({kind:'stderr',text:'ing\npartial'}); onEvent({kind:'exit',exitCode:7}); onEvent({kind:'exit',exitCode:9});
  assert.deepEqual(a.events.map(e=>[e.kind,e.text??e.exitCode]),[['stdout','hello'],['stdout',''],['stderr','warning'],['stdout','last'],['stderr','partial'],['exit',7]]);
  assert.equal(a.destroyed.length,1);
  const nativeOptions=a.calls.find(c=>c[0]==='create')[1];
  assert.equal(nativeOptions.compilerPath,'/installed/libs/libqfli_clang.so'); assert.equal(nativeOptions.linkerPath,'/installed/libs/libqfli-ld.lld-.so'); assert.equal(nativeOptions.runtimeDirectory,'/installed/libs');
  const b=create({accepted:false}); b.bridge.start(b.call(b.args),b.result,b.context); await tick(); assert.equal(b.events.at(-1).exitCode,127); assert.equal(b.destroyed.length,1);
  for(const selected of [null, [], {}, ['/project/src/main.c',3], 'bad']) { const c=create(); c.bridge.start(c.call({...c.args,sources:selected}),c.result,c.context); await tick(); assert.equal(c.errors[0][0],'invalid_run'); assert.equal(c.calls.length,0); }
  const d=create(); const legacy={...d.args}; delete legacy.sources; d.bridge.start(d.call(legacy),d.result,d.context); await tick(); assert.deepEqual(Array.from(d.calls.find(c=>c[0]==='run')[4]),['/project/helper.CPP','/project/src/main.c']);
  let rejectRaw; const e=create({unready:true,resources:{getRawFd:()=>new Promise((resolve,reject)=>{rejectRaw=reject;})}}); e.bridge.start(e.call(e.args),e.result,e.context); e.bridge.cancel(e.call({runId:'test-1'})); rejectRaw(Error('resource missing')); await tick(); assert.equal(e.replies[0].available,true); assert.equal(e.events.at(-1).exitCode,130); assert.equal(e.calls.length,0);
  const rawData=Buffer.alloc(2*1024*1024+131); for(let i=0;i<rawData.length;i++) rawData[i]=i%251;
  const hapData=Buffer.concat([Buffer.alloc(37,254),rawData,Buffer.alloc(43,253)]); let cursor=0, output=[],closeCount=0,readCount=0;
  const f=create({resources:{getRawFd:async()=>({fd:7,offset:37,length:rawData.length}),closeRawFd:async()=>closeCount++},io:{openSync:()=>({fd:9}),closeSync(){},lseek(fd,at){cursor=at;},async read(fd,buf,o){readCount++; const length=Math.min(o.length,hapData.length-cursor,393217); new Uint8Array(buf).set(hapData.subarray(cursor,cursor+length)); cursor+=length; return length;},async write(fd,buf){const length=Math.min(buf.byteLength,65537); output.push(Buffer.from(buf).subarray(0,length)); return length;}}});
  await f.bridge.copyToolchainArchive(f.context,'/cache/archive.zip'); assert.deepEqual(Buffer.concat(output),rawData); assert.equal(closeCount,1); assert(readCount>2);
  const root='native/build/toolchain-ohos-arm64-ready'; const g=create({io:{accessSync:p=>fs.existsSync(p),statSync:p=>({isFile:()=>fs.statSync(p).isFile()}),readTextSync:p=>fs.readFileSync(p,'utf8')}}); assert.equal(g.bridge.hasToolchainFiles(root),true);
  console.log('PASS: ArkTS actual-source protocol buffering, terminal once, signed paths, refusal cleanup, malformed explicit source lists, absent-source discovery, prepare cancellation, bounded HAP slice copy with partial reads/writes, actual package readiness.');
})().catch(error=>{console.error(error);process.exitCode=1;});
