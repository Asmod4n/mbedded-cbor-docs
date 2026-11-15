import { readFileSync, writeFileSync } from "node:fs";
import { encoded, hexOf, bytesOf, instantiated } from "../site/examples.mjs";

const [wasm, examples, output] = process.argv.slice(2);
const { run } = await instantiated(readFileSync(wasm));
const unquoted = text => {
  try { return JSON.parse(text); } catch { return text.replace(/^"|"$/g, ""); }
};
const out = [];
for (const e of JSON.parse(readFileSync(examples, "utf8"))) {
  const bytes = e.message !== null ? Uint8Array.from(encoded(JSON.parse(e.message))) : bytesOf(e.bytes);
  const [notation] = await run(bytes, "cbor::diagnostic_notation(bytes).value()", e.group);
  out.push({ hex: hexOf(bytes), notation: e.message !== null ? e.message : /^(fault|unexpected)/.test(notation ?? "") ? "" : unquoted(notation) });
}
writeFileSync(output, JSON.stringify(out));
