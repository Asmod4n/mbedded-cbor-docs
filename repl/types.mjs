// Reads test/doc_types.hpp of mbedded-cbor and writes, for each type of its examples, the struct on one line, the
// description of the type and the types its struct names, as JSON on stdout.
import { readFileSync } from "node:fs";

const text = readFileSync(process.argv[2], "utf8");
const lines = text.split("\n");
const namespaces = [...text.matchAll(/^namespace (\w+)$/gm)].map(m => m[1]);
const unqualified = s => namespaces.reduce((t, ns) => t.replaceAll(ns + "::", ""), s);
const oneLine = block => block.map(l => l.trim()).filter(l => l !== "").join(" ");

const types = [];
const byKey = new Map();
let ns = null;
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const open = line.match(/^namespace (\w+)$/);
  if (open) { ns = open[1]; continue; }
  if (/^} \/\/ namespace /.test(line)) { ns = null; continue; }
  const head = line.match(/^struct (\w+)(?: : (\w+))? \{$/);
  if (ns !== null && head) {
    const block = [line];
    while (lines[++i] !== "};") block.push(lines[i]);
    block.push("};");
    const t = { ns, name: head[1], struct: unqualified(oneLine(block)), source: block.join("\n"), description: [] };
    types.push(t);
    byKey.set(ns + "::" + t.name, t);
    continue;
  }
  if (ns === null && /^CBOR_DEFINE/.test(line)) {
    const block = [line];
    while (!/\);$/.test(block[block.length - 1])) block.push(lines[++i]);
    const name = block[0].match(/\((\w+::\w+)/)[1];
    const t = byKey.get(name);
    if (!t) throw new Error("a description of a type that doc_types.hpp does not define: " + name);
    t.description.push(unqualified(oneLine(block)));
    continue;
  }
  if (ns === null && line === "template <>" && /^struct cbor::describe_members<\w+::\w+> \{$/.test(lines[i + 1])) {
    const block = [line];
    while (lines[i] !== "};") block.push(lines[++i]);
    const name = block[1].match(/<(\w+::\w+)>/)[1];
    const t = byKey.get(name);
    if (!t) throw new Error("a description of a type that doc_types.hpp does not define: " + name);
    t.description.push(...unqualified(block.join("\n")).split("\n"));
  }
}
for (const t of types) {
  const named = new Set();
  for (const m of t.source.matchAll(/\b(?:(\w+)::)?(\w+)\b/g)) {
    const key = (m[1] && namespaces.includes(m[1]) ? m[1] : t.ns) + "::" + m[2];
    if (byKey.has(key) && byKey.get(key) !== t) named.add(key);
  }
  t.uses = [...named];
  delete t.source;
}
process.stdout.write(JSON.stringify(types, null, 1) + "\n");
