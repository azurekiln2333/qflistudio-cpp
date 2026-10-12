import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const stage = path.join(repo, "native/build/forge-web-review");
const core = path.join(repo, "native/build/shared-core-web-review/updated");
if (!fs.existsSync(path.join(core, "lib/services/platform_io_browser.dart"))) {
  throw new Error("Prepare the reviewed shared-core copy first");
}
fs.mkdirSync(stage, { recursive: true });
for (const name of ["lib", "assets", "test", "web", "packages/qfli_c_runtime"]) {
  const source = path.join(repo, name);
  fs.cpSync(source, path.join(stage, name), {
    recursive: true,
    filter: (entry) => ![".dart_tool", "build", ".git"].includes(path.basename(entry)),
  });
}
for (const name of ["pubspec.yaml", "pubspec.lock", "analysis_options.yaml"]) {
  fs.copyFileSync(path.join(repo, name), path.join(stage, name));
}
fs.writeFileSync(path.join(stage, "pubspec_overrides.yaml"), [
  "dependency_overrides:",
  "  qfli_studio_core:",
  "    path: ../shared-core-web-review/updated",
  "  re_editor:",
  "    path: ../shared-core-web-review/updated/vendor/re_editor",
  "",
].join("\n"));
console.log(`Forge review copy: ${stage}`);
console.log("Run offline dependency resolution, analysis and Flutter builds in that directory.");
console.log("This copy does not modify the sibling shared-core repository.");
