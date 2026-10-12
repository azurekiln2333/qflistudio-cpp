import { parentPort } from "node:worker_threads";
import { executeWasm } from "../../../web/forge-wasi.js";

parentPort.on("message", async ({ bytes, files }) => {
  const result = await executeWasm(bytes, files, (event) => parentPort.postMessage(event));
  parentPort.postMessage({ kind: "exit", exitCode: result.exitCode });
});
