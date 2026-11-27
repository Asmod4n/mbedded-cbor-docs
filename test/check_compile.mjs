// Compiles every example that a page shows, as a reader copies it into a program: the types and their descriptions at
// global scope, once per page, and the lines from the using-directive on in one function per example. The examples
// exist to be copied, so an example that does not compile is a fault of the docs.
import { readFileSync, writeFileSync, mkdtempSync, readdirSync } from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";
import { tmpdir } from "node:os";

const [compiler, include, site, expected] = process.argv.slice(2);
const run = promisify(execFile);
const decoded = s => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&");
const headers = ["cbor/cbor.hpp", "array", "chrono", "cstdint", "map", "memory", "numeric", "optional", "set", "span", "string",
  "string_view", "variant", "vector"];
const dir = mkdtempSync(join(tmpdir(), "examples-"));
const files = [];
let count = 0;
for (const page of readdirSync(site).filter(f => f.endsWith(".html"))) {
  const html = readFileSync(join(site, page), "utf8");
  const blocks = [...html.matchAll(/<pre class="code editable"[^>]*>([\s\S]*?)<\/pre>/g)]
    .map(m => decoded(m[1].replace(/<[^>]*>/g, "")).split("\n").map(l => l.replace(/\s+\/\/ .*$/, "").trimEnd()));
  if (blocks.length === 0) continue;
  const global = [];
  const bodies = [];
  blocks.forEach((lines, i) => {
    const start = lines.findIndex(l => l.startsWith("using namespace std::string_literals;"));
    if (start < 0) throw new Error(`${page}: example ${i + 1} has no using-directive`);
    const head = lines.slice(0, start);
    for (let j = 0; j < head.length; j++) {
      let block = head[j];
      if (head[j] === "template <>")
        while (head[j] !== "};") block += "\n" + head[++j];
      if (!global.includes(block)) global.push(block);
    }
    bodies.push(`void example_${i + 1}()\n{\n` + lines.slice(start).map(l => "    " + l).join("\n") + "\n}\n");
  });
  count += blocks.length;
  const file = join(dir, page.replace(".html", ".cpp"));
  writeFileSync(file, headers.map(h => `#include <${h}>`).join("\n") + "\n\n" + global.join("\n") + "\n\n" + bodies.join("\n"));
  files.push(file);
}
const faults = [];
const queue = [...files];
const worker = async () => {
  for (let f = queue.shift(); f !== undefined; f = queue.shift()) {
    try {
      await run(compiler, ["-std=c++26", "-freflection", "-fsyntax-only", "-I", include, f], { maxBuffer: 1 << 26 });
    } catch (e) {
      faults.push(`${f}:\n${(e.stderr || e.message).split("\n").filter(l => / error: /.test(l)).slice(0, 10).join("\n")}`);
    }
  }
};
await Promise.all([worker(), worker(), worker(), worker()]);
console.log(`examples: ${count} in ${files.length} files, ${faults.length} files with errors`);
for (const f of faults) console.log(f);
if (faults.length > 0 || count !== Number(expected)) {
  if (count !== Number(expected)) console.log(`the pages show ${count} examples, the test expects ${expected}`);
  process.exit(1);
}
