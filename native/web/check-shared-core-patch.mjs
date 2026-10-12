import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const updated = path.join(repo, "native/build/shared-core-web-review/updated");
const configFile = path.join(repo, ".dart_tool/package_config.json");
const config = JSON.parse(fs.readFileSync(configFile));
for (const item of config.packages) {
  item.rootUri = new URL(item.rootUri, pathToFileURL(configFile)).href;
  if (item.name === "qfli_studio_core") item.rootUri = pathToFileURL(updated + path.sep).href;
}
const filePackage = "D:/AppData/Local/Pub/Cache/hosted/pub.dev/file-7.0.1/";
config.packages.push({ name: "file", rootUri: pathToFileURL(filePackage).href, packageUri: "lib/", languageVersion: "3.0" });
const configDirectory = path.join(updated, ".dart_tool");
fs.mkdirSync(configDirectory, { recursive: true });
const output = path.join(configDirectory, "package_config.json");
fs.writeFileSync(output, JSON.stringify(config, null, 2));
const runnerTest = path.join(repo, "native/build/forge-web-review/test/web_runner_browser_test.dart");
fs.mkdirSync(path.dirname(runnerTest), { recursive: true });
fs.copyFileSync(path.join(repo, "native/web/tests/web_runner_browser_test.dart"), runnerTest);
const dart = "D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe";
const args = ["analyze", `--packages=${output}`, path.join(updated, "lib"), path.join(updated, "test/platform_storage_browser_test.dart"), path.join(updated, "test/platform_storage_native_test.dart"), path.join(updated, "test/code_editor_browser_input_test.dart"), path.join(repo, "lib/web_clang_runner_browser.dart"), runnerTest];
const result = spawnSync(dart, args, { cwd: updated, encoding: "utf8" });
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
process.exitCode = result.status;
