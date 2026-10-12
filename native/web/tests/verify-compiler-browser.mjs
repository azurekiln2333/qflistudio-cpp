import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { cases, fixture, repo } from "./fixtures.mjs";

for (const name of ["qfli-compiler.js", "qfli-compiler.wasm", "qfli-compiler.data"]) {
  if (!fs.existsSync(path.join(repo, "web/toolchain", name))) {
    throw new Error(`Build the browser compiler first: missing web/toolchain/${name}`);
  }
}
const { chromium } = createRequire(import.meta.url)(process.env.QFLI_PLAYWRIGHT_MODULE || "playwright");
const server = http.createServer((request, response) => {
  const relative = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const filename = path.resolve(repo, `.${relative}`);
  if (filename !== repo && !filename.startsWith(repo + path.sep)) { response.writeHead(403).end(); return; }
  if (relative === "/") {
    response.writeHead(200, { "Content-Type": "text/html" }).end("<!doctype html><title>Browser Compiler Test</title>");
    return;
  }
  if (!fs.existsSync(filename) || !fs.statSync(filename).isFile()) { response.writeHead(404).end(); return; }
  response.writeHead(200, {
    "Content-Type": filename.endsWith(".wasm") ? "application/wasm" : filename.endsWith(".data") ? "application/octet-stream" : "text/javascript",
    "Cache-Control": "public, max-age=3600",
  });
  fs.createReadStream(filename).pipe(response);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, channel: process.env.QFLI_BROWSER_CHANNEL || "chrome" });
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  async function compile(files, entryFile, cancelWhenReady = false) {
    return page.evaluate(({ files, entryFile, cancelWhenReady }) => new Promise((resolve, reject) => {
      const worker = new Worker("/web/forge-worker.bundle.js", { type: "module" });
      const events = [];
      const stop = (error) => {
        clearTimeout(timeout);
        worker.terminate();
        if (error) reject(error); else resolve(events);
      };
      const timeout = setTimeout(() => stop(new Error(`Compiler timed out: ${JSON.stringify(events.slice(-5))}`)), 180000);
      worker.onerror = (error) => stop(new Error(error.message));
      worker.onmessage = ({ data }) => {
        events.push(data.kind !== "files" ? data : {
          ...data, files: data.files.map(({ path, bytes, directory }) => directory ?
            { path, directory } : { path, bytes: [...bytes] }),
        });
        if (cancelWhenReady && data.kind === "stdout" && data.text === "ready") {
          events.push({ kind: "exit", exitCode: 130 });
          stop();
        } else if (data.kind === "exit") stop();
      };
      worker.postMessage({ runId: "compiler-test", entryFile,
        files: files.map(({ path, bytes, directory }) => directory ?
          { path, directory } : { path, bytes: new Uint8Array(bytes) }),
      });
    }), { files: files.map(({ path, bytes, directory }) => directory ?
      { path, directory } : { path, bytes: [...bytes] }), entryFile, cancelWhenReady });
  }
  for (const [name, code, stdout, stderr] of cases) {
    const files = fixture(name).files.filter(({ path }) => !/^(actual|expected)\.(stdout|stderr)$/.test(path));
    const entryFile = files.find(({ path }) => /(^|\/)main\.(c|cpp)$/i.test(path)).path;
    const events = await compile(files, entryFile);
    assert.equal(events.at(-1).exitCode, code, `${name}: ${JSON.stringify(events)}`);
    assert.deepEqual(events.filter((event) => event.kind === "stdout").map((event) => event.text), stdout);
    assert.deepEqual(events.filter((event) => event.kind === "stderr").map((event) => event.text), stderr);
    if (name === "files") {
      const output = events.find((event) => event.kind === "files").files.find((file) => file.path === "output.txt");
      assert.ok(output, "new output.txt must be returned");
      assert.equal(new TextDecoder().decode(new Uint8Array(output.bytes)), "42\n");
    }
    console.log(`PASS browser compilation and execution ${name}: exit ${code}`);
  }
  for (const [name, source, diagnostic] of [
    ["syntax", "int main(void) { int value = ; }\n", /error:/],
    ["link", "extern int missing(void); int main(void) { return missing(); }\n", /undefined symbol/],
  ]) {
    const events = await compile([{ path: "main.c", bytes: new TextEncoder().encode(source) }], "main.c");
    assert.notEqual(events.at(-1).exitCode, 0);
    assert.match(events.filter((event) => event.kind === "stderr").map((event) => event.text).join("\n"), diagnostic);
    assert.equal(events.some((event) => event.kind === "stdout" || event.kind === "files"), false);
    console.log(`PASS browser ${name} diagnostics prevent execution`);
  }
  const cancelled = await compile(fixture("cancel").files, "main.c", true);
  assert.equal(cancelled.at(-1).exitCode, 130);
  console.log("PASS browser-compiled infinite-program cancellation");
} finally {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
}
