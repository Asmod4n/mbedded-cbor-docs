import { hexOf, bytesOf, instantiated } from "./examples.mjs";

const group = document.body.dataset.group;
const escaped = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
const shown = (call, result) => '<span class="call">' + escaped(call) + "</span>\n" +
  '<span class="' + (/^(fault|unexpected)/.test(result) ? "err" : "ok") + '">' + escaped(result) + "</span>";
const module = fetch(document.querySelector('script[src^="site.js"]').src.replace(/site\.js.*$/, "examples.wasm"))
  .then(r => r.arrayBuffer()).then(instantiated);
const resultShown = result => '<span class="' + (/^(fault|unexpected)/.test(result) ? "err" : "ok") + '">' + escaped(result) + "</span>";
const run = module.then(m => m.run);

const boxOf = box => {
  const message = box.querySelector("[data-message]"), notation = box.querySelector("[data-notation]");
  const hex = box.querySelector("[data-bytes]");
  const bytes = () => bytesOf(hex.value);
  const fromMessage = async () => {
    try { hex.value = hexOf((await module).diag2cbor(message.value)); message.removeAttribute("aria-invalid"); }
    catch { message.setAttribute("aria-invalid", "true"); }
  };
  const toNotation = async () => {
    if (!notation) return;
    try {
      const r = await run, items = [];
      let rest = bytes();
      do {
        const size = Number((await r(rest, "cbor::item_size(bytes)", group))[0]);
        const item = Number.isInteger(size) && size > 0 ? rest.subarray(0, size) : rest;
        const text = (await r(item, "cbor::diagnostic_notation(bytes).value()", group))[0];
        try { items.push(JSON.parse(text)); } catch { items.push(text); }
        rest = rest.subarray(item.length);
      } while (rest.length);
      notation.value = items.join(", ");
    }
    catch (e) { notation.value = e.message; }
  };
  if (message) message.addEventListener("input", fromMessage);
  hex.addEventListener("input", toNotation);
  (message && !hex.value ? fromMessage() : Promise.resolve()).then(toNotation);
  return { message, hex, bytes, fromMessage };
};

const resultGap = "   ";
const resultTail = /\s{2,}\/\/ .*$/;
const codeLinesOf = pre => pre.innerText.replace(/ /g, " ").split("\n").map(l => l.replace(/\s+$/, "")).filter(l => l.trim());
const literalBytes = text => {
  const out = [];
  for (const piece of text.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
    const s = piece[1];
    for (let i = 0; i < s.length; i++) {
      if (s[i] !== "\\") { out.push(...new TextEncoder().encode(s[i])); continue; }
      const c = s[++i];
      if (c === "x") { out.push(parseInt(s.slice(i + 1, i + 3), 16)); i += 2; }
      else out.push({ n: 10, t: 9, r: 13, 0: 0, "\\": 92, '"': 34, "'": 39 }[c] ?? c.charCodeAt(0));
    }
  }
  return Uint8Array.from(out);
};
const dataLength = lines => {
  const start = lines.findIndex(l => /^std::string bytes =/.test(l));
  if (start < 0) throw new Error("the example starts with std::string bytes = followed by the bytes as a string literal");
  let end = start;
  while (end < lines.length && !/;\s*(\/\/.*)?$/.test(lines[end])) end++;
  return { start, end: end + 1 };
};
const played = async pre => {
  const lines = codeLinesOf(pre);
  const old = new Map([...pre.querySelectorAll(".l")].map(l => {
    const copy = l.cloneNode(true);
    copy.querySelector(".r")?.remove();
    return [copy.textContent.trimEnd(), copy.innerHTML.trimEnd()];
  }));
  let head, calls, results;
  try {
    const { start, end } = dataLength(lines);
    const adopt = /^auto const doc = cbor::lazy::adopt\(/.test(lines[end] ?? "") ? 1 : 0;
    head = lines.slice(0, end + adopt);
    calls = lines.slice(end + adopt).map(l => l.replace(resultTail, ""));
    results = await (await run)(literalBytes([lines[start].replace(/\s*\/\/.*$/, ""), ...lines.slice(start + 1, end)].join("\n")), calls.map(c => c.replace(/;\s*$/, "")).join("\n"), group);
  } catch (e) {
    head = lines.slice(0, 1);
    calls = lines.slice(1).map(l => l.replace(resultTail, ""));
    results = calls.map(() => "fault: " + e.message);
  }
  const widest = Math.max(0, ...calls.map(c => c.length));
  const line = c => '<span class="l">' + (old.get(c) ?? escaped(c));
  pre.innerHTML = head.map(h => line(h) + "</span>").join("\n") + (calls.length ? "\n" : "") +
    calls.map((c, i) => line(c) + " ".repeat(widest - c.length) + resultGap +
      '<span class="r comment' + (/^(fault|unexpected)/.test(results[i] ?? "") ? " err" : "") + '">// ' + escaped(results[i] ?? "") + "</span></span>").join("\n");
};

document.querySelectorAll(".example[data-play]").forEach(box => {
  const pre = box.querySelector("pre"), button = box.querySelector("button.run");
  button.hidden = false;
  button.addEventListener("click", () => played(pre));
  pre.addEventListener("keydown", e => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); played(pre); } });
});

const consoleBox = document.querySelector(".play[data-console]");
if (consoleBox) {
  const b = boxOf(consoleBox), log = consoleBox.querySelector(".log");
  const form = consoleBox.querySelector("form"), entry = form.querySelector("input");
  const history = [];
  form.addEventListener("submit", async e => {
    e.preventDefault();
    const line = entry.value;
    if (!line.trim()) return;
    let bytes;
    try { bytes = b.bytes(); } catch (err) { log.insertAdjacentHTML("beforeend", shown(line, "fault: " + err.message) + "\n"); return; }
    const results = await (await run)(bytes, [...history, line].join("\n"), group);
    const last = results[results.length - 1] ?? "";
    if (!last.startsWith("fault")) history.push(line);
    log.insertAdjacentHTML("beforeend", shown("» " + line, last) + "\n");
    log.scrollTop = log.scrollHeight;
    entry.select();
  });
  [b.message, b.hex].forEach(el => el?.addEventListener("input", () => { history.length = 0; }));
  const list = consoleBox.querySelector("[data-completions]");
  let options = [], chosen = -1;
  const shut = () => { list.hidden = true; list.replaceChildren(); options = []; chosen = -1; entry.setAttribute("aria-expanded", "false"); };
  const take = text => { entry.value = text; shut(); entry.focus(); listed(); };
  const marked = () => options.forEach((o, i) => o.setAttribute("aria-selected", i === chosen ? "true" : "false"));
  const listed = async () => {
    let bytes;
    try { bytes = b.bytes(); } catch { shut(); return; }
    const { head, found } = await (await module).completed(bytes, [...history, entry.value].join("\n"), group);
    shut();
    if (!found.length || (found.length === 1 && found[0] === entry.value)) return;
    options = found.map((text, i) => {
      const o = document.createElement("button");
      o.type = "button";
      o.id = "co-option-" + i;
      o.setAttribute("role", "option");
      o.textContent = text.slice(head.length);
      o.addEventListener("click", () => take(text));
      list.append(o);
      return Object.assign(o, { full: text });
    });
    list.hidden = false;
    entry.setAttribute("aria-expanded", "true");
  };
  entry.addEventListener("input", () => {
    if (/(->|\.|::|\(|\[|<|")$/.test(entry.value) || !list.hidden) listed(); else shut();
  });
  entry.addEventListener("keydown", e => {
    if (e.key === "Tab" && !e.shiftKey) {
      if (options.length === 1) { e.preventDefault(); take(options[0].full); return; }
      if (options.length > 1) {
        e.preventDefault();
        const all = options.map(o => o.full);
        let common = all[0];
        for (const t of all) while (!t.startsWith(common)) common = common.slice(0, -1);
        if (common.length > entry.value.length) { entry.value = common; listed(); } else { chosen = (chosen + 1) % options.length; marked(); }
        return;
      }
      e.preventDefault();
      listed();
    } else if (e.key === "ArrowDown" && options.length) { e.preventDefault(); chosen = (chosen + 1) % options.length; marked(); }
    else if (e.key === "ArrowUp" && options.length) { e.preventDefault(); chosen = (chosen + options.length - 1) % options.length; marked(); }
    else if (e.key === "Enter" && chosen >= 0) { e.preventDefault(); take(options[chosen].full); }
    else if (e.key === "Escape") shut();
  });
  consoleBox.querySelector("[data-complete]").addEventListener("click", () => { entry.focus(); listed(); });
  document.querySelectorAll("[data-load]").forEach(button => button.addEventListener("click", () => {
    b.message.value = button.dataset.loadMessage;
    b.message.dispatchEvent(new Event("input"));
    log.replaceChildren();
    entry.value = button.dataset.loadCall;
    form.requestSubmit();
    consoleBox.scrollIntoView();
  }));
}

document.querySelectorAll("nav.side li a").forEach(a => { if (a.getAttribute("href") === location.pathname.split("/").pop()) a.classList.add("here"); });
