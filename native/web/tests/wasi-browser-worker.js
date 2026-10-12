import { executeWasm } from "../../../web/forge-wasi.js";

self.onmessage = async ({ data: { bytes, files } }) => {
  const result = await executeWasm(bytes, files, (event) => self.postMessage(event));
  self.postMessage({ kind: "files", files: result.files });
  self.postMessage({ kind: "exit", exitCode: result.exitCode });
};
