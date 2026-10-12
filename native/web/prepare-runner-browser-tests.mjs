import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const stage = path.join(repo, "native/build/forge-web-review");
const compiler = path.join(repo, "web/toolchain");
for (const name of ["qfli-compiler.js", "qfli-compiler.wasm", "qfli-compiler.data"]) {
  if (!fs.existsSync(path.join(compiler, name))) throw new Error(`Build browser compiler first: ${name}`);
}
if (!fs.existsSync(path.join(stage, "pubspec_overrides.yaml"))) throw new Error("Stage the Forge review copy first.");
const canvasKit = process.env.QFLI_CANVASKIT || "D:/ProgramFiles/flutter_ohos/bin/cache/flutter_web_sdk/canvaskit";
if (!fs.existsSync(canvasKit)) throw new Error(`Missing SDK CanvasKit directory: ${canvasKit}`);
const tests = path.join(stage, "test");
fs.mkdirSync(tests, { recursive: true });
fs.copyFileSync(path.join(repo, "native/web/tests/web_runner_browser_test.dart"), path.join(tests, "web_runner_browser_test.dart"));
fs.copyFileSync(path.join(repo, "web/forge-worker.bundle.js"), path.join(tests, "forge-worker.bundle.js"));
fs.cpSync(compiler, path.join(tests, "toolchain"), { recursive: true });
fs.cpSync(canvasKit, path.join(tests, "canvaskit"), { recursive: true });
console.log(`Browser runner gate prepared in ${stage}`);
console.log("Run flutter test --no-pub --platform=chrome test/web_runner_browser_test.dart from that scratch directory.");
