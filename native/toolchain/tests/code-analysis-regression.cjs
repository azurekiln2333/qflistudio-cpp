// Invoked by the actual Clang/WasmEdge NAPI bridge harness, never a mock compiler.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

module.exports = async function(native, project, cache, sdk) {
  for (const name of fs.readdirSync(project)) fs.rmSync(path.join(project, name), {recursive:true, force:true});
  const main = path.join(project, 'main.cpp');
  const header = path.join(project, 'include', 'nested', 'local.h');
  const alias = path.join(project, 'include', 'alias.h');
  const escape = path.join(project, 'include', 'escape.h');
  const foreignDirectory = fs.mkdtempSync(path.join(path.dirname(project), 'analysis-foreign-'));
  const foreignHeader = path.join(foreignDirectory, 'private.h');
  const foreignSecret = 'QFLI_ANALYSIS_FOREIGN_SECRET_TOKEN';
  fs.mkdirSync(path.dirname(header), {recursive:true});
  fs.writeFileSync(header, '#define VALUE 7\n');
  fs.writeFileSync(foreignHeader, `#define QFLI_FOREIGN_VALUE ${foreignSecret}\n`);
  fs.symlinkSync(path.relative(path.dirname(alias), header), alias);
  fs.symlinkSync(foreignHeader, escape);
  const disk = '#include <cstdio>\nint main(){std::FILE *f=std::fopen("MUST_NOT_RUN","w");if(f)std::fclose(f);return 0;}';
  fs.writeFileSync(main, disk);
  fs.writeFileSync(path.join(project, 'program.wasm'), 'preexisting output must survive');
  function digest() {
    const result = [];
    function walk(directory) {
      for (const item of fs.readdirSync(directory, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
        const filename = path.join(directory,item.name);
        if (item.isDirectory()) walk(filename);
        else result.push([path.relative(project,filename),crypto.createHash('sha256').update(fs.readFileSync(filename)).digest('hex')]);
      }
    }
    walk(project); return result;
  }
  const before = digest(), cwd = process.cwd();
  async function analyze(documents, {active = main, cpp = true, preCancel = false, cancel = false} = {}) {
    return new Promise((resolve,reject) => {
      let out = '', err = '', exits = 0;
      const handle = native.create({toolchainRoot:sdk, onEvent:event => {
        if (event.kind === 'stdout') out += event.text;
        else if (event.kind === 'stderr') err += event.text;
        else if (event.kind === 'exit') {
          clearTimeout(timer);
          assert.equal(++exits,1);
          native.destroy(handle);
          assert.deepEqual(fs.readdirSync(cache),[]);
          assert.equal(process.cwd(),cwd);
          resolve({code:event.exitCode,out,err});
        } else reject(Error('unknown analysis event'));
      }});
      const timer = setTimeout(() => {native.cancel(handle);reject(Error('analysis timeout'));},20000);
      if (preCancel) native.cancel(handle);
      assert.equal(native.analyze(handle,project,active,cpp,documents,cache),true);
      assert.equal(native.analyze(handle,project,active,cpp,documents,cache),false);
      if (cancel) setTimeout(() => native.cancel(handle),1);
    });
  }
  const source = '#include "include/nested/local.h"\r\n// 汉字😀\r\nint main(){return VALUE + missing_name;}\r\n';
  let result = await analyze([{path:main,text:source},{path:header,text:'#define VALUE 11\r\n'}]);
  assert.equal(result.code,1); assert.equal(result.err,'');
  let response = JSON.parse(result.out);
  assert.equal(response.unmappedErrors,false);
  const diagnostic = response.diagnostics.find(item=>item.message.includes('missing_name'));
  assert.ok(diagnostic,JSON.stringify(response));
  assert.equal(diagnostic.filePath,main);
  const bytes = Buffer.from(source);
  assert.equal(diagnostic.startByte,bytes.indexOf(Buffer.from('missing_name')));
  assert.equal(diagnostic.endByte,diagnostic.startByte+12);
  assert.equal(bytes.subarray(diagnostic.startByte,diagnostic.endByte).toString(),'missing_name');

  result = await analyze([{path:main,text:'#include "include/nested/local.h"\r\nint main(){return value;}\r\n'},
    {path:header,text:'// 头😀\r\ninline int value = unknown_header_name;\r\n'}]);
  assert.equal(result.code,1);
  response = JSON.parse(result.out);
  assert.equal(response.unmappedErrors,false);
  assert.ok(response.diagnostics.some(item=>item.filePath===header&&item.message.includes('unknown_header_name')));

  // A header which is active but disconnected from other open translation
  // units must be analyzed instead of returning their unrelated clean status.
  result = await analyze([{path:main,text:'int main(){return 0;}'},
    {path:header,text:'// 头😀\r\ninline int answer(){return disconnected_header_error;}\r\n'}],{active:header});
  assert.equal(result.code,1);
  response = JSON.parse(result.out);
  assert.equal(response.unmappedErrors,false);
  assert.ok(response.diagnostics.some(item=>item.filePath===header&&item.message.includes('disconnected_header_error')));

  // Conversely, a header actually entered by a TU must keep that TU's context.
  // Parsing it again independently would invent an unknown ContextualType.
  result = await analyze([{path:main,text:'using ContextualType = int;\n#include "include/nested/local.h"\nint main(){return contextual;}\n'},
    {path:header,text:'inline ContextualType contextual = 1;\n'}],{active:header});
  assert.equal(result.code,0,result.err + result.out);
  assert.deepEqual(JSON.parse(result.out),{diagnostics:[],unmappedErrors:false});

  // Overlay lookup follows an in-project physical alias before reading, while
  // returned locations retain the caller's original snapshot alias spelling.
  const aliasText = '// 别名😀\r\ninline int aliased = dirty_alias_error;\r\n';
  result = await analyze([{path:main,text:'#include "include/alias.h"\nint main(){return aliased;}'},
    {path:alias,text:aliasText}],{active:alias});
  assert.equal(result.code,1);
  response = JSON.parse(result.out);
  assert.equal(response.unmappedErrors,false);
  const aliasDiagnostic = response.diagnostics.find(item=>item.message.includes('dirty_alias_error'));
  assert.ok(aliasDiagnostic,JSON.stringify(response));
  assert.equal(aliasDiagnostic.filePath,alias);
  assert.equal(aliasDiagnostic.startByte,Buffer.from(aliasText).indexOf(Buffer.from('dirty_alias_error')));
  assert.equal(aliasDiagnostic.endByte,aliasDiagnostic.startByte+'dirty_alias_error'.length);
  assert.equal(response.diagnostics.filter(item=>item.severity==='error').length,1,JSON.stringify(response));
  assert.ok(!response.diagnostics.some(item=>item.filePath===main),JSON.stringify(response));

  // An include may not read unrelated application files through an absolute
  // path, a .. traversal, or an in-project symlink. If it were read, its macro
  // would expose the private token in a main-file expansion diagnostic.
  for (const include of [foreignHeader, path.relative(project,foreignHeader), 'include/escape.h']) {
    result = await analyze([{path:main,text:`#include ${JSON.stringify(include)}\nint main(){return QFLI_FOREIGN_VALUE;}\n`}]);
    assert.equal(result.code,1,include + result.err + result.out);
    response = JSON.parse(result.out);
    assert.equal(response.unmappedErrors,false,JSON.stringify(response));
    assert.ok(response.diagnostics.some(item=>item.filePath===main&&item.severity==='error'&&
      /file not found|permission denied/i.test(item.message)),JSON.stringify(response));
    assert.ok(!JSON.stringify(response).includes(foreignSecret),JSON.stringify(response));
  }

  // A closed header error cannot be silently reported as a clean open buffer.
  fs.writeFileSync(header,'inline int value = closed_header_error;\n');
  result = await analyze([{path:main,text:'#include "include/nested/local.h"\nint main(){return value;}'}]);
  assert.equal(result.code,1); assert.equal(JSON.parse(result.out).unmappedErrors,true);
  fs.writeFileSync(header,'#define VALUE 7\n');
  // Both open translation units are checked; the valid active buffer cannot
  // conceal another dirty buffer, including one not yet written to disk.
  const other = path.join(project,'new_unsaved.c');
  result = await analyze([{path:main,text:disk},{path:other,text:'int helper(void){return broken_c_name;}'}]);
  assert.equal(result.code,1);
  assert.ok(JSON.parse(result.out).diagnostics.some(item=>item.filePath===other&&item.message.includes('broken_c_name')));
  assert.equal(fs.existsSync(other),false);

  result = await analyze([{path:main,text:disk}]);
  assert.equal(result.code,0); assert.equal(result.err,'');
  assert.deepEqual(JSON.parse(result.out),{diagnostics:[],unmappedErrors:false});
  assert.equal(fs.existsSync(path.join(project,'MUST_NOT_RUN')),false);
  assert.deepEqual(digest(),before);
  const singleHeader = await analyze([{path:header,text:'inline int answer(){return 42;}'}],{active:header});
  assert.equal(singleHeader.code,0);

  result = await analyze([{path:main,text:disk}],{preCancel:true}); assert.equal(result.code,130);
  result = await analyze([{path:main,text:'int a;\n'.repeat(200000)}],{cancel:true}); assert.equal(result.code,130);
  result = await analyze([{path:main,text:disk}]); assert.equal(result.code,0);
  const outside = path.join(path.dirname(project),'foreign.c');
  result = await analyze([{path:outside,text:'int x;'}],{active:outside}); assert.equal(result.code,127);
  result = await analyze([{path:main,text:disk},{path:main,text:disk}]); assert.equal(result.code,127);
  assert.deepEqual(digest(),before);
  console.log('PASS: actual Clang analysis dirty CRLF/UTF8 source/header ranges, all open units, disconnected/contextual active headers, dirty symlink aliases, physical include confinement, unavailable closed-file errors, no source/output writes or execution, cancellation and fresh recovery');
};
