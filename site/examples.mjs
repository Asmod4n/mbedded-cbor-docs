const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export const hexOf = bytes => [...bytes].map(b => b.toString(16).padStart(2, "0")).join(" ");

export const bytesOf = hex => {
  const t = hex.replace(/\s+/g, "");
  if (t.length % 2 || /[^0-9a-f]/i.test(t)) throw new Error("the bytes are not hex");
  return Uint8Array.from(t.match(/../g) ?? [], h => parseInt(h, 16));
};

export const instantiated = async source => {
  const module = await WebAssembly.compile(source);
  let memory;
  const imports = {};
  for (const i of WebAssembly.Module.imports(module))
    (imports[i.module] ??= {})[i.name] = () => { throw new Error("the module called " + i.name); };
  Object.assign(imports.wasi_snapshot_preview1 ??= {}, {
    environ_sizes_get: (count, size) => {
      const d = new DataView(memory.buffer);
      d.setUint32(count, 0, true);
      d.setUint32(size, 0, true);
      return 0;
    },
    environ_get: () => 0,
    random_get: (p, n) => { crypto.getRandomValues(new Uint8Array(memory.buffer, p, n)); return 0; },
  });
  const made = async () => {
    const instance = await WebAssembly.instantiate(module, imports);
    memory = instance.exports.memory;
    instance.exports._initialize?.();
    return instance.exports;
  };
  let x = await made();
  const put = data => {
    const p = x.buffer(data.length || 1);
    new Uint8Array(memory.buffer, p, data.length).set(data);
    return p;
  };
  const call = (name, bytes, lines, group) => {
    const text = textEncoder.encode(lines), label = textEncoder.encode(group);
    const b = put(bytes), l = put(text), g = put(label);
    const p = x[name](b, bytes.length, l, text.length, g, label.length);
    x.release(b);
    x.release(l);
    x.release(g);
    const n = new DataView(memory.buffer).getUint32(p, true);
    const out = textDecoder.decode(new Uint8Array(memory.buffer, p + 4, n));
    x.release(p);
    return out.split("\n").slice(0, -1);
  };
  const diag2cbor = text => {
    const t = textEncoder.encode(text), p = put(t);
    const out = x.diag2cbor(p, t.length);
    x.release(p);
    const n = new DataView(memory.buffer).getUint32(out, true);
    const bytes = new Uint8Array(memory.buffer, out + 4, n).slice();
    x.release(out);
    if (!n) throw new Error("the message is not EDN");
    return bytes;
  };
  const run = async (bytes, lines, group) => {
    try {
      return call("run", bytes, lines, group);
    } catch {
      x = await made();
    }
    const kept = [], results = [];
    for (const line of lines.split("\n").filter(l => l.trim())) {
      try {
        results.push(call("run", bytes, [...kept, line].join("\n"), group).at(-1));
        kept.push(line);
      } catch {
        x = await made();
        results.push("fault: the call ended the program (a wrong use; exceptions are off in this build)");
      }
    }
    return results;
  };
  const completed = async (bytes, lines, group) => {
    try {
      const [head, ...found] = call("complete", bytes, lines, group);
      return { head, found, trapped: false };
    } catch {
      x = await made();
      return { head: lines.split("\n").at(-1), found: [], trapped: true };
    }
  };
  return { run, completed, diag2cbor };
};
