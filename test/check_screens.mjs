import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { readFileSync, readdirSync, mkdtempSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";

const [chromium, site] = process.argv.slice(2);
const screenWidth = 2560, screenHeight = 1440;
const runningTextWordsLimit = 1449;
const sentencesPerEntryLimit = 2;
const desktops = [[2560, 1440], [1920, 1080]];
const phoneWidth = 390, phoneHeight = 844;
const types = { html: "text/html", css: "text/css", mjs: "text/javascript", js: "text/javascript", wasm: "application/wasm" };
const server = createServer((request, response) => {
  const name = request.url === "/" ? "index.html" : request.url.slice(1).split("?")[0];
  try {
    const body = readFileSync(`${site}/${name}`);
    response.writeHead(200, { "content-type": types[name.split(".").pop()] ?? "text/plain" });
    response.end(body);
  } catch {
    response.writeHead(404).end();
  }
}).listen(0, "127.0.0.1");
await new Promise(done => server.once("listening", done));
const origin = `http://127.0.0.1:${server.address().port}`;
const debugPort = 20000 + Math.floor(Math.random() * 20000);
const browser = spawn(chromium, ["--headless", "--no-sandbox", "--disable-gpu", `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${mkdtempSync(`${tmpdir()}/screens-`)}`, "about:blank"], { stdio: ["ignore", "ignore", "pipe"] });
const stop = code => { browser.kill(); server.close(); process.exit(code); };
const pageSocket = async () => {
  for (let tries = 0; tries < 100; tries++) {
    try {
      const target = await (await fetch(`http://127.0.0.1:${debugPort}/json/new?about:blank`, { method: "PUT" })).json();
      return new WebSocket(target.webSocketDebuggerUrl);
    } catch { await new Promise(done => setTimeout(done, 100)); }
  }
  throw new Error("the browser does not answer");
};
const socket = await pageSocket();
await new Promise(done => socket.addEventListener("open", done));
let next = 0;
const waiting = new Map(), problems = [];
socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (message.id !== undefined) waiting.get(message.id)?.(message);
  else if (message.method === "Runtime.exceptionThrown") problems.push(message.params.exceptionDetails.exception?.description ?? "an exception");
  else if (message.method === "Log.entryAdded" && message.params.entry.level === "error") problems.push(message.params.entry.text + " " + (message.params.entry.url ?? ""));
});
const send = (method, params = {}) => new Promise(done => { const id = ++next; waiting.set(id, done); socket.send(JSON.stringify({ id, method, params })); });
const evaluate = async expression => (await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })).result.result.value;
const pause = milliseconds => new Promise(done => setTimeout(done, milliseconds));
const opened = async (name, width, height, mobile) => {
  await send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile });
  await send("Page.navigate", { url: `${origin}/${name}` });
  for (let tries = 0; tries < 100 && (await evaluate("document.readyState")) !== "complete"; tries++) await pause(50);
  await pause(300);
};
await send("Page.enable");
await send("Runtime.enable");
await send("Log.enable");
let wrong = 0;
const fail = text => { wrong++; console.error(text); };
const rows = [];
for (const name of readdirSync(site).filter(f => f.endsWith(".html")).sort()) {
  const screens = [];
  for (const [w, h] of desktops) {
    await opened(name, w, h, false);
    const height = await evaluate("document.documentElement.scrollHeight");
    screens.push(`${(height / h).toFixed(2)} screens at ${w}x${h}`);
  }
  await opened(name, phoneWidth, phoneHeight, true);
  const width = await evaluate("document.documentElement.scrollWidth");
  const words = await evaluate("document.body.innerText.split(/\\s+/).filter(Boolean).length");
  const running = await evaluate(`[...document.querySelectorAll(".text > p")].map(p => p.innerText).join(" ").split(/\\s+/).filter(Boolean).length`);
  if (running > runningTextWordsLimit) fail(`${name}: ${running} words of running text, more than ${runningTextWordsLimit} (2 screens at 1920x1080)`);
  const crowded = await evaluate(`[...document.querySelectorAll(".text")].filter(t => [...t.querySelectorAll(":scope > p")].map(p => p.innerText).join(" ").split(/(?<=[.!?])\\s+/).filter(Boolean).length > ${sentencesPerEntryLimit}).map(t => t.closest("section")?.id).join(" ")`);
  if (crowded) fail(`${name}: more than ${sentencesPerEntryLimit} sentences of running text in: ${crowded}`);
  rows.push(`${name}\t${screens.join("\t")}\t${width} px wide at ${phoneWidth}\t${running} words of running text`);
  if (width > phoneWidth) {
    const wide = await evaluate(`[...document.querySelectorAll("body *")].filter(e => e.getBoundingClientRect().right > ${phoneWidth} && ![...Array(20)].reduce(([n, hit]) => [n?.parentElement, hit || (n && n !== e && /auto|scroll|hidden/.test(getComputedStyle(n).overflowX))], [e, false])[1]).slice(0, 3).map(e => Math.round(e.getBoundingClientRect().right) + " " + getComputedStyle(e).display + " " + e.tagName + "." + e.className + " " + (e.textContent ?? "").slice(0, 40)).join(" | ")`);
    fail(`${name}: ${width} px wide at ${phoneWidth}, the page scrolls sideways; wide: ${wide}`);
  }
}
console.log(rows.join("\n"));
if (existsSync(`${site}/lazy.html`)) {
await opened("lazy.html", screenWidth, screenHeight, false);
if ((await evaluate("document.querySelectorAll('.example button.run:not([hidden])').length")) === 0) fail("lazy.html: the script did not show a Run button");
await evaluate(`document.querySelector(".example button.run").click()`);
await pause(1500);
const shown = await evaluate("document.querySelector('.example pre').textContent");
if (shown.includes("// fault") || !shown.includes("// ")) fail(`lazy.html: the example shows ${shown}`);
for (const name of readdirSync(site).filter(f => f.endsWith(".html")).sort()) {
  await opened(name, screenWidth, screenHeight, false);
  await evaluate(`document.querySelectorAll(".example button.run").forEach(b => b.click())`);
  await pause(2500);
  const faults = await evaluate(`[...document.querySelectorAll(".example")].filter(e => e.querySelector("pre").textContent.includes("// fault")).map(e => e.closest("section").id).join(" ")`);
  if (faults) fail(`${name}: Run gives a fault in: ${faults}`);
}
await opened("console.html", screenWidth, screenHeight, false);
await evaluate(`(async () => { const form = document.querySelector('.play[data-console] form'); form.requestSubmit(); })()`);
await pause(1500);
const log = await evaluate("document.querySelector('.play[data-console] .log').textContent");
if (!log.includes('ref to "ann"')) fail(`console.html: the log shows ${JSON.stringify(log)}`);
}
for (const problem of problems) fail(`the browser reports: ${problem}`);
console.log(`screens: ${wrong} faults`);
stop(wrong ? 1 : 0);
