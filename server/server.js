// FigBridge relay: Figma uploads a design, gets a 6-character code; the Studio plugin downloads it by code.
// No dependencies. Run: node server.js   (port via PORT env, default 7777)
const http = require("http");

const fs = require("fs");
const path = require("path");

const PORT = Number(process.env.PORT) || 7777;
const TTL_MS = 6 * 60 * 60 * 1000; // codes live 6 hours
const store = new Map(); // code -> { doc, images, created, ready }

// ---------- Roblox Open Cloud image upload ----------
// server/config.json: { "apiKey": "...", "userId": 123 }  (or "groupId" instead of userId)
const CONFIG_PATH = path.join(__dirname, "config.json");
const CACHE_PATH = path.join(__dirname, "asset-cache.json"); // image hash -> decal asset id
function loadJSON(p, fallback) { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return fallback; } }
const config = loadJSON(CONFIG_PATH, null);
const assetCache = loadJSON(CACHE_PATH, {});
if (config && config.apiKey && (config.userId || config.groupId)) console.log("Open Cloud upload: enabled");
else console.log("Open Cloud upload: disabled (create server/config.json, see README)");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function uploadDecal(id, pngBase64) {
  const creator = config.groupId ? { groupId: String(config.groupId) } : { userId: String(config.userId) };
  const form = new FormData();
  form.append("request", JSON.stringify({
    assetType: "Decal",
    displayName: "FigBridge " + id.slice(0, 8),
    description: "Uploaded by FigBridge",
    creationContext: { creator },
  }));
  form.append("fileContent", new Blob([Buffer.from(pngBase64, "base64")], { type: "image/png" }), "image.png");
  const res = await fetch("https://apis.roblox.com/assets/v1/assets", { method: "POST", headers: { "x-api-key": config.apiKey }, body: form });
  const op = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error("upload " + res.status + " " + JSON.stringify(op).slice(0, 200));
  let result = op;
  for (let i = 0; i < 30 && !(result.done && result.response); i++) {
    await sleep(1000);
    const opId = String(op.path || op.operationId || "").replace(/^operations\//, "");
    const r = await fetch("https://apis.roblox.com/assets/v1/operations/" + opId, { headers: { "x-api-key": config.apiKey } });
    result = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error("operation " + r.status + " " + JSON.stringify(result).slice(0, 200));
  }
  const assetId = result.response && result.response.assetId;
  if (!assetId) throw new Error("upload timed out");
  return String(assetId);
}

async function uploadAll(entry) {
  if (!config || !config.apiKey) return;
  for (const [id, img] of Object.entries(entry.images)) {
    if (!img.png) continue;
    if (assetCache[id]) { img.decal = assetCache[id]; continue; }
    try {
      img.decal = await uploadDecal(id, img.png);
      assetCache[id] = img.decal;
      fs.writeFileSync(CACHE_PATH, JSON.stringify(assetCache, null, 1));
      console.log("[asset] " + id.slice(0, 8) + " -> decal " + img.decal);
    } catch (e) {
      img.uploadError = String(e.message || e);
      console.log("[asset] " + id.slice(0, 8) + " FAILED: " + img.uploadError);
    }
  }
}

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
function newCode() {
  let code;
  do {
    code = "";
    for (let i = 0; i < 6; i++) code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  } while (store.has(code));
  return code;
}

function send(res, status, body) {
  const data = typeof body === "string" ? body : JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(data);
}

function cleanup() {
  const now = Date.now();
  for (const [code, entry] of store) if (now - entry.created > TTL_MS) store.delete(code);
}
setInterval(cleanup, 10 * 60 * 1000).unref();

const server = http.createServer((req, res) => {
  if (req.method === "OPTIONS") return send(res, 204, "");
  const url = new URL(req.url, "http://localhost");
  const parts = url.pathname.split("/").filter(Boolean); // api, ...

  if (req.method === "GET" && url.pathname === "/api/ping") return send(res, 200, { ok: true, app: "figbridge" });

  if (req.method === "POST" && url.pathname === "/api/upload") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      let payload;
      try {
        payload = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      } catch {
        return send(res, 400, { error: "Invalid JSON" });
      }
      if (!payload || !payload.doc) return send(res, 400, { error: "Missing doc" });
      // live sync reuses one code ("channel") and bumps its version on every update
      const channel = typeof payload.channel === "string" && /^[A-Z0-9]{6}$/.test(payload.channel) ? payload.channel : null;
      const code = channel || newCode();
      const prev = store.get(code);
      const entry = { doc: payload.doc, images: payload.images || {}, created: Date.now(), version: ((prev && prev.version) || 0) + 1 };
      entry.ready = uploadAll(entry); // Studio waits for this before downloading
      entry.ready.then(() => { entry.readyVersion = entry.version; });
      store.set(code, entry);
      // Keep the latest design (without pixels) on disk to debug conversions.
      try { fs.writeFileSync(path.join(__dirname, "last-upload.json"), JSON.stringify(payload.doc, null, 1)); } catch {}
      const kb = Math.round(Buffer.concat(chunks).length / 1024);
      console.log(`[upload] ${code} v${entry.version}  ${payload.doc.name || "?"}  ${Object.keys(payload.images || {}).length} images  ${kb} KB`);
      send(res, 200, { code, version: entry.version });
    });
    return;
  }

  // GET /api/v/CODE -> { version } of the latest ready upload (cheap poll for live sync)
  if (req.method === "GET" && parts[0] === "api" && parts[1] === "v" && parts[2]) {
    const entry = store.get(parts[2].toUpperCase());
    if (!entry) return send(res, 404, { error: "Code not found or expired" });
    return send(res, 200, { version: entry.readyVersion || 0 });
  }

  // GET /api/c/CODE  -> doc + image list (without pixels)
  // GET /api/c/CODE/img/ID -> { w, h, data }
  if (req.method === "GET" && parts[0] === "api" && parts[1] === "c" && parts[2]) {
    const entry = store.get(parts[2].toUpperCase());
    if (!entry) return send(res, 404, { error: "Code not found or expired" });
    if (parts[3] === "img" && parts[4]) {
      const img = entry.images[parts[4]];
      if (!img) return send(res, 404, { error: "Image not found" });
      return send(res, 200, img);
    }
    entry.ready.then(() => {
      const images = Object.entries(entry.images).map(([id, im]) => ({ id, w: im.w, h: im.h, decal: im.decal, uploadError: im.uploadError }));
      console.log(`[download] ${parts[2].toUpperCase()}`);
      send(res, 200, { doc: entry.doc, images, version: entry.version });
    });
    return;
  }

  send(res, 404, { error: "Not found" });
});

server.listen(PORT, () => console.log(`FigBridge server running on http://localhost:${PORT}`));
