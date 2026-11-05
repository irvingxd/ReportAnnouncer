// Syntax-checks every .lua file and verifies the files listed in the .toc exist.
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const root = path.resolve(__dirname, "..", "..");
let failed = false;

for (const file of fs.readdirSync(root).filter((f) => f.endsWith(".lua"))) {
  try {
    luaparse.parse(fs.readFileSync(path.join(root, file), "utf8"), { luaVersion: "5.1" });
    console.log("ok   " + file);
  } catch (e) {
    console.error("FAIL " + file + ": " + e.message);
    failed = true;
  }
}

for (const toc of fs.readdirSync(root).filter((f) => f.endsWith(".toc"))) {
  const lines = fs.readFileSync(path.join(root, toc), "utf8").split(/\r?\n/);
  for (const line of lines.map((l) => l.trim()).filter((l) => l && !l.startsWith("#"))) {
    if (!fs.existsSync(path.join(root, line))) {
      console.error("FAIL " + toc + " lists missing file " + line);
      failed = true;
    }
  }
}

process.exit(failed ? 1 : 0);
