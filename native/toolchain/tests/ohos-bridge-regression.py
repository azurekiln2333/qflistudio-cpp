"""Execute actual OHOS bridge core/executor using Linux host Clang 15.

These gates prove host orchestration/language/cleanup, not OHOS device execution.
"""
import pathlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[3]
source = (root / 'ohos/entry/src/main/cpp/qfli_ohos_runner.cpp').read_text()
core = source.split('/* ---- NAPI 接口层 ---- */')[0]
core = core.replace('#include "napi/native_api.h"', '')
fixture = r'''
#include <cassert>
#include <chrono>
#include <fstream>
struct Output { std::string out, err; };
void collect(void *p, bool error, const char *s, size_t n) {
    auto *o = static_cast<Output *>(p);
    (error ? o->err : o->out).append(s, n);
}
int main(int argc, char **argv) {
    assert(argc == 3);
    int cancel[2]; assert(pipe2(cancel, O_CLOEXEC | O_NONBLOCK) == 0);
    bool cancelled = false; Output output;
    auto child = [&](const std::vector<std::string> &command, const std::string &input = "") {
        output = {};
        return RunChild(command, "/tmp", input, "", "/tmp", cancel[0], &cancelled, collect, &output);
    };
    int code = child({"/bin/sh", "-c", "exec 1>&-; sleep 0.1; printf diagnostic >&2"});
    assert(code == 0 && output.out.empty() && output.err == "diagnostic");
    code = child({"/usr/bin/python3", "-c", "import os; os.write(1,b'A'*131072); os.write(2,b'B'*131072)"});
    assert(code == 0 && output.out == std::string(131072, 'A') && output.err == std::string(131072, 'B'));
    code = child({"/usr/bin/python3", "-c", "import sys; print(repr(sys.stdin.read()))"});
    assert(code == 0 && output.out == "''\n");
    code = child({"/not/a/compiler"});
    assert(code == 125 && output.err.find("cannot execute") != std::string::npos);
    code = child({"/bin/cat"}, "/not/an/input/file");
    assert(code == 125 && output.err.find("cannot open program input") != std::string::npos);
    puts("PASS: independent stdout/stderr, pipe-capacity output, stdin EOF and startup failures");

    for (const char *command : {"exec 1>&-; sleep 20", "exec 1>&- 2>&-; sleep 20"}) {
        std::thread request([&] { usleep(150000); const char c = 1; assert(write(cancel[1], &c, 1) == 1); });
        const auto start = std::chrono::steady_clock::now();
        code = child({"/bin/sh", "-c", command});
        request.join();
        assert(code == 130 && cancelled);
        assert(std::chrono::steady_clock::now() - start < std::chrono::seconds(3));
        char signal; assert(read(cancel[0], &signal, 1) == 1); cancelled = false;
    }
    const auto orphanStart = std::chrono::steady_clock::now();
    code = child({"/bin/sh", "-c", "sleep 20 & printf child-started; exit 9"});
    assert(code == 9 && output.out == "child-started");
    assert(std::chrono::steady_clock::now() - orphanStart < std::chrono::seconds(3));
    puts("PASS: cancellation after one/both stream EOF; descendant cleanup after leader exit");

    char projectTemplate[] = "/tmp/ohos bridge-XXXXXX";
    char outsideTemplate[] = "/tmp/ohos-outside-XXXXXX";
    assert(mkdtemp(projectTemplate) && mkdtemp(outsideTemplate));
    const std::string project(projectTemplate), outside(outsideTemplate);
    auto writeFile = [](const std::string &path, const char *text) {
        FILE *file = fopen(path.c_str(), "w"); assert(file); fputs(text, file); assert(fclose(file) == 0);
    };
    writeFile(Join(project, "host.cfg"), "\n");
    Toolchain toolchain;
    toolchain.compiler = argv[2]; toolchain.executor = argv[1];
    toolchain.config = Join(project, "host.cfg");
    auto compile = [&](const std::string &entry, std::vector<Source> sources, bool stale = false) {
        std::string resolvedProject(project), resolvedEntry(Join(project, entry));
        assert(ValidateSources(&resolvedProject, &resolvedEntry, &sources));
        std::string pattern = Join(project, "build-XXXXXX");
        std::vector<char> path(pattern.begin(), pattern.end()); path.push_back(0);
        assert(mkdtemp(path.data()));
        const std::string build(path.data());
        if (stale) {
            std::ifstream saved(Join(project, "previous.so"), std::ios::binary);
            std::ofstream binary(Join(build, "program.so"), std::ios::binary);
            binary << saved.rdbuf(); assert(binary.good());
        }
        output = {};
        const int result = CompileAndRun(toolchain, resolvedProject, resolvedEntry, sources,
            build, cancel[0], &cancelled, collect, &output);
        if (entry == "main.C" && result == 7) {
            std::ifstream binary(Join(build, "program.so"), std::ios::binary);
            std::ofstream saved(Join(project, "previous.so"), std::ios::binary);
            saved << binary.rdbuf(); assert(saved.good());
        }
        RemoveTree(build);
        assert(access(build.c_str(), F_OK) != 0);
        return result;
    };
    writeFile(Join(project, "main.C"), "#include <stdio.h>\nint answer(void); int main(void) { _Static_assert(_Generic(1, int: 1, default: 0), \"C mode\"); printf(\"%d\\n\", answer()); return 7; }\n");
    writeFile(Join(project, "helper.CPP"), "#include <vector>\n#include <stdexcept>\nextern \"C\" int answer() { try { throw std::runtime_error(\"ok\"); } catch (...) { return std::vector<int>{42}.at(0); } }\n");
    code = compile("main.C", {{Join(project, "main.C"), false}, {Join(project, "helper.CPP"), true}});
    if (code != 7) fprintf(stderr, "%s", output.err.c_str());
    assert(code == 7 && output.out == "42\n");
    puts("PASS: uppercase mixed C17/C++20, spaces in paths, stdlib, exceptions and exit status");

    writeFile(Join(project, "input.txt"), "49\n");
    writeFile(Join(project, "math.c"), "#include <stdio.h>\n#include <math.h>\nint main(void) { double n; if (scanf(\"%lf\", &n) != 1) return 99; fprintf(stderr, \"separate\\n\"); printf(\"%.0f\\n\", sqrt(n)); return 0; }\n");
    code = compile("math.c", {{Join(project, "math.c"), false}});
    assert(code == 0 && output.out == "7\n" && output.err == "separate\n");
    writeFile(Join(project, "exit.cpp"), "#include <cstdio>\n#include <cstdlib>\nstruct Guard { ~Guard() { puts(\"destructor\"); } } guard; int main() { std::atexit([] { puts(\"atexit\"); }); std::exit(23); }\n");
    code = compile("exit.cpp", {{Join(project, "exit.cpp"), true}});
    assert(code == 23 && output.out == "atexit\ndestructor\n");
    writeFile(Join(project, "crash.c"), "#include <signal.h>\nint main(void) { raise(SIGKILL); return 0; }\n");
    code = compile("crash.c", {{Join(project, "crash.c"), false}});
    assert(code == 137);
    puts("PASS: input.txt, runtime libm, independent stderr, exit/atexit/C++ destructor, crash isolation");

    writeFile(Join(project, "bad.c"), "int main(void) { syntax error }\n");
    code = compile("bad.c", {{Join(project, "bad.c"), false}}, true);
    assert(code != 0 && !output.err.empty() && output.out.empty());
    writeFile(Join(project, "missing.c"), "int absent(void); int main(void) { return absent(); }\n");
    code = compile("missing.c", {{Join(project, "missing.c"), false}}, true);
    assert(code != 0 && output.err.find("undefined") != std::string::npos && output.out.empty());
    puts("PASS: compile/link diagnostics; existing stale program.so is never executed");

    std::string resolvedProject(project), resolvedEntry(Join(project, "main.C"));
    std::vector<Source> invalid = {{Join(project, "helper.CPP"), true}};
    assert(!ValidateSources(&resolvedProject, &resolvedEntry, &invalid));
    writeFile(Join(outside, "outside.c"), "int main(void) { return 0; }\n");
    assert(symlink(Join(outside, "outside.c").c_str(), Join(project, "escape.c").c_str()) == 0);
    resolvedProject = project; resolvedEntry = Join(project, "escape.c");
    invalid = {{resolvedEntry, false}};
    assert(!ValidateSources(&resolvedProject, &resolvedEntry, &invalid));
    const std::string cleanup = Join(project, "cleanup"); assert(mkdir(cleanup.c_str(), 0700) == 0);
    assert(symlink(outside.c_str(), Join(cleanup, "project-link").c_str()) == 0);
    assert(symlink(cleanup.c_str(), Join(cleanup, "cycle").c_str()) == 0);
    RemoveTree(cleanup);
    assert(access(Join(outside, "outside.c").c_str(), F_OK) == 0);
    const std::string utf8 = "\xe4\xb8\xad\xf0\x9f\x98\x80";
    for (size_t length = 1; length <= utf8.size(); ++length) {
        const size_t expected = length < 3 ? 0 : (length < 7 ? 3 : 7);
        assert(CompleteUtf8Length(utf8.substr(0, length)) == expected);
    }
    puts("PASS: entry inclusion, canonical symlink containment, safe symlink/cycle cleanup, UTF-8 boundaries");
    close(cancel[0]); close(cancel[1]); RemoveTree(project); RemoveTree(outside);
}
'''
with tempfile.TemporaryDirectory(prefix='ohos-bridge-') as temp:
    cpp = pathlib.Path(temp) / 'test.cpp'
    binary = pathlib.Path(temp) / 'test'
    cpp.write_text(core + fixture)
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-pthread',
                    str(cpp), '-o', str(binary)], check=True)
    executor = pathlib.Path(temp) / 'executor'
    subprocess.run(['gcc', '-Wall', '-Wextra', '-Werror',
                    str(root / 'native/toolchain/ohos-executor.c'), '-ldl', '-o', str(executor)], check=True)
    subprocess.run([str(binary), str(executor), '/usr/bin/clang-15'], check=True, timeout=45)

    # Node implements the same standard NAPI surface as OHOS. Exercise the full
    # actual source, including external handles, TSFN callbacks and finalizers.
    cached_node = root / 'native/build/emsdk-4.0.23/node/22.16.0_64bit'
    node = shutil.which('node') or str(cached_node / 'bin/node')
    includes = pathlib.Path('/usr/include/node')
    if not (includes / 'node_api.h').is_file():
        includes = cached_node / 'include/node'
    if pathlib.Path(node).is_file() and (includes / 'node_api.h').is_file():
        addon_cpp = pathlib.Path(temp) / 'addon.cpp'
        addon = pathlib.Path(temp) / 'runner.node'
        addon_cpp.write_text(source.replace('#include "napi/native_api.h"', '#include <node_api.h>'))
        subprocess.run(['g++', '-std=c++17', '-shared', '-fPIC', '-pthread', '-Wall', '-Wextra',
                        '-Werror', '-Wno-deprecated-declarations', '-I', str(includes),
                        str(addon_cpp), '-o', str(addon)], check=True)
        (pathlib.Path(temp) / 'bin').mkdir()
        (pathlib.Path(temp) / 'bin/ohos.cfg').write_text('\n')
        (pathlib.Path(temp) / 'project').mkdir()
        (pathlib.Path(temp) / 'cache').mkdir()
        script = pathlib.Path(temp) / 'napi.cjs'
        script.write_text(r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const native = require(process.argv[2]);
const base = process.argv[3];
const project = path.join(base, 'project'), cache = path.join(base, 'cache');
function create(callback) {
  const handle = native.create({toolchainRoot: base, executorPath: path.join(base, 'executor'),
    compilerPath: '/usr/bin/clang-15', linkerPath: '/usr/bin/ld', runtimeDirectory: base,
    onEvent: callback});
  assert.ok(handle); return handle;
}
async function run(name, source, mode) {
  const entry = path.join(project, name); fs.writeFileSync(entry, source);
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(Error(`NAPI timeout: ${name}`)), 10000);
    let out = '', err = '', triggered = false;
    const handle = create(event => {
      if (event.kind === 'stdout' || event.kind === 'stderr') {
        assert.ok(!event.text.includes('\ufffd'), 'split UTF-8 was replaced');
        if (event.kind === 'stdout') out += event.text; else err += event.text;
        if (!triggered && out.includes('started') && mode) {
          triggered = true;
          if (mode === 'destroy') { native.destroy(handle); native.destroy(handle); }
          else { native.cancel(handle); native.cancel(handle); }
        }
      } else if (event.kind === 'exit') {
        clearTimeout(timeout);
        native.destroy(handle); native.destroy(handle); native.cancel(handle);
        assert.equal(native.run(handle, project, entry, [entry], cache), false);
        resolve({code: event.exitCode, out, err});
      }
    });
    // Rejected validation must leave the same handle usable for a valid retry.
    assert.equal(native.run(handle, project, entry, [entry, '/etc/passwd'], cache), false);
    assert.equal(native.run(handle, project, entry, [entry], cache), true);
    assert.equal(native.run(handle, project, entry, [entry], cache), false);
  });
}
(async () => {
  const unicode = await run('unicode.c', '#define _DEFAULT_SOURCE\n#include <unistd.h>\nint main(void){const char s[]="\\xe4\\xb8\\xad\\xf0\\x9f\\x98\\x80";for(unsigned i=0;i<sizeof(s)-1;i++){write(1,s+i,1);usleep(10000);}return 7;}\n');
  assert.deepEqual(unicode, {code: 7, out: '\u4e2d\ud83d\ude00', err: ''});
  const sleeper = '#include <unistd.h>\nint main(void){write(1,"started\\n",8);close(1);close(2);for(;;)sleep(10);}\n';
  assert.equal((await run('cancel.c', sleeper, 'cancel')).code, 130);
  assert.equal((await run('destroy.c', sleeper, 'destroy')).code, 130);
  const unused = create(() => {}); native.destroy(unused); native.destroy(unused); native.cancel(unused);
  if (global.gc) global.gc();
  console.log('PASS: full actual NAPI callbacks, UTF-8 byte splits, validation retry, single-use run, cancel/destroy/GC lifecycle');
})().catch(error => { console.error(error); process.exit(1); });
''')
        subprocess.run([node, '--expose-gc', str(script), str(addon), temp], check=True, timeout=40)
    else:
        print('SKIP: full host NAPI addon check requires Linux Node and node_api.h')
