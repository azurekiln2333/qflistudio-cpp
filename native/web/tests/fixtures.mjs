import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const generated = path.join(repo, "native/build/portable-fixtures");
export const fixtureRoot = process.env.QFLI_WASI_FIXTURES || fs.readdirSync(generated)
  .map((name) => path.join(generated, name))
  .filter((directory) => fs.existsSync(path.join(directory, "exceptions/.qfli/build/program.wasm")))
  .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0];
if (!fixtureRoot) throw new Error("Run verify-portable-wasm.sh first, or set QFLI_WASI_FIXTURES.");

export function projectFiles(directory, prefix = "") {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const relative = prefix + entry.name;
    if (entry.name === ".qfli") return [];
    return entry.isDirectory() ? projectFiles(path.join(directory, entry.name), `${relative}/`) :
      [{ path: relative, bytes: new Uint8Array(fs.readFileSync(path.join(directory, entry.name))) }];
  });
}

export function fixture(name) {
  const directory = path.join(fixtureRoot, name);
  return {
    bytes: new Uint8Array(fs.readFileSync(path.join(directory, ".qfli/build/program.wasm"))),
    files: projectFiles(directory).filter((file) => name !== "files" || file.path !== "output.txt"),
  };
}

export const cases = [
  ["mixed_c_main", 0, ["42"], []],
  ["mixed_case", 0, ["42"], []],
  ["math", 0, ["4.000000"], []],
  ["io", 0, ["input=42"], ["input accepted"]],
  ["nonzero", 7, ["before exit"], ["intentional failure"]],
  ["exceptions", 0, ["exception preserved; destructors=2", "stdlib exception caught"], []],
  ["files", 0, ["file=42"], []],
];
