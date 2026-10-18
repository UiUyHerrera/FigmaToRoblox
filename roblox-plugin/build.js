// Builds dist/FigmaToRoblox.lua (single-file Studio plugin) from src/.
// Usage: node build.js            -> writes dist/FigmaToRoblox.lua
//        node build.js --install  -> also copies it into the Roblox Plugins folder
const fs = require("fs");
const path = require("path");

const src = (f) => fs.readFileSync(path.join(__dirname, "src", f), "utf8");
const defaults = src("defaults.lua");
const runtime = src("runtime.lua").replace("--@DEFAULTS", defaults);

let level = "==";
while (runtime.includes("]" + level + "]")) level += "=";
const plugin = src("plugin.lua")
  .replace("--@DEFAULTS", defaults)
  .replace("--@RUNTIME", "[" + level + "[" + runtime + "]" + level + "]");

const out = path.join(__dirname, "dist", "FigmaToRoblox.lua");
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, plugin);
console.log("Built " + out);

// Mirror defaults into the Figma plugin (colors become #rrggbb).
function luaValue(v) {
  v = v.trim();
  const hex = (r, g, b) => "#" + [r, g, b].map((x) => Math.round(x).toString(16).padStart(2, "0")).join("");
  let m;
  if ((m = v.match(/^Color3\.fromRGB\(([^)]*)\)$/))) return hex(...m[1].split(",").map(Number));
  if ((m = v.match(/^Color3\.new\(([^)]*)\)$/))) return hex(...m[1].split(",").map((x) => Number(x) * 255));
  if (v === "true" || v === "false") return v === "true";
  if (/^".*"$/.test(v)) return v.slice(1, -1);
  return Number(v);
}
const json = {};
for (const line of defaults.split("\n")) {
  const m = line.match(/^\s*(\w+)\s*=\s*\{(.*)\},?\s*$/);
  if (!m) continue;
  json[m[1]] = {};
  for (const pair of m[2].match(/\w+\s*=\s*(Color3\.\w+\([^)]*\)|"[^"]*"|[^,]+)/g) || []) {
    const [k, ...rest] = pair.split("=");
    json[m[1]][k.trim()] = luaValue(rest.join("="));
  }
}
const codePath = path.join(__dirname, "..", "figma-plugin", "code.js");
const code = fs.readFileSync(codePath, "utf8").replace(/\/\*@DEFAULTS\*\/[\s\S]*?\/\*@END\*\//, "/*@DEFAULTS*/" + JSON.stringify(json) + "/*@END*/");
fs.writeFileSync(codePath, code);
console.log("Synced defaults into figma-plugin/code.js");

if (process.argv.includes("--install")) {
  const dir = process.platform === "win32"
    ? path.join(process.env.LOCALAPPDATA, "Roblox", "Plugins")
    : path.join(process.env.HOME, "Documents", "Roblox", "Plugins");
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(out, path.join(dir, "FigmaToRoblox.lua"));
  // Earlier versions installed the plugin as FigBridge.lua; remove it so Studio doesn't load two copies.
  const legacy = path.join(dir, "FigBridge.lua");
  if (fs.existsSync(legacy)) fs.unlinkSync(legacy);
  console.log("Installed to " + dir + " — restart Studio.");
}
