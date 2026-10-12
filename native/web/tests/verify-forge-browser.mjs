import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const root = path.join(repo, "native/build/forge-web-review/build/web");
const screenshots = path.join(repo, "native/build/forge-web-review/screenshots");
const runtime = process.env.QFLI_PLAYWRIGHT_MODULE || "playwright";
const accessibility = process.env.QFLI_ACCESSIBILITY !== "false";
const verifyRun = process.env.QFLI_VERIFY_RUN === "true";
const { chromium } = createRequire(import.meta.url)(runtime);
const mime = {
  ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".wasm": "application/wasm", ".css": "text/css",
  ".png": "image/png", ".ttf": "font/ttf", ".woff2": "font/woff2",
};
assert.ok(fs.existsSync(path.join(root, "main.dart.js")), "Build the Forge review app first");
if (verifyRun) {
  assert.ok(accessibility, "Runtime UI checks require accessible controls");
  for (const name of ["qfli-compiler.js", "qfli-compiler.wasm", "qfli-compiler.data"]) {
    assert.ok(fs.existsSync(path.join(root, "toolchain", name)), `Missing browser compiler: ${name}`);
  }
}
fs.mkdirSync(screenshots, { recursive: true });
const server = http.createServer((request, response) => {
  const filename = path.resolve(root, `.${decodeURIComponent(new URL(request.url, "http://localhost").pathname)}`);
  if (filename !== root && !filename.startsWith(root + path.sep)) {
    response.writeHead(403).end();
    return;
  }
  const source = filename === root ? path.join(root, "index.html") : filename;
  if (!fs.existsSync(source) || !fs.statSync(source).isFile()) {
    response.writeHead(404).end();
    return;
  }
  response.writeHead(200, { "Content-Type": mime[path.extname(source)] || "application/octet-stream" });
  fs.createReadStream(source).pipe(response);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const browser = await chromium.launch({ headless: true, channel: process.env.QFLI_BROWSER_CHANNEL || "chrome" });
try {
  const origin = `http://127.0.0.1:${server.address().port}`;
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin });
  const page = await context.newPage();
  const snapshot = () => page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open("qfli-studio-forge", 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result;
      const read = database.transaction("filesystem", "readonly").objectStore("filesystem").get("snapshot");
      read.onerror = () => { database.close(); reject(read.error); };
      read.onsuccess = () => {
        database.close();
        resolve(read.result ? JSON.parse(read.result) : null);
      };
    };
  }));
  const sourcePath = "/qfli/projects/cProjects/Browser C Verify/src/main.c";
  const savedSource = async () => {
    const entry = (await snapshot())?.entries.find((entry) => entry.path === sourcePath);
    return entry?.bytes ? Buffer.from(entry.bytes, "base64").toString("utf8") : null;
  };
  await page.addInitScript(() => {
    window.addEventListener("error", (event) => {
      if (event.error?.dartException) console.error(`DART ERROR: ${String(event.error)}`);
    });
  });
  page.on("pageerror", (error) => console.error(`PAGE ERROR: ${error.stack || error}`));
  page.on("console", (message) => {
    if (message.type() === "error") console.error(`BROWSER ERROR: ${message.text()}`);
  });
  page.on("requestfailed", (request) => console.error(`REQUEST FAILED: ${request.url()} ${request.failure()?.errorText}`));
  page.on("response", (response) => {
    if (response.status() >= 400) console.error(`HTTP ${response.status()}: ${response.url()}`);
  });
  await page.goto(origin);
  if (accessibility) {
    await page.getByRole("button", { name: "Enable accessibility" }).dispatchEvent("click", { timeout: 30000 });
  }
  await page.waitForTimeout(5000);
  if (accessibility) console.log(await page.locator("body").ariaSnapshot());
  await page.screenshot({ path: path.join(screenshots, "desktop-home.png") });
  if (accessibility) {
    await page.getByRole("button", { name: "新建项目", exact: true }).last().click();
  } else {
    await page.mouse.click(1193, 855);
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(screenshots, "desktop-create.png") });
  }
  const dialog = accessibility ? await page.locator("body").ariaSnapshot() : "";
  console.log("CREATE DIALOG", dialog);
  assert.ok(!dialog.includes("http://"), "Project location must be a virtual filesystem path");
  if (accessibility) {
    await page.getByRole("textbox", { name: "项目名称", exact: true }).fill("Browser C Verify");
    await page.getByRole("button", { name: "创建", exact: true }).click();
    await page.getByRole("button", { name: "运行", exact: true }).waitFor();
  } else {
    await page.mouse.click(600, 399);
    await page.keyboard.insertText("Browser C Verify");
    await page.waitForTimeout(300);
    await page.mouse.click(811, 556);
  }
  if (accessibility) console.log("EDITOR", await page.locator("body").ariaSnapshot());
  await page.waitForTimeout(5000);
  await page.screenshot({ path: path.join(screenshots, "desktop-editor.png") });
  let source = '#include <stdio.h>\nint main(void) { puts("ui_saved"); return 0; }\n';
  await page.mouse.click(220, 155);
  console.log("BEFORE INPUT", await page.locator("textarea,input:not([type=submit])").evaluateAll((elements) =>
    elements.map((element) => ({ tag: element.tagName, value: element.value, focused: element === document.activeElement }))));
  await page.keyboard.press("Control+A");
  if (process.env.QFLI_INPUT_MODE === "clipboard") {
    await page.evaluate((text) => navigator.clipboard.writeText(text), source);
    await page.keyboard.press("Control+V");
    await page.waitForTimeout(300);
    await page.keyboard.insertText("//typed");
    source += "//typed";
  } else {
    await page.keyboard.insertText(source);
  }
  await page.waitForTimeout(500);
  console.log("AFTER INPUT", await page.locator("textarea,input:not([type=submit])").evaluateAll((elements) =>
    elements.map((element) => ({ tag: element.tagName, value: element.value, focused: element === document.activeElement }))));
  await page.screenshot({ path: path.join(screenshots, "desktop-edited.png") });
  await page.keyboard.press("Control+S");
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(screenshots, "desktop-after-save.png") });
  if (process.env.QFLI_SAVE_MODE === "menu") {
    if (accessibility) {
      await page.getByRole("button", { name: "更多", exact: true }).click();
      await page.getByText("保存 (Ctrl+S)", { exact: true }).click();
    } else {
      await page.mouse.click(1252, 27);
      await page.waitForTimeout(300);
      await page.screenshot({ path: path.join(screenshots, "desktop-save-menu.png") });
      await page.mouse.click(1150, 40);
    }
  }
  const deadline = Date.now() + 10000;
  while (await savedSource() !== source && Date.now() < deadline) {
    await page.waitForTimeout(100);
  }
  assert.equal(await savedSource(), source, "Editor input must reach the exact project file");
  console.log(`PASS editor ${process.env.QFLI_SAVE_MODE === "menu" ? "menu" : "keyboard"} save reaches IndexedDB`);
  console.log("SAVED SOURCE", await savedSource());
  await page.reload();
  if (accessibility) {
    await page.getByRole("button", { name: "Enable accessibility" }).dispatchEvent("click");
    await page.getByRole("heading", { name: /QFLIForge|Browser C Verify/ }).waitFor();
  } else {
    await page.waitForTimeout(5000);
  }
  if (accessibility) console.log("RELOADED", await page.locator("body").ariaSnapshot());
  if (!accessibility) {
    await page.screenshot({ path: path.join(screenshots, "desktop-projects.png") });
    await page.mouse.click(400, 110);
    await page.waitForTimeout(1000);
  } else if (await page.getByRole("button", { name: "运行", exact: true }).count() === 0) {
    await page.getByRole("group", { name: /Browser C Verify/ }).click();
  }
  if (accessibility) await page.getByRole("button", { name: "运行", exact: true }).waitFor();
  await page.mouse.click(220, 155);
  await page.keyboard.press("Control+A");
  await page.evaluate(() => navigator.clipboard.writeText("reopen-check-pending"));
  await page.keyboard.press("Control+C");
  const copiedSource = () => page.evaluate(async () => (await navigator.clipboard.readText()).replace(/\r\n/g, "\n"));
  const copyDeadline = Date.now() + 10000;
  while (await copiedSource() !== source && Date.now() < copyDeadline) {
    await page.waitForTimeout(100);
  }
  const reopenedSource = await copiedSource();
  assert.equal(reopenedSource, source, "Reopened editor must contain the saved source");
  console.log("PASS saved source is reopened by the editor");
  console.log("EDITOR INPUT", await page.locator("textarea,input").evaluateAll((elements) =>
    elements.map((element) => ({ tag: element.tagName, value: element.value }))));
  await page.keyboard.press("ArrowRight");
  if (accessibility) console.log("REOPEN", await page.locator("body").ariaSnapshot());
  await page.screenshot({ path: path.join(screenshots, "desktop-reopened.png") });
  if (verifyRun) {
    await page.getByRole("button", { name: "运行", exact: true }).click();
    await page.getByText("ui_saved", { exact: true }).waitFor({ timeout: 180000 });
    await page.getByText("（运行结束，退出码 0）", { exact: true }).waitFor();
    console.log("PASS saved C program compiles and runs through the UI");
    await page.screenshot({ path: path.join(screenshots, "desktop-run.png") });
    const infinite = '#include <stdio.h>\nint main(void) { puts("ui_stop_ready"); fflush(stdout); for (;;) {} }\n';
    await page.mouse.click(220, 155);
    await page.keyboard.press("Control+A");
    await page.keyboard.insertText(infinite);
    await page.keyboard.press("Control+S");
    const saveDeadline = Date.now() + 10000;
    while (await savedSource() !== infinite && Date.now() < saveDeadline) {
      await page.waitForTimeout(100);
    }
    assert.equal(await savedSource(), infinite, "Infinite program must be saved before execution");
    await page.getByRole("button", { name: "运行", exact: true }).click();
    await page.getByText("ui_stop_ready", { exact: true }).waitFor({ timeout: 180000 });
    await page.getByRole("button", { name: "停止", exact: true }).click();
    await page.getByText("（运行结束，退出码 130）", { exact: true }).waitFor();
    console.log("PASS infinite C program stops through the UI with exit 130");
    await page.screenshot({ path: path.join(screenshots, "desktop-stopped.png") });
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(screenshots, "mobile-editor.png") });
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
