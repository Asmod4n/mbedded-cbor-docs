import { readFileSync, readdirSync, existsSync } from "node:fs";

const site = process.argv[2];
const pages = readdirSync(site).filter(f => f.endsWith(".html"));
const idsOf = new Map(pages.map(p => [p, new Set([...readFileSync(`${site}/${p}`, "utf8").matchAll(/\sid="([^"]*)"/g)].map(m => m[1]))]));
let wrong = 0, count = 0;
for (const page of pages) {
  const text = readFileSync(`${site}/${page}`, "utf8");
  for (const [, attribute, target] of text.matchAll(/\s(href|src)="([^"]*)"/g)) {
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    count++;
    const [file, fragment] = target.split("#");
    const name = file === "" ? page : file;
    if (!existsSync(`${site}/${name}`)) {
      wrong++;
      console.error(`${page}: ${attribute} ${target}: no file ${name}`);
    } else if (fragment !== undefined && fragment !== "" && !(idsOf.get(name)?.has(fragment))) {
      wrong++;
      console.error(`${page}: ${attribute} ${target}: no id ${fragment} in ${name}`);
    }
  }
}
console.log(`links: ${count} checked, ${wrong} broken`);
process.exit(wrong ? 1 : 0);
