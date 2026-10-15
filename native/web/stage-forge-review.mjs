import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const stage = path.join(repo, "native/build/forge-web-review");
const core = path.join(repo, "native/build/shared-core-web-review/updated");
const browserFacades = ["platform_io_browser.dart", "platform_path_browser.dart"];
for (const name of browserFacades) {
  if (!fs.existsSync(path.join(core, "lib/services", name))) {
    throw new Error(`Prepare the reviewed shared-core copy first: ${name}`);
  }
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
// The runner, editor and project store must use the same memory filesystem.
// Forward only the staged app's browser facades to the reviewed shared core;
// copying the local browser implementation would create a second singleton.
for (const name of browserFacades) {
  fs.writeFileSync(path.join(stage, "lib/platform", name),
    `export 'package:qfli_studio_core/services/${name}';\n`);
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
