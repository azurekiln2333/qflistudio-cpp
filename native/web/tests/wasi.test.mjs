import assert from "node:assert/strict";
import test from "node:test";
import { Worker } from "node:worker_threads";
import { once } from "node:events";
import { executeWasm, OutputLines, projectTree } from "../../../web/forge-wasi.js";
import { cases, fixture } from "./fixtures.mjs";

for (const [name, code, stdout, stderr] of cases) {
  test(`actual WASI ${name}`, async () => {
    const events = [];
    const { bytes, files } = fixture(name);
    const result = await executeWasm(bytes, files, (event) => events.push(event));
    assert.equal(result.exitCode, code);
    assert.deepEqual(events.filter((event) => event.kind === "stdout").map((event) => event.text), stdout);
    assert.deepEqual(events.filter((event) => event.kind === "stderr").map((event) => event.text), stderr);
    if (name === "files") {
      assert.equal(new TextDecoder().decode(result.files.find((file) => file.path === "output.txt").bytes), "42\n");
    }
  });
}

test("trap reports an isolated runtime failure", async () => {
  const { bytes, files } = fixture("trap");
  const events = [];
  const result = await executeWasm(bytes, files, (event) => events.push(event));
  assert.equal(result.exitCode, 134);
  assert.match(events.find((event) => event.kind === "stderr").text, /unreachable/);
});

test("output preserves empty lines, fragmented UTF8 and final unterminated text", () => {
  const received = [];
  const output = new OutputLines((line) => received.push(line));
  const bytes = new TextEncoder().encode("\u4e2d\n\nlast");
  output.write(bytes.slice(0, 1));
  output.write(bytes.slice(1, 4));
  output.write(bytes.slice(4));
  output.flush();
  assert.deepEqual(received, ["\u4e2d", "", "last"]);
});

test("project filesystem rejects paths leaving its preopen", () => {
  for (const path of ["../secret", "/secret", "data/../../secret", "data\\secret", "a/./b"]) {
    assert.throws(() => projectTree([{ path, bytes: [] }]), /Invalid project-relative/);
  }
});

test("empty project directories are mapped into the WASI preopen", async () => {
  const { bytes, files } = fixture("io");
  const result = await executeWasm(bytes, [...files, { path: "empty", directory: true }], () => {});
  assert.ok(result.files.some((entry) => entry.path === "empty" && entry.directory));
});

test("worker termination stops an actual infinite Wasm program", async () => {
  const worker = new Worker(new URL("./wasi-node-worker.mjs", import.meta.url));
  try {
    const ready = once(worker, "message");
    worker.postMessage(fixture("cancel"));
    const [event] = await ready;
    assert.equal(event.kind, "stdout");
    assert.equal(event.text, "ready");
    await worker.terminate();
  } finally {
    await worker.terminate();
  }
});
