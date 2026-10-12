import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const source = path.resolve(repo, "../qfli_studio_core");
const task = path.join(repo, ".trellis/tasks/10-01-cross-platform-native-runtime");
const templates = path.join(task, "patches/shared-core-platform");
const stage = path.join(repo, "native/build/shared-core-web-review");
const base = path.join(stage, "base");
const updated = path.join(stage, "updated");
const tests = ["platform_storage_native_test.dart", "platform_storage_browser_test.dart",
  "code_editor_browser_input_test.dart"];
const vendorFiles = ["_code_field.dart", "_code_editable.dart", "_code_input.dart", "_code_shortcuts.dart"]
  .map((name) => `vendor/re_editor/lib/src/${name}`);
fs.mkdirSync(stage, { recursive: true });
for (const target of [base, updated]) {
  fs.mkdirSync(target, { recursive: true });
  fs.cpSync(path.join(source, "lib"), path.join(target, "lib"), { recursive: true });
  fs.copyFileSync(path.join(source, "pubspec.yaml"), path.join(target, "pubspec.yaml"));
}
for (const relative of vendorFiles) {
  const original = path.join(base, relative);
  const replacement = path.join(updated, relative);
  fs.mkdirSync(path.dirname(original), { recursive: true });
  fs.mkdirSync(path.dirname(replacement), { recursive: true });
  fs.copyFileSync(path.join(source, relative), original);
  fs.copyFileSync(path.join(task, "patches/shared-core-vendor", relative.slice("vendor/".length)), replacement);
}

function files(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory() ? files(path.join(directory, entry.name)) : [path.join(directory, entry.name)]);
}
for (const filename of files(path.join(updated, "lib"))) {
  if (!filename.endsWith(".dart")) continue;
  let content = fs.readFileSync(filename, "utf8");
  content = content.replace("import 'package:path/path.dart' as p;",
    "import 'package:qfli_studio_core/services/platform_path.dart' as p;");
  if (!content.includes("import 'dart:io';")) {
    fs.writeFileSync(filename, content);
    continue;
  }
  content = content.replace("import 'dart:io';", "import 'package:qfli_studio_core/services/platform_io.dart';")
    .replace(/\bFile\(/g, "studioFile(")
    .replace(/\bDirectory\(/g, "studioDirectory(")
    .replace(/\bDirectory\.current\b/g, "studioCurrentDirectory")
    .replace(/\bDirectory\.systemTemp\b/g, "studioSystemTemp")
    .replace(/\bFileSystemEntity\.typeSync\(/g, "studioEntityTypeSync(")
    .replace(/\bFileSystemEntity\.type\(/g, "studioEntityType(");
  if (filename.endsWith(`${path.sep}app_paths.dart`)) {
    content = content.replace("final candidates = <String>[];", "if (kIsWeb) {\n      await initializeStudioStorage();\n      return studioCurrentDirectory.path;\n    }\n    final candidates = <String>[];")
      .replace("// 三个 Store 共享一次探测", "if (kIsWeb) {\n      await initializeStudioStorage();\n      return studioCurrentDirectory.path;\n    }\n    // 三个 Store 共享一次探测");
  }
  if (filename.endsWith(`${path.sep}avatar_cache.dart`)) {
    content = content.replace("import 'dart:typed_data';\r\n", "").replace("import 'dart:typed_data';\n", "");
  }
  fs.writeFileSync(filename, content);
}
for (const name of ["platform_io.dart", "platform_io_native.dart", "platform_io_browser.dart",
  "platform_path.dart", "platform_path_native.dart", "platform_path_browser.dart"]) {
  fs.copyFileSync(path.join(templates, name), path.join(updated, "lib/services", name));
}
fs.mkdirSync(path.join(updated, "test"), { recursive: true });
for (const name of tests) {
  fs.copyFileSync(path.join(templates, name), path.join(updated, "test", name));
}
const pubspec = path.join(updated, "pubspec.yaml");
fs.writeFileSync(pubspec, fs.readFileSync(pubspec, "utf8").replace(
  "  path: ^1.9.1", "  path: ^1.9.1\n  file: ^7.0.1\n  web: ^1.1.1"));
const comparison = path.join(stage, "comparison");
for (const [name, directory] of [["base", base], ["updated", updated]]) {
  fs.mkdirSync(path.join(comparison, name), { recursive: true });
  fs.cpSync(path.join(directory, "lib"), path.join(comparison, name, "lib"), { recursive: true });
  fs.copyFileSync(path.join(directory, "pubspec.yaml"), path.join(comparison, name, "pubspec.yaml"));
  for (const relative of vendorFiles) {
    const target = path.join(comparison, name, relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(directory, relative), target);
  }
}
fs.mkdirSync(path.join(comparison, "updated/test"), { recursive: true });
for (const name of tests) {
  fs.copyFileSync(path.join(templates, name), path.join(comparison, "updated/test", name));
}
const result = spawnSync("git", ["-c", "core.autocrlf=false", "diff", "--no-index", "--no-ext-diff", "--", "base", "updated"], {
  cwd: comparison, encoding: "utf8", maxBuffer: 16 * 1024 * 1024,
});
if (![0, 1].includes(result.status)) throw new Error(result.stderr);
const patch = result.stdout.replace(/a\/base\//g, "a/").replace(/b\/updated\//g, "b/")
  .split(/^diff --git /m).slice(1)
  .filter((section) => {
    const header = section.split("\n")[0];
    return / b\/(lib\/.*\.dart|test\/.*\.dart|pubspec\.yaml)$/.test(header) ||
      vendorFiles.some((relative) => header.endsWith(` b/${relative}`));
  })
  .map((section) => `diff --git ${section}`).join("");
const output = path.join(task, "patches/shared-core-web.patch");
fs.writeFileSync(output, patch);
const absolute = source.replaceAll("\\", "/");
const sections = patch.split(/^diff --git /m).slice(1);
const apply = sections.map((section) => {
  const lines = section.split("\n");
  const newFile = lines.includes("new file mode 100644");
  const target = lines.find((line) => line.startsWith("+++ b/"))?.slice(6);
  if (!target) throw new Error(`Cannot identify patch target: ${lines[0]}`);
  const start = lines.findIndex((line) => line.startsWith("@@"));
  let body = lines.slice(start).filter((line) => !line.startsWith("\\ No newline"));
  if (body.at(-1) === "") body.pop();
  if (newFile) {
    body = body.filter((line) => !line.startsWith("@@"));
    return `*** Add File: ${absolute}/${target}\n${body.join("\n")}`;
  }
  body = body.map((line) => line.startsWith("@@") ? "@@" : line);
  return `*** Update File: ${absolute}/${target}\n${body.join("\n")}`;
}).join("\n");
fs.writeFileSync(path.join(task, "patches/shared-core-web.apply-patch"), `*** Begin Patch\n${apply}\n*** End Patch\n`);
console.log(`Prepared current-tree patch: ${output}`);
console.log(`Review copy: ${updated}`);
