import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { cases, fixture, repo } from "./fixtures.mjs";

const { chromium } = createRequire(import.meta.url)(process.env.QFLI_PLAYWRIGHT_MODULE || "playwright");
const server = http.createServer((request, response) => {
  const filename = path.resolve(repo, `.${decodeURIComponent(new URL(request.url, "http://localhost").pathname)}`);
  if (filename !== repo && !filename.startsWith(repo + path.sep)) { response.writeHead(403).end(); return; }
  if (!fs.existsSync(filename) || !fs.statSync(filename).isFile()) {
    response.writeHead(200, { "Content-Type": "text/html" }).end("<!doctype html><title>WASI Test</title>");
    return;
  }
  response.writeHead(200, { "Content-Type": filename.endsWith(".wasm") ? "application/wasm" : "text/javascript" });
  fs.createReadStream(filename).pipe(response);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const browser = await chromium.launch({ headless: true, channel: process.env.QFLI_BROWSER_CHANNEL || 'chrome' });
try {
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  for (const [name, code, stdout, stderr] of cases) {
    const { bytes, files } = fixture(name);
    const events = await page.evaluate(({ bytes, files }) => new Promise((resolve, reject) => {
      const worker = new Worker("/native/web/tests/wasi-browser-worker.js", { type: "module" });
      const events = [];
      worker.onerror = (error) => { worker.terminate(); reject(new Error(error.message)); };
      worker.onmessage = ({ data }) => {
        events.push(data);
        if (data.kind === "exit") {
          worker.terminate();
          resolve(events.map((event) => event.kind !== "files" ? event : {
            ...event, files: event.files.map(({ path, bytes, directory }) => directory ?
              { path, directory } : { path, bytes: [...bytes] }),
          }));
        }
      };
      worker.postMessage({ bytes: new Uint8Array(bytes), files: files.map(({ path, bytes }) => ({ path, bytes: new Uint8Array(bytes) })) });
    }), { bytes: [...bytes], files: files.map(({ path, bytes }) => ({ path, bytes: [...bytes] })) });
    assert.equal(events.at(-1).exitCode, code);
    assert.deepEqual(events.filter((event) => event.kind === "stdout").map((event) => event.text), stdout);
    assert.deepEqual(events.filter((event) => event.kind === "stderr").map((event) => event.text), stderr);
    if (name === "files") {
      const output = events.find((event) => event.kind === "files").files.find((file) => file.path === "output.txt");
      assert.ok(output, "new output.txt must be included in the writeback payload");
      assert.equal(new TextDecoder().decode(new Uint8Array(output.bytes)), "42\n");
    }
    console.log(`PASS Chromium worker ${name}: exit ${code}`);
  }
  const cancel = fixture("cancel");
  assert.equal(await page.evaluate(({ bytes, files }) => new Promise((resolve, reject) => {
    const worker = new Worker("/native/web/tests/wasi-browser-worker.js", { type: "module" });
    worker.onerror = (error) => reject(new Error(error.message));
    worker.onmessage = ({ data }) => {
      if (data.kind === "stdout" && data.text === "ready") {
        worker.terminate();
        resolve(130);
      }
    };
    worker.postMessage({ bytes: new Uint8Array(bytes), files: files.map(({ path, bytes }) => ({ path, bytes: new Uint8Array(bytes) })) });
  }), { bytes: [...cancel.bytes], files: cancel.files.map(({ path, bytes }) => ({ path, bytes: [...bytes] })) }), 130);
  console.log("PASS Chromium worker infinite-program cancellation");
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
