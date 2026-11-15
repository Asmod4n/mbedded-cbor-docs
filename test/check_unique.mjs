import { readFileSync, readdirSync } from "node:fs";

const site = process.argv[2];
const minimumWords = 4;
const decoded = s => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");
const plain = s => decoded(s.replace(/<[^>]*>/g, "")).replace(/`/g, "");
const sentences = new Map(), entries = new Map();
let wrong = 0, count = 0;
const note = (map, key, page, what) => {
  count++;
  if (map.has(key)) {
    wrong++;
    console.error(`${what} stands twice: ${key}\n  in ${map.get(key)} and in ${page}`);
  } else map.set(key, page);
};
for (const page of readdirSync(site).filter(f => f.endsWith(".html")).sort()) {
  const text = readFileSync(`${site}/${page}`, "utf8");
  for (const [, heading] of text.matchAll(/<h2>([^<]*)<\/h2>/g)) note(entries, plain(heading), page, "an entry");
  for (const [, , block] of text.matchAll(/<(p|td)(?: [^>]*)?>([\s\S]*?)<\/\1>/g))
    for (const paragraph of plain(block).split(/\n\s*\n/))
      for (const sentence of paragraph.replace(/\s+/g, " ").trim().split(/(?<=[.!?])\s+/))
        if (sentence.split(" ").length >= minimumWords) note(sentences, sentence, page, "a sentence");
}
console.log(`unique: ${count} texts and entries checked, ${wrong} twice`);
process.exit(wrong ? 1 : 0);
