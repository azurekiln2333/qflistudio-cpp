#!/usr/bin/env python3
"""Exercise the actual OHOS portable NAPI bridge with real host Clang/WasmEdge."""
import json
import os
import pathlib
import shlex
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[3]
compiler_build = pathlib.Path(os.environ.get('QFLI_COMPILER_BUILD', root / 'native/build/compiler-linux'))
runtime_build = pathlib.Path(os.environ.get('QFLI_RUNTIME_BUILD', root / 'native/build/portable-linux-eh'))
sdk = pathlib.Path(os.environ.get('WASI_SDK', root / 'native/build/portable-deps/wasi-sdk-33.0-x86_64-linux'))
node = shutil.which('node') or str(root / 'native/build/emsdk-4.0.23/node/22.16.0_64bit/bin/node')
node_headers = pathlib.Path('/usr/include/node')
if not (node_headers / 'node_api.h').is_file():
    node_headers = root / 'native/build/emsdk-4.0.23/node/22.16.0_64bit/include/node'
assert pathlib.Path(node).is_file() and (node_headers / 'node_api.h').is_file(), 'Actual Node NAPI is required'


def flags(build, target):
    text = (build / f'CMakeFiles/{target}.dir/flags.make').read_text()
    result = []
    for line in text.splitlines():
        if line.startswith(('CXX_DEFINES =', 'CXX_INCLUDES =')):
            result.extend(shlex.split(line.partition('=')[2]))
    return result


def archives(build, target, own):
    words = shlex.split((build / f'CMakeFiles/{target}.dir/link.txt').read_text())
    return [str(build / word) for word in words if word.endswith('.a') and word != own]


with tempfile.TemporaryDirectory(prefix='qfli-ohos-portable-', delete=not bool(os.environ.get('QFLI_KEEP_TEST_BUILD'))) as temporary:
    work = pathlib.Path(temporary)
    print(f'Actual NAPI test artifacts: {work}', flush=True)
    (work / 'napi').mkdir()
    (work / 'napi/native_api.h').write_text('#include <node_api.h>\n')
    objects = []
    for source, build, target in [
        (root / 'native/compiler/compiler.cpp', compiler_build, 'qfli_compiler'),
        (root / 'native/portable/wasm_runtime.cpp', runtime_build, 'qfli_wasm'),
    ]:
        output = work / f'{target}.o'
        subprocess.run(['clang++-18', '-std=c++17', '-O2', '-fPIC', *flags(build, target),
                        '-c', str(source), '-o', str(output)], check=True)
        objects.append(str(output))
    addon = work / 'portable.node'
    subprocess.run([
        'clang++-18', '-std=c++17', '-shared', '-fPIC', '-pthread', '-fuse-ld=lld', '-O2', '-Wall', '-Wextra',
        '-Werror', '-Wno-deprecated-declarations', '-I', str(work), '-I', str(node_headers),
        str(root / 'ohos/entry/src/main/cpp/qfli_ohos_portable.cpp'), *objects,
        *archives(compiler_build, 'qfli_compiler_probe', 'libqfli_compiler.a'),
        *archives(runtime_build, 'qfli_wasm_probe', 'libqfli_wasm.a'),
        '-Wl,--exclude-libs,ALL', '-lrt', '-ldl', '-lm', '-o', str(addon),
    ], check=True)
    resources = work / 'resources'
    resources.mkdir()
    for item in ['share', 'lib']:
        (resources / item).symlink_to(sdk / item, target_is_directory=True)
    (resources / 'toolchain.json').write_text(json.dumps({'formatVersion': 2, 'wasiSdkVersion': '33.0'}))
    script = work / 'test.cjs'
    script.write_text(r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const native = require(process.argv[2]);
const base = process.argv[3], sdk = process.argv[4];
const project = path.join(base, 'project with spaces'), cache = path.join(base, 'cache');
fs.mkdirSync(project); fs.mkdirSync(cache);
const originalCwd = process.cwd();
let serial = 0;
function options(callback) { return {toolchainRoot: sdk, onEvent: callback}; }
function verifyCleanup() {
  assert.deepEqual(fs.readdirSync(cache), []);
  assert.equal(process.cwd(), originalCwd);
}
async function run(source, {extension = 'c', files = {}, selected, mode} = {}) {
  for (const name of fs.readdirSync(project)) fs.rmSync(path.join(project, name), {recursive:true, force:true});
  const entry = path.join(project, `main.${extension}`);
  fs.writeFileSync(entry, source);
  for (const [name, text] of Object.entries(files)) {
    const filename = path.join(project, name); fs.mkdirSync(path.dirname(filename), {recursive:true});
    fs.writeFileSync(filename, text);
  }
  let handle;
  return await new Promise((resolve, reject) => {
    let out = '', err = '', exits = 0, cancelSent = false;
    const timer = setTimeout(() => { if (handle) native.cancel(handle); reject(Error(`run ${serial} timed out`)); }, 20000);
    handle = native.create(options(event => {
      if (event.kind === 'stdout') {
        out += event.text;
        if (mode === 'output-cancel' && !cancelSent && out.includes('started')) {
          cancelSent = true; native.cancel(handle);
        }
      } else if (event.kind === 'stderr') err += event.text;
      else if (event.kind === 'exit') {
        clearTimeout(timer); assert.equal(++exits, 1); verifyCleanup();
        if (handle) { native.destroy(handle); native.destroy(handle); native.cancel(handle); }
        resolve({code:event.exitCode, out, err});
      } else reject(Error(`Unexpected event: ${JSON.stringify(event)}`));
    }));
    if (mode === 'pre-cancel') native.cancel(handle);
    const sources = selected ? selected.map(name => path.join(project,name)) :
      [entry, ...Object.keys(files).filter(name => /\.(?:c|cc|cpp|cxx)$/i.test(name)).map(name => path.join(project,name))];
    if (serial === 0) assert.equal(native.run(handle, project, entry, [], cache), false);
    assert.equal(native.run(handle, project, entry, sources, cache), true);
    assert.equal(native.run(handle, project, entry, sources, cache), false);
    ++serial;
    if (mode === 'compile-cancel') setTimeout(() => native.cancel(handle), 30);
    if (mode === 'destroy') { native.destroy(handle); native.destroy(handle); native.cancel(handle); }
    if (mode === 'gc') { handle = null; global.gc(); }
  });
}
(async () => {
  assert.throws(() => native.create({toolchainRoot:'relative', onEvent(){}}), error => error.code === 'QFLI_NATIVE_INIT');
  assert.throws(() => native.create({...options(() => {}), onEvent:false}), /onEvent/);
  assert.throws(() => native.create({toolchainRoot:base, onEvent(){}}), /missing readable WASI SDK resource/);
  const getterError = Error('original getter');
  const badOptions = {get toolchainRoot(){throw getterError;}, onEvent(){}};
  assert.throws(() => native.create(badOptions), error => error === getterError);
  const entry = path.join(project,'validation.c'); fs.writeFileSync(entry,'int main(void){return 0;}');
  const outside = path.join(base,'outside.c'); fs.writeFileSync(outside,'int main(void){return 0;}');
  const escape = path.join(project,'escape.c'); fs.symlinkSync(outside,escape);
  let validationHandle = native.create(options(() => {}));
  for (const sources of [[], [outside], [escape], [entry,entry]]) {
    assert.equal(native.run(validationHandle,project,entry,sources,cache),false);
  }
  assert.equal(native.run(validationHandle,project,entry,[entry],outside),false);
  native.destroy(validationHandle); native.destroy(validationHandle); native.cancel(validationHandle);
  assert.equal(native.run(validationHandle,project,entry,[entry],cache),false);
  validationHandle = null; global.gc();
  console.log('PASS: actual NAPI initialization, preserved JS errors, canonical source validation and idempotent lifecycle');

  let result = await run('#include <stdio.h>\nint main(void){puts("native C");return 7;}');
  assert.deepEqual(result,{code:7,out:'native C\n',err:''});
  result = await run(`#include <iostream>
#include <vector>
#include <numeric>
#include <stdexcept>
struct Guard { ~Guard(){ std::cout << "destroyed\\n"; } };
int main(){try{Guard g;throw std::runtime_error("exception");}
catch(const std::exception &e){std::vector<int> v{10,12,20};std::cout<<e.what()<<" "<<std::accumulate(v.begin(),v.end(),0)<<"\\n";}}`,{extension:'cpp'});
  assert.deepEqual(result,{code:0,out:'destroyed\nexception 42\n',err:''});
  result = await run('#include <stdio.h>\n#include <math.h>\n#include "answer.h"\nint main(void){double n;scanf("%lf",&n);printf("%d %.0f\\n",answer(),sqrt(n));fprintf(stderr,"separate\\n");return 17;}',{
    files:{'include/answer.h':'int answer(void);','helper.CPP':'#include <vector>\nextern "C" int answer(){return std::vector<int>{42}.at(0);}', 'input.txt':'49\n'}});
  assert.deepEqual(result,{code:17,out:'42 7\n',err:'separate\n'});
  console.log('PASS: real C17/C++20, exceptions/destructors, mixed sources/headers/math/stdin and independent stderr/status');

  result = await run('#include <stdio.h>\n#include <time.h>\nint main(void){clock_t start=clock();for(volatile int i=0;i<10000;++i){}clock_t end=clock();if(start==(clock_t)-1||end<start)return 2;puts("clock supported");}');
  assert.deepEqual(result,{code:0,out:'clock supported\n',err:''});
  result = await run('#include <setjmp.h>\n#include <stdio.h>\njmp_buf env;void jump(void){longjmp(env,42);}\nint main(void){int value=setjmp(env);if(!value)jump();printf("jump=%d\\n",value);return value==42?0:3;}');
  assert.deepEqual(result,{code:0,out:'jump=42\n',err:''});
  result = await run(`#include <setjmp.h>
#include <iostream>
#include <stdexcept>
static jmp_buf env;
static int jump(){int n=setjmp(env);if(!n)longjmp(env,0);return n;}
static int destroyed;
struct Guard{~Guard(){++destroyed;}};
int main(){int n=jump();try{Guard g;try{throw std::runtime_error("exception");}catch(...){throw;}}
catch(const std::exception &e){std::cout<<"jump="<<n<<" "<<e.what()<<" destroyed="<<destroyed<<"\\n";}
return n==1&&destroyed==1?0:4;}`,{extension:'cpp'});
  assert.deepEqual(result,{code:0,out:'jump=1 exception destroyed=1\n',err:''});
  console.log('PASS: SDK process-clock emulation, C setjmp/longjmp and C++ standard EH coexistence');

  for (const source of ['int main(void){this is invalid C;}','int missing(void);int main(void){return missing();}']) {
    result = await run(source); assert.notEqual(result.code,0); assert.equal(result.out,''); assert.match(result.err,/error:|undefined/);
    assert.deepEqual(await run('int main(void){return 0;}'),{code:0,out:'',err:''});
  }
  result = await run('int main(void){__builtin_trap();}'); assert.equal(result.code,125); assert.ok(result.err);
  assert.deepEqual(await run('int main(void){return 0;}'),{code:0,out:'',err:''});
  result = await run('#include <stdio.h>\nint main(void){puts("selected");}',{files:{'other.c':'int main(void){return 99;}'},selected:['main.c']});
  assert.deepEqual(result,{code:0,out:'selected\n',err:''});
  console.log('PASS: compiler/linker/trap diagnostics and same-process recovery, selected entry and no stale output');

  result = await run('#define _POSIX_C_SOURCE 200809L\n#include <stdio.h>\n#include <unistd.h>\n#include <time.h>\nint main(void){const char *s="鸿蒙😀";struct timespec delay={0,1000000};for(int i=0;i<10;i++){for(int j=0;j<10;j++){write(1,s+j,1);nanosleep(&delay,0);}}puts("");}');
  assert.deepEqual(result,{code:0,out:'鸿蒙😀'.repeat(10)+'\n',err:''});
  result = await run('#include <stdio.h>\nint main(void){for(int i=0;i<200000;i++)putchar(65);for(int i=0;i<200000;i++)fputc(66,stderr);puts("\\n\\n尾行");}');
  assert.deepEqual(result,{code:0,out:'A'.repeat(200000)+'\n\n尾行\n',err:'B'.repeat(200000)});
  console.log('PASS: independent pipe-capacity streams, UTF-8 byte splits, blank lines and final tails');

  for (const source of [
    '#include <stdio.h>\nint main(void){puts("started");fflush(stdout);for(;;){volatile int x=0;x++;}}',
    '#include <stdio.h>\n#include <unistd.h>\nint main(void){puts("started");fflush(stdout);sleep(30);}',
  ]) {
    result = await run(source,{mode:'output-cancel'}); assert.equal(result.code,130); assert.match(result.out,/started/);
    assert.deepEqual(await run('int main(void){return 0;}'),{code:0,out:'',err:''});
  }
  result = await run('int main(void){for(;;){}}',{mode:'pre-cancel'}); assert.equal(result.code,130);
  const hugeSource = Array.from({length:120000},(_,i)=>`int variable_${i}=${i};`).join('\n')+'\nint main(void){return 0;}';
  result = await run(hugeSource,{mode:'compile-cancel'}); assert.equal(result.code,130);
  for (const mode of ['destroy','gc']) {
    result = await run('int main(void){for(;;){}}',{mode}); assert.equal(result.code,130);
  }
  assert.deepEqual(await run('int main(void){return 0;}'),{code:0,out:'',err:''});
  console.log('PASS: real compiler/CPU/sleep/pre-start cancellation, destroy/GC during worker and successful fresh run');
  verifyCleanup(); console.log(`PASS: ${serial} actual in-process compiler/interpreter runs; exit follows cleanup`);
})().catch(error => { console.error(error); process.exit(1); });
''')
    completed = subprocess.run([node, '--expose-gc', str(script), str(addon), str(work), str(resources)],
                               capture_output=True, text=True, timeout=180)
    print(completed.stdout, end='', flush=True)
    assert completed.returncode == 0, completed.stderr
    assert not completed.stderr, f'Process stderr escaped the event pipe: {completed.stderr}'
