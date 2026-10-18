// FigBridge — Figma side. Serializes one frame into a JSON tree the Studio plugin rebuilds as native UI.

// Tag catalogue: key, whether it takes an argument, group and a short description (shown in the Tags tab).
const TAGS = [
  // Structure
  ["button", 0, "Structure", "Clickable button with hover/press feedback. Put it on the whole button frame."],
  ["scroll", 0, "Structure", "Scrolling window. Put it on a frame with Clip content; children outside the frame become scrollable."],
  ["panel", 0, "Structure", "A panel buttons can open/close. Name it e.g. Shop_panel. Hide it in Figma to start closed."],
  ["open", 1, "Structure", "Button that opens the panel named in the argument (_open:Shop)."],
  ["close", 0, "Structure", "Button that hides its parent panel (or the whole GUI)."],
  ["toggle", 1, "Structure", "Button that opens/closes the named panel (_toggle:Shop)."],
  ["image", 0, "Structure", "Export this layer (with its children) as a single image."],
  ["frame", 0, "Structure", "Force an editable Frame; unsupported paints are dropped."],
  ["txt", 0, "Structure", "Force live text even if it has unsupported fills."],
  ["ignore", 0, "Structure", "Skip this layer."],
  ["keep", 0, "Structure", "Keep this layer separate when its parent is exported as an image."],
  ["nodim", 0, "Structure", "Image inside a button that should not darken on hover."],
  ["fit", 0, "Structure", "Text auto-shrinks to fit its box (TextScaled)."],
  ["list", 0, "Structure", "Arrange direct children in a UIListLayout (equal gaps)."],
  ["grid", 0, "Structure", "Arrange equal-sized children in a UIGridLayout."],
  ["textbox", 0, "Structure", "Player text input. The drawn text becomes the placeholder."],
  ["canvas", 0, "Structure", "CanvasGroup: clips to rounded corners and fades as one."],
  ["aspect", 0, "Structure", "Keep width/height ratio (UIAspectRatioConstraint)."],
  // Tabs
  ["tab", 1, "Tabs", "Tab button: shows the named panel and hides the other tab panels in its group (_tab:Weapons)."],
  ["tabgroup", 0, "Tabs", "Shared parent of a set of tab buttons and their panels."],
  ["active", 0, "Tabs", "Variant inside a _tab button shown only while that tab is selected."],
  // Buttons & states
  ["grow", 0, "Buttons", "Grows while hovered."],
  ["press", 0, "Buttons", "Shrinks while pressed and springs back."],
  ["sound", 0, "Buttons", "Plays sounds on hover and click (asset ids in settings)."],
  ["popout", 0, "Exits", "Shrinks and fades out when closed."],
  ["fadeout", 0, "Exits", "Fades out when closed."],
  ["dropout", 0, "Exits", "Falls and fades out when closed."],
  ["smooth", 0, "Buttons", "Button grows on hover and shrinks on press."],
  ["hover", 0, "Buttons", "Variant layer inside a button shown while hovered."],
  ["clicked", 0, "Buttons", "Variant layer inside a button shown while pressed."],
  ["default", 0, "Buttons", "Resting variant; hidden while another variant shows."],
  ["disabled", 0, "Buttons", "Variant shown when the button's Interactable is false."],
  ["up", 0, "Buttons", "Button rises while hovered."],
  ["turn", 0, "Buttons", "Button rotates while hovered."],
  ["squish", 0, "Buttons", "Button flattens on press and springs back."],
  ["ripple", 0, "Buttons", "Circular wave from the click point."],
  ["burst", 0, "Buttons", "Particles fly out on click."],
  ["magnet", 0, "Buttons", "Button is pulled toward a nearby cursor."],
  ["select", 0, "Buttons", "Click highlights this card and clears siblings (attribute FB_Selected)."],
  ["lean", 0, "Buttons", "Inner layer tilts when its parent button is hovered."],
  ["color", 0, "Buttons", "Layer changes colour while its button is hovered."],
  ["glint", 0, "Buttons", "Shine layer sweeps across its parent on hover."],
  ["pointer", 0, "Buttons", "Your drawn arrow slides to the hovered button of its menu."],
  ["nopointer", 0, "Buttons", "This button is skipped by the menu's _pointer."],
  ["card", 1, "Buttons", "Info card shown while the named button is hovered (_card:Buy)."],
  // Entrances
  ["reveal", 0, "Entrances", "Rocks in with a 3D-looking turn and scale when shown."],
  ["pop", 0, "Entrances", "Springy scale-in when shown."],
  ["fadein", 0, "Entrances", "Fade in when shown."],
  ["drop", 0, "Entrances", "Drops from above with a bounce when shown."],
  ["swing", 0, "Entrances", "Swings in with a settling rotation when shown."],
  ["cascade", 0, "Entrances", "Children appear one after another."],
  // Motion at rest
  ["pixels", 0, "Motion", "Small squares light up and fade over the layer."],
  ["fall", 0, "Motion", "Copies of an image fall inside the layer (tag the image or its frame)."],
  ["drift", 0, "Motion", "Scrolls a tiled image fill (set the fill to Tile in Figma)."],
  ["spin", 0, "Motion", "Rotates forever."],
  ["rays", 0, "Motion", "Slow rotation plus pulse, for background rays."],
  ["pulse", 0, "Motion", "Grows and shrinks repeatedly."],
  ["float", 0, "Motion", "Floats back and forth."],
  ["jelly", 0, "Motion", "Idle wobble."],
  ["blink", 0, "Motion", "Fades out and in repeatedly."],
  ["shake", 0, "Motion", "Short shakes at intervals."],
  ["wiggle", 0, "Motion", "Short side-to-side swings at intervals."],
  ["glow", 0, "Motion", "Pulsing outline glow."],
  ["type", 0, "Motion", "Typewriter text reveal."],
  ["sparkle", 0, "Motion", "Twinkling stars over the layer."],
  ["shiny", 0, "Motion", "Shine layer sweeps across its parent repeatedly."],
  ["beam", 0, "Motion", "Streak layer loops upward inside its parent."],
  ["gleam", 0, "Motion", "Light sweep across live text."],
  ["stroke", 0, "Motion", "Animates the outline gradient."],
  ["flow", 0, "Motion", "Animates the fill gradient (rainbow if none)."],
  // World / looks
  ["tilt3d", 0, "World", "Card leans toward the cursor while hovered (3D look). Also _3d."],
  ["tilt", 0, "World", "Holds the card at a fixed turned angle (3D look)."],
  ["prompt", 0, "World", "Root only: shows the design when a player walks near (ProximityPrompt)."],
  ["hold", 0, "World", "Inside a _prompt design: its outline fills while the key is held."],
  ["billboard", 0, "World", "Root only: becomes a BillboardGui on a new Part."],
  ["surface", 0, "World", "Root only: becomes a SurfaceGui on a new Part."],
  ["focus", 0, "World", "Blurs the world while this panel is visible."],
  ["shadow", 0, "Looks", "Adds an editable drop shadow."],
  // Data
  ["bar", 1, "Data", "Fill layer that grows with a value (_bar:leaderstats.XP). Set Max in settings."],
  ["buy", 1, "Data", "Button that opens the Roblox purchase prompt (_buy:12345). Type: Product or GamePass."],
  ["bind", 1, "Data", "Text shows a live value under the player (_bind:leaderstats.Gems)."],
];

// Event-based pickers for the Interact tab: one choice per section.
const SECTIONS = [
  { id: "action", title: "On click", hint: "What the click does: pick the window on the canvas or from the list", options: [["open", "Open panel"], ["toggle", "Toggle panel"], ["close", "Close"]] },
  { id: "hover", title: "Hover", hint: "While the pointer is over it", options: [["grow", "Grow"], ["up", "Lift"], ["turn", "Tilt"], ["magnet", "Magnet"], ["tilt3d", "3D tilt"], ["button", "Dim"]] },
  { id: "click", title: "Click", hint: "While pressing it", options: [["press", "Shrink"], ["squish", "Squish"], ["ripple", "Ripple"], ["burst", "Burst"]] },
  { id: "appear", title: "Appear", hint: "When it shows up or opens", options: [["pop", "Pop"], ["fadein", "Fade"], ["drop", "Drop"], ["swing", "Swing"], ["reveal", "Reveal"]] },
  { id: "exit", title: "Exit", hint: "When it closes", options: [["popout", "Shrink"], ["fadeout", "Fade"], ["dropout", "Fall"]] },
  { id: "idle", title: "Idle", hint: "Loops while visible", options: [["pulse", "Pulse"], ["float", "Float"], ["spin", "Spin"], ["wiggle", "Wiggle"], ["shake", "Shake"], ["jelly", "Jelly"], ["blink", "Blink"], ["glow", "Glow"], ["rays", "Rays"], ["sparkle", "Sparkle"], ["pixels", "Pixels"], ["fall", "Falling"], ["drift", "Drift"], ["tilt", "Fixed 3D"]] },
  { id: "text", title: "Text effect", hint: "For text layers", textOnly: true, options: [["gleam", "Shine"], ["type", "Typewriter"], ["flow", "Rainbow"]] },
];
// Tag settings defaults; generated from roblox-plugin/src/defaults.lua by roblox-plugin/build.js.
const DEFAULTS = /*@DEFAULTS*/{"button":{"Darken":0.12,"Time":0.12},"grow":{"Scale":1.1,"Time":0.2,"Style":"Smooth"},"press":{"Scale":0.92,"Time":0.1,"Style":"Bouncy"},"sound":{"Hover":"","Click":"","Volume":0.5},"popout":{"To":0.6,"Time":0.22},"fadeout":{"Time":0.25},"dropout":{"Distance":60,"Time":0.3},"smooth":{"HoverScale":1.1,"PressScale":0.94,"Time":0.15,"HoverSound":"","ClickSound":""},"up":{"Lift":6,"Time":0.15,"Style":"Smooth"},"turn":{"Angle":6,"Time":0.15},"squish":{"Squash":0.85,"Time":0.35},"ripple":{"Color":"#ffffff","Opacity":0.35,"Time":0.5},"burst":{"Count":10,"Distance":70,"Size":8,"Life":0.55,"Spin":180,"Color":"#ffe678","Shape":"Circle","Icon":""},"magnet":{"Strength":0.25,"Radius":120},"select":{"Color":"#ffd700","Thickness":3},"lean":{"Angle":12,"Time":0.15},"color":{"HoverColor":"#ffdc78","Time":0.15},"glint":{"Time":0.5},"card":{"Delay":0.15,"Time":0.15},"pop":{"From":0.6,"Time":0.45,"Delay":0,"Style":"Bouncy"},"fadein":{"Time":0.4,"Delay":0},"drop":{"Height":80,"Time":0.7,"Delay":0},"swing":{"Angle":14,"Time":1,"Delay":0},"cascade":{"Step":0.07,"Time":0.3,"Distance":12},"spin":{"Speed":90},"rays":{"Speed":20,"Pulse":0.05,"Rate":0.5},"pulse":{"Amount":0.06,"Rate":1.2},"float":{"Distance":6,"Rate":0.5,"Angle":0},"jelly":{"Amount":0.04,"Rate":1},"blink":{"On":1,"Off":0.5,"Fade":0.2,"Delay":0},"shake":{"Distance":4,"Duration":0.4,"Every":3},"wiggle":{"Angle":8,"Duration":0.5,"Every":3},"glow":{"Color":"#ffffff","Size":14,"Rate":1},"reveal":{"Angle":10,"From":0.85,"Time":0.8,"Delay":0},"tilt3d":{"Strength":14,"Depth":0.25},"tilt":{"X":0,"Y":20},"pointer":{"Time":0.25,"Hide":0.4},"pixels":{"Size":8,"Rate":8,"Color":"#ffffff","Opacity":0.35},"fall":{"Count":8,"Speed":60,"MinSize":0.5,"MaxSize":1},"drift":{"SpeedX":20,"SpeedY":0},"prompt":{"Distance":10,"Hold":0},"hold":{"Color":"#ffffff"},"type":{"Speed":30,"Delay":0,"Loop":false,"Pause":1.5},"sparkle":{"Count":6,"MinSize":8,"MaxSize":16,"Life":1.2,"Spin":90,"Rise":0,"Color":"#ffffff","Shape":"Star","Icon":"","Trigger":"Always"},"shiny":{"Time":0.8,"Pause":1.5},"beam":{"Speed":60},"gleam":{"Time":0.8,"Pause":1.5,"Color":"#ffffff"},"stroke":{"Speed":90,"Mode":"Rotate"},"flow":{"Speed":60,"Mode":"Rotate","Bands":2,"Rainbow":false},"bar":{"Max":100,"MaxPath":"","Direction":"Right","Time":0.3},"buy":{"Type":"Product"},"focus":{"Blur":12},"billboard":{"Width":6},"surface":{"Width":6}}/*@END*/;
const PRESETS = [
  ["Soft hover button", ["button", "smooth"]],
  ["Squish on click", ["button", "squish"]],
  ["Ripple on click", ["button", "ripple"]],
  ["Burst on click", ["button", "burst"]],
  ["Hover lift", ["button", "up"]],
];
function readSettings(n) {
  try { return JSON.parse(n.getPluginData("fb_settings") || "{}"); } catch (e) { return {}; }
}

const KNOWN = {};
for (const t of TAGS) KNOWN[t[0]] = true;
KNOWN["3d"] = true; KNOWN.exit = true; KNOWN.input = true; KNOWN.lock = true; KNOWN.img = true;
const ALIAS = { "3d": "tilt3d", exit: "close", input: "textbox", lock: "image", img: "image" };

function parseName(raw) {
  const tags = {};
  let name = raw.trim();
  if (name.startsWith("#")) { tags.image = true; name = name.slice(1); }
  if (name.toLowerCase().startsWith("img:")) { tags.image = true; name = name.slice(4); }
  const pieces = name.split("_");
  let base = pieces[0];
  for (let i = 1; i < pieces.length; i++) {
    const p = pieces[i];
    const idx = p.indexOf(":");
    let key = (idx >= 0 ? p.slice(0, idx) : p).toLowerCase();
    if (KNOWN[key]) {
      key = ALIAS[key] || key;
      tags[key] = idx >= 0 ? p.slice(idx + 1) : true;
    } else {
      base += "_" + p;
    }
  }
  base = base.trim() || raw.trim() || "Layer";
  return { name: base, tags };
}

// ---------- math ----------
function inv(m) {
  const a = m[0][0], c = m[0][1], tx = m[0][2], b = m[1][0], d = m[1][1], ty = m[1][2];
  const det = a * d - b * c || 1e-9;
  return [[d / det, -c / det, (c * ty - d * tx) / det], [-b / det, a / det, (b * tx - a * ty) / det]];
}
function apply(m, x, y) { return [m[0][0] * x + m[0][1] * y + m[0][2], m[1][0] * x + m[1][1] * y + m[1][2]]; }
function angleOf(m) { return Math.atan2(m[1][0], m[0][0]) * 180 / Math.PI; }
function round(v, p) { const k = Math.pow(10, p == null ? 3 : p); return Math.round(v * k) / k; }

// ---------- fonts ----------
const FAMILIES = ["AccanthisADFStd", "AmaticSC", "Arial", "Arimo", "Balthazar", "Bangers", "BuilderSans", "ComicNeueAngular", "Creepster", "DenkOne", "Fondamento", "FredokaOne", "GothamSSm", "GrenzeGotisch", "Guru", "HighwayGothic", "Inconsolata", "IndieFlower", "JosefinSans", "Jura", "Kalam", "LuckiestGuy", "Merriweather", "Michroma", "Montserrat", "Nunito", "Oswald", "PatrickHand", "PermanentMarker", "PressStart2P", "Roboto", "RobotoCondensed", "RobotoMono", "Sarpanch", "SourceSansPro", "SpecialElite", "TitilliumWeb", "Ubuntu", "Zekton"];
const FAMILY_ALIAS = {
  gotham: "GothamSSm", gothamssm: "GothamSSm", fredoka: "FredokaOne", fredokaone: "FredokaOne",
  sourcesans3: "SourceSansPro", sourcesans: "SourceSansPro", poppins: "Montserrat", inter: "BuilderSans",
  sfpro: "BuilderSans", sfprodisplay: "BuilderSans", sfprotext: "BuilderSans", helvetica: "Arimo",
  helveticaneue: "Arimo", opensans: "Nunito", lato: "Nunito", notosans: "Nunito", rubik: "Nunito",
  baloo: "FredokaOne", baloo2: "FredokaOne", lilitaone: "LuckiestGuy", titanone: "LuckiestGuy",
  pressstart: "PressStart2P", bebasneue: "Oswald", anton: "Oswald", worksans: "BuilderSans",
  dmsans: "BuilderSans", manrope: "BuilderSans", raleway: "Montserrat", comicneue: "ComicNeueAngular",
};
const unmappedFonts = {};
function mapFamily(family) {
  const key = family.toLowerCase().replace(/[^a-z0-9]/g, "");
  for (const f of FAMILIES) if (f.toLowerCase() === key) return f;
  if (FAMILY_ALIAS[key]) return FAMILY_ALIAS[key];
  unmappedFonts[family] = true;
  return "BuilderSans";
}
function mapWeight(style) {
  const s = style.toLowerCase().replace(/\s/g, "");
  if (s.includes("thin") || s.includes("hairline")) return 100;
  if (s.includes("extralight") || s.includes("ultralight")) return 200;
  if (s.includes("semibold") || s.includes("demibold")) return 600;
  if (s.includes("extrabold") || s.includes("ultrabold")) return 800;
  if (s.includes("black") || s.includes("heavy")) return 900;
  if (s.includes("light")) return 300;
  if (s.includes("medium")) return 500;
  if (s.includes("bold")) return 700;
  return 400;
}
function mapFont(fontName) {
  return { family: mapFamily(fontName.family), weight: mapWeight(fontName.style), italic: /italic|oblique/i.test(fontName.style) };
}

// ---------- paints ----------
function visiblePaints(paints) {
  if (!paints || paints === figma.mixed) return [];
  return paints.filter((p) => p.visible !== false && (p.opacity == null || p.opacity > 0));
}
function rgb(c) { return [round(c.r, 4), round(c.g, 4), round(c.b, 4)]; }

function sampleStops(stops, t) {
  if (t <= stops[0][0]) return stops[0].slice(1);
  const last = stops[stops.length - 1];
  if (t >= last[0]) return last.slice(1);
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) {
      const a = stops[i - 1], b = stops[i];
      const k = (t - a[0]) / ((b[0] - a[0]) || 1e-9);
      return [1, 2, 3, 4].map((j) => a[j] + (b[j] - a[j]) * k);
    }
  }
  return last.slice(1);
}

// Linear gradient → Roblox UIGradient rotation + keypoints remapped to the rotated box.
function linearGradient(p, w, h) {
  const T = [p.gradientTransform[0].slice(), p.gradientTransform[1].slice()];
  const I = inv(T);
  const s = apply(I, 0, 0.5), e = apply(I, 1, 0.5);
  const sx = s[0] * w, sy = s[1] * h, ex = e[0] * w, ey = e[1] * h;
  const dx = ex - sx, dy = ey - sy;
  const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len, uy = dy / len;
  const proj = [0 * ux + 0 * uy, w * ux, h * uy, w * ux + h * uy];
  const pmin = Math.min.apply(null, proj), pmax = Math.max.apply(null, proj);
  const span = (pmax - pmin) || 1;
  const p0 = sx * ux + sy * uy;
  const op = p.opacity == null ? 1 : p.opacity;
  let stops = p.gradientStops.map((st) => [(p0 + st.position * len - pmin) / span, st.color.r, st.color.g, st.color.b, st.color.a * op]);
  stops.sort((a, b) => a[0] - b[0]);
  const out = [[0].concat(sampleStops(stops, 0))];
  for (const st of stops) if (st[0] > 0.0005 && st[0] < 0.9995) out.push(st);
  out.push([1].concat(sampleStops(stops, 1)));
  let final = out;
  if (final.length > 20) {
    final = [];
    for (let i = 0; i < 20; i++) { const t = i / 19; final.push([t].concat(sampleStops(out, t))); }
  }
  for (let i = 1; i < final.length; i++) if (final[i][0] <= final[i - 1][0]) final[i][0] = Math.min(1, final[i - 1][0] + 0.0001);
  return { kind: "gradient", rot: round(Math.atan2(dy, dx) * 180 / Math.PI, 2), stops: final.map((st) => st.map((v) => round(v, 4))) };
}

function radialAsLinear(p) {
  const op = p.opacity == null ? 1 : p.opacity;
  const stops = p.gradientStops.map((st) => [st.position, st.color.r, st.color.g, st.color.b, st.color.a * op]);
  const out = [[0].concat(sampleStops(stops, 0))];
  for (const st of stops) if (st[0] > 0.0005 && st[0] < 0.9995) out.push(st);
  out.push([1].concat(sampleStops(stops, 1)));
  return { kind: "gradient", rot: 90, stops: out.slice(0, 20).map((st) => st.map((v) => round(v, 4))) };
}

// ---------- export state ----------
let images = [];          // [{ key, bytes }]
let imageKeyByHash = {};  // figma image hash -> key
let warnings = [];
let keyCounter = 0;

function warn(node, msg) { warnings.push(node.name + ": " + msg); }

async function addImageFromHash(hash) {
  if (imageKeyByHash[hash]) return imageKeyByHash[hash];
  const img = figma.getImageByHash(hash);
  if (!img) return null;
  const bytes = await img.getBytesAsync();
  const key = "k" + (keyCounter++);
  images.push({ key, bytes });
  imageKeyByHash[hash] = key;
  return key;
}

function isShape(n) { return ["VECTOR", "STAR", "POLYGON", "LINE", "BOOLEAN_OPERATION"].includes(n.type); }
function hasChildren(n) { return "children" in n && n.children.length > 0; }

function collectKeepers(n, out) {
  if (!("children" in n)) return out;
  for (const c of n.children) {
    if (parseName(c.name).tags.keep) out.push(c);
    else collectKeepers(c, out);
  }
  return out;
}

// Exact mode: a decorative subtree (no text, no tagged descendants) becomes one image so it looks identical.
const LIVE_TAGS = ["scroll", "list", "grid", "textbox", "frame", "txt", "canvas", "tabgroup", "stroke", "flow", "sparkle", "select"];
let exactMode = true;
function hasLiveContent(n, isSelf) {
  if (n.type === "TEXT") return true;
  const t = parseName(n.name).tags;
  if (isSelf) { if (LIVE_TAGS.some((k) => t[k] !== undefined)) return true; }
  else if (Object.keys(t).length) return true;
  if ("children" in n) for (const c of n.children) if (hasLiveContent(c, false)) return true;
  return false;
}
function isSimple(n) {
  if (hasChildren(n)) return false;
  if ("effects" in n && n.effects.some((e) => e.visible !== false)) return false;
  if (n.blendMode && n.blendMode !== "NORMAL" && n.blendMode !== "PASS_THROUGH") return false;
  const fills = visiblePaints(n.fills);
  if (fills.length > 1 || fills.some((p) => p.type !== "SOLID")) return false;
  const strokes = visiblePaints(n.strokes);
  return strokes.length === 0 || (strokes.length === 1 && strokes[0].type === "SOLID");
}

function needsBake(n, tags) {
  if (tags.image) return "tag";
  if (blendTargets.has(n.id)) return "blend";
  // pure artwork (vectors/shapes, no text, no tagged layers inside) is always one image, so it keeps
  // its internal blending and moves as a whole (e.g. a spinning ray group)
  const STRUCT = ["scroll", "list", "grid", "textbox", "frame", "txt", "tabgroup", "select", "canvas"];
  if (hasChildren(n) && n.type !== "TEXT" && !STRUCT.some((k) => tags[k] !== undefined) && !n.children.some((c) => hasLiveContent(c, false))) return "art";
  if (tags.frame || tags.txt) return null;
  if (exactMode && n.type !== "TEXT" && !isSimple(n) && !hasLiveContent(n, true)) return "exact";
  if (isShape(n)) return "shape";
  if (n.type === "ELLIPSE") {
    const arc = n.arcData;
    const fullArc = !arc || (arc.innerRadius === 0 && Math.abs(arc.endingAngle - arc.startingAngle) >= Math.PI * 2 - 0.01);
    if (!fullArc || Math.abs(n.width - n.height) > 0.5) return "ellipse";
  }
  if ("children" in n && n.children.some((c) => c.isMask)) return "mask";
  const fills = visiblePaints(n.fills);
  if (n.type === "TEXT") {
    if (fills.some((p) => p.type !== "SOLID")) return "text-fill";
    return null;
  }
  const exotic = fills.some((p) => p.type !== "SOLID" && p.type !== "GRADIENT_LINEAR" && p.type !== "IMAGE");
  if (exotic && !hasChildren(n)) return "fill";
  if (fills.length > 1 && !hasChildren(n)) {
    const top = fills[fills.length - 1];
    const allSolidBelowImage = top.type === "IMAGE" && fills.length === 2 && fills[0].type === "SOLID";
    if (!allSolidBelowImage) return "multi-fill";
  }
  return null;
}

// Geometry of node n in the local space of its exported parent (parentM = parent's absoluteTransform).
function geometry(n, parentM, parentRot, baked) {
  if (baked) {
    const bb = n.absoluteRenderBounds || n.absoluteBoundingBox || { x: n.absoluteTransform[0][2], y: n.absoluteTransform[1][2], width: n.width, height: n.height };
    const c = apply(inv(parentM), bb.x + bb.width / 2, bb.y + bb.height / 2);
    return { x: c[0], y: c[1], w: bb.width, h: bb.height, rot: -parentRot, worldRot: 0, m: [[1, 0, bb.x], [0, 1, bb.y]] };
  }
  const m = n.absoluteTransform;
  const wc = apply(m, n.width / 2, n.height / 2);
  const c = apply(inv(parentM), wc[0], wc[1]);
  const worldRot = angleOf(m);
  return { x: c[0], y: c[1], w: n.width, h: n.height, rot: worldRot - parentRot, worldRot, m };
}

function readStroke(n) {
  const strokes = visiblePaints(n.strokes);
  if (!strokes.length) return null;
  let weight = n.strokeWeight;
  if (weight === figma.mixed || weight == null) weight = Math.max(n.strokeTopWeight || 0, n.strokeBottomWeight || 0, n.strokeLeftWeight || 0, n.strokeRightWeight || 0);
  if (!weight) return null;
  const p = strokes[strokes.length - 1];
  const out = { weight: round(weight, 2), align: n.strokeAlign || "CENTER" };
  if (p.type === "SOLID") { out.color = rgb(p.color); out.a = p.opacity == null ? 1 : p.opacity; }
  else if (p.type === "GRADIENT_LINEAR") { out.color = [1, 1, 1]; out.a = 1; out.gradient = linearGradient(p, n.width, n.height); }
  else if (p.type.startsWith("GRADIENT")) { out.color = [1, 1, 1]; out.a = 1; out.gradient = radialAsLinear(p); warn(n, "non-linear stroke gradient approximated"); }
  else { warn(n, "image stroke skipped"); return null; }
  return out;
}

function readRadius(n) {
  if (n.type === "ELLIPSE") return Math.min(n.width, n.height) / 2;
  if (!("cornerRadius" in n)) return 0;
  if (n.cornerRadius === figma.mixed) {
    const r = [n.topLeftRadius, n.topRightRadius, n.bottomLeftRadius, n.bottomRightRadius];
    warn(n, "different corner radii; Roblox uses one radius (max taken)");
    return Math.max.apply(null, r);
  }
  return n.cornerRadius || 0;
}

function readShadow(n) {
  if (!("effects" in n)) return null;
  let shadow = null;
  for (const e of n.effects) {
    if (e.visible === false) continue;
    if (e.type === "DROP_SHADOW" && !shadow) {
      shadow = { color: rgb(e.color), a: round(e.color.a, 3), x: e.offset.x, y: e.offset.y, blur: e.radius, spread: e.spread || 0 };
    } else if (e.type === "INNER_SHADOW") warn(n, "inner shadow not supported (skipped)");
    else if (e.type === "LAYER_BLUR" || e.type === "BACKGROUND_BLUR") warn(n, "blur not supported (skipped)");
  }
  return shadow;
}

async function readFill(n, out) {
  const fills = visiblePaints(n.fills);
  if (!fills.length) return;
  const top = fills[fills.length - 1];
  if (top.type === "IMAGE") {
    if (!top.imageHash) return;
    const key = await addImageFromHash(top.imageHash);
    const modes = { FILL: "Crop", FIT: "Fit", TILE: "Tile", CROP: "Stretch" };
    out.img = { id: key, mode: modes[top.scaleMode] || "Stretch", a: top.opacity == null ? 1 : top.opacity };
    if (top.scaleMode === "TILE") {
      const size = await figma.getImageByHash(top.imageHash).getSizeAsync();
      const sf = top.scalingFactor || 1;
      out.img.tile = [round(size.width * sf, 1), round(size.height * sf, 1)];
    }
    if (top.scaleMode === "CROP") warn(n, "image crop approximated as stretch");
    const below = fills.slice(0, -1).reverse().find((p) => p.type === "SOLID");
    if (below) out.fill = { kind: "solid", color: rgb(below.color), a: below.opacity == null ? 1 : below.opacity };
    return;
  }
  if (fills.length > 1) warn(n, "multiple fills; only the top one is used");
  if (top.type === "SOLID") out.fill = { kind: "solid", color: rgb(top.color), a: top.opacity == null ? 1 : top.opacity };
  else if (top.type === "GRADIENT_LINEAR") out.fill = linearGradient(top, n.width, n.height);
  else if (top.type.startsWith("GRADIENT")) { out.fill = radialAsLinear(top); warn(n, "non-linear gradient approximated as linear"); }
}

function escapeRich(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}
function applyCase(s, textCase) {
  if (textCase === "UPPER") return s.toUpperCase();
  if (textCase === "LOWER") return s.toLowerCase();
  if (textCase === "TITLE") return s.replace(/\b\w/g, (ch) => ch.toUpperCase());
  return s;
}
function hex(c) { return "#" + [c.r, c.g, c.b].map((v) => Math.round(v * 255).toString(16).padStart(2, "0")).join(""); }

function readText(n) {
  const segs = n.getStyledTextSegments(["fontName", "fontSize", "fills", "textDecoration", "textCase", "lineHeight"]);
  // dominant segment = longest
  let base = segs[0];
  for (const s of segs) if (s.characters.length > base.characters.length) base = s;
  const solid = (s) => { const f = visiblePaints(s.fills).filter((p) => p.type === "SOLID"); return f.length ? f[f.length - 1] : null; };
  const bf = solid(base);
  const t = {
    font: mapFont(base.fontName),
    size: round(base.fontSize, 2),
    color: bf ? rgb(bf.color) : [0, 0, 0],
    a: bf ? (bf.opacity == null ? 1 : bf.opacity) : 0,
    alignX: n.textAlignHorizontal === "JUSTIFIED" ? "LEFT" : n.textAlignHorizontal,
    alignY: n.textAlignVertical,
    wrap: n.textAutoResize !== "WIDTH_AND_HEIGHT",
    autoW: n.textAutoResize === "WIDTH_AND_HEIGHT" && !n.characters.includes("\n"),
    lineH: 1,
  };
  const lh = base.lineHeight;
  if (lh && lh.unit === "PIXELS") t.lineH = round(lh.value / (base.fontSize * 1.2), 3);
  else if (lh && lh.unit === "PERCENT") t.lineH = round(lh.value / 100 / 1.2, 3);
  t.lineH = Math.min(3, Math.max(1, t.lineH));
  const uniform = segs.every((s) => {
    const f = solid(s);
    return s.fontName.family === base.fontName.family && s.fontName.style === base.fontName.style &&
      s.fontSize === base.fontSize && s.textDecoration === "NONE" &&
      ((f && bf && hex(f.color) === hex(bf.color) && (f.opacity == null ? 1 : f.opacity) === t.a) || (!f && !bf));
  });
  if (uniform) {
    t.text = segs.map((s) => applyCase(s.characters, s.textCase)).join("");
  } else {
    t.rich = true;
    t.text = segs.map((s) => {
      let str = escapeRich(applyCase(s.characters, s.textCase));
      const f = solid(s);
      const fm = mapFont(s.fontName);
      const attrs = [];
      if (f) attrs.push('color="' + hex(f.color) + '"');
      if (f && f.opacity != null && f.opacity < 1) attrs.push('transparency="' + round(1 - f.opacity, 2) + '"');
      if (s.fontSize !== base.fontSize) attrs.push('size="' + Math.round(s.fontSize) + '"');
      if (fm.family !== t.font.family) attrs.push('family="rbxasset://fonts/families/' + fm.family + '.json"');
      if (fm.weight !== t.font.weight) attrs.push('weight="' + fm.weight + '"');
      if (attrs.length) str = "<font " + attrs.join(" ") + ">" + str + "</font>";
      if (fm.italic && !t.font.italic) str = "<i>" + str + "</i>";
      if (s.textDecoration === "UNDERLINE") str = "<u>" + str + "</u>";
      if (s.textDecoration === "STRIKETHROUGH") str = "<s>" + str + "</s>";
      return str;
    }).join("");
  }
  const strokeP = readStroke(n);
  if (strokeP) t.stroke = strokeP;
  return t;
}

// ---------- blend modes ----------
// Roblox can't blend layers, so a blended layer is flattened into the container that holds its backdrop.
// Text and tagged layers inside that container are hidden during the export and rebuilt live on top.
let blendTargets = new Set();
const plainBlend = (m) => !m || m === "NORMAL" || m === "PASS_THROUGH";
// layer blend, or a blend set on one of its paints (common in files imported from Photoshop)
function isBlended(n) {
  if (!plainBlend(n.blendMode)) return true;
  const paints = visiblePaints("fills" in n ? n.fills : null).concat(visiblePaints("strokes" in n ? n.strokes : null));
  return paints.some((p) => !plainBlend(p.blendMode));
}
function hasOwnFill(n) { return visiblePaints(n.fills).length > 0; }
function computeBlendTargets(root) {
  blendTargets = new Set();
  const walk = (n) => {
    if (n !== root && isBlended(n) && n.type !== "TEXT") {
      // climb to the nearest ancestor that paints a backdrop (or the export root)
      let a = n.parent;
      while (a && a !== root && !hasOwnFill(a)) a = a.parent;
      if (a) blendTargets.add(a.id);
    }
    if ("children" in n) for (const c of n.children) walk(c);
  };
  walk(root);
}
function collectLive(n, out) {
  if (!("children" in n)) return out;
  for (const c of n.children) {
    if (c.type === "TEXT" || Object.keys(parseName(c.name).tags).length) out.push(c);
    else collectLive(c, out);
  }
  return out;
}

// Paint order inside a baked node: a container's own paint, then its children; kept layers are single items.
function bakeItems(n, keepSet) {
  const out = [];
  const walk = (m, isRoot) => {
    if (!isRoot) {
      if (!m.visible) return;
      if (keepSet.has(m.id)) { out.push({ kind: "keep", node: m }); return; }
    }
    if ("children" in m && m.children.length) {
      if (hasOwnPaint(m)) out.push({ kind: "self", node: m });
      for (const ch of m.children) walk(ch, false);
    } else out.push({ kind: "leaf", node: m });
  };
  walk(n, true);
  return out;
}

// Renders only `keep` items of n, on a temporary off-canvas copy (the user's layers are never touched).
// Returns the image and where it sits in n's baked frame, or null when the slice is empty.
async function exportSlice(n, keep, items, scale, geo) {
  const copy = n.clone();
  try {
    figma.currentPage.appendChild(copy);
    copy.x += 100000;
    if (!copy.visible) copy.visible = true;
    for (const it of items) {
      if (keep.has(it)) continue;
      let m = copy;
      for (const i of pathTo(n, it.node)) m = m && "children" in m ? m.children[i] : null;
      if (!m) continue;
      if (it.kind === "self") {
        if ("fills" in m) m.fills = [];
        if ("strokes" in m) m.strokes = [];
        if ("effects" in m) m.effects = [];
      } else if ("opacity" in m) m.opacity = 0;
    }
    const crb = copy.absoluteRenderBounds;
    if (!crb || crb.width < 0.5 || crb.height < 0.5) return null;
    const bytes = await copy.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } });
    // the copy was moved; map its bounds back onto the original
    const sx = copy.absoluteTransform[0][2] - n.absoluteTransform[0][2];
    const sy = copy.absoluteTransform[1][2] - n.absoluteTransform[1][2];
    return { bytes, x: crb.x - sx - geo.m[0][2], y: crb.y - sy - geo.m[1][2], w: crb.width, h: crb.height };
  } finally {
    if (!copy.removed) copy.remove();
  }
}

async function bakeNode(n, out, geo, reason) {
  const max = Math.max(geo.w, geo.h, 1);
  const scale = Math.max(0.05, Math.min(2, 1024 / max));
  const keepers = reason === "blend" ? collectLive(n, []) : collectKeepers(n, []);
  if (!keepers.length) {
    // plain bake: one image
    const wasVisible = n.visible;
    try {
      if (!wasVisible) n.visible = true;
      const bytes = await n.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } });
      const key = "k" + (keyCounter++);
      images.push({ key, bytes });
      out.type = "image";
      out.img = { id: key, mode: "Stretch", a: 1 };
    } finally {
      if (!wasVisible) n.visible = false;
    }
    return;
  }
  // Layers that stay live (text, tagged, _keep) are interleaved with image slices in Figma's paint order,
  // so static art drawn above a spinning layer stays above it in Roblox.
  const keepSet = new Set(keepers.map((k) => k.id));
  const items = bakeItems(n, keepSet);
  out.type = "frame";
  delete out.fill;
  out.children = [];
  let slice = [], sliceNo = 0;
  const flush = async () => {
    if (!slice.length) return;
    const s = await exportSlice(n, new Set(slice), items, scale, geo);
    slice = [];
    if (!s) return;
    const key = "k" + (keyCounter++);
    images.push({ key, bytes: s.bytes });
    out.children.push({
      id: n.id + "#slice" + (sliceNo++), name: out.name + "_Art", tags: {}, type: "image",
      x: round(s.x + s.w / 2, 2), y: round(s.y + s.h / 2, 2), w: round(s.w, 2), h: round(s.h, 2), rot: 0,
      visible: true, opacity: 1, img: { id: key, mode: "Stretch", a: 1 },
    });
  };
  for (const it of items) {
    if (it.kind === "keep") {
      await flush();
      const child = await exportNode(it.node, geo.m, 0);
      if (child) out.children.push(child);
    } else slice.push(it);
  }
  await flush();
}

async function exportNode(n, parentM, parentRot, isRoot) {
  const parsed = parseName(n.name);
  const tags = parsed.tags;
  if (tags.ignore) return null;
  if (["SLICE", "CONNECTOR", "STICKY", "SHAPE_WITH_TEXT", "CODE_BLOCK", "WIDGET", "EMBED", "LINK_UNFURL", "MEDIA", "TABLE"].includes(n.type)) return null;
  if (n.isMask) return null; // masks are handled by baking their parent

  const bakeReason = needsBake(n, tags);
  // The root is placed inside a holder the size of its own frame, so its outer stroke/shadow survive.
  const geo = isRoot
    ? geometry(n, n.absoluteTransform, angleOf(n.absoluteTransform), !!bakeReason)
    : geometry(n, parentM, parentRot, !!bakeReason);
  if (isRoot) geo.rot = 0;

  const out = {
    id: n.id, name: parsed.name, tags,
    x: round(geo.x, 2), y: round(geo.y, 2), w: round(geo.w, 2), h: round(geo.h, 2), rot: round(geo.rot, 2),
    visible: n.visible !== false,
    opacity: n.opacity == null ? 1 : round(n.opacity, 3),
  };
  const settings = readSettings(n);
  for (const key in settings) {
    if (settings[key].Icon !== "@icon") continue;
    const b64 = n.getPluginData("fb_icon_" + key);
    if (b64) {
      const k = "k" + (keyCounter++);
      images.push({ key: k, bytes: figma.base64Decode(b64) });
      settings[key].Icon = { img: k };
    } else delete settings[key].Icon;
  }
  if (Object.keys(settings).length) out.settings = settings;
  try {
    const picked = JSON.parse(n.getPluginData("fb_link") || "null");
    if (picked && picked.id && picked.id !== n.id) out.link = { action: picked.action || "open", id: picked.id, name: picked.name };
  } catch (e) {}
  // Prototype tab: "On click → Navigate to / Open overlay" opens the target, "Back / Close overlay" closes
  if ("reactions" in n && n.reactions && n.reactions.length) {
    for (const r of n.reactions) {
      if (!r.trigger || r.trigger.type !== "ON_CLICK") continue;
      const acts = r.actions || (r.action ? [r.action] : []);
      for (const a of acts) {
        if (!a) continue;
        if (a.type === "NODE" && a.destinationId) {
          const dest = await figma.getNodeByIdAsync(a.destinationId);
          if (dest && dest.id !== n.id) out.link = { action: "open", id: dest.id, name: parseName(dest.name).name };
        } else if (a.type === "BACK" || a.type === "CLOSE") {
          out.link = { action: "close" };
        }
      }
    }
  }

  if (bakeReason) {
    if (bakeReason === "text-fill") warn(n, "gradient/image text exported as image");
    if (bakeReason === "blend") warn(n, "blend mode flattened into images; text and tagged layers stay live, in Figma's layer order");
    await bakeNode(n, out, geo, bakeReason);
    return out;
  }

  if (n.type === "TEXT") {
    out.type = "text";
    out.text = readText(n);
    if (visiblePaints(n.fills).some((p) => p.type !== "SOLID")) warn(n, "non-solid text fill dropped (_txt)");
    const sh = readShadow(n);
    if (sh) warn(n, "text shadow not supported (skipped)");
    return out;
  }

  out.type = "frame";
  await readFill(n, out);
  if (tags.frame) {
    const fills = visiblePaints(n.fills);
    if (fills.some((p) => p.type !== "SOLID" && p.type !== "GRADIENT_LINEAR" && p.type !== "IMAGE")) warn(n, "unsupported fill simplified (_frame)");
  }
  const stroke = readStroke(n);
  if (stroke) out.stroke = stroke;
  const radius = readRadius(n);
  if (radius > 0) out.radius = round(Math.min(radius, Math.min(n.width, n.height) / 2), 2);
  const shadow = readShadow(n);
  if (shadow) out.shadow = shadow;
  if (n.clipsContent) out.clip = true;

  if ("children" in n && n.children.length) {
    out.children = [];
    for (const c of n.children) {
      const child = await exportNode(c, geo.m, geo.worldRot, false);
      if (child) out.children.push(child);
    }
  }
  return out;
}

// ---------- plugin wiring ----------
figma.showUI(__html__, { width: 380, height: 660, themeColors: true });

function selectionInfo() {
  const sel = figma.currentPage.selection;
  return sel.map((n) => {
    const settings = readSettings(n);
    const icons = {};
    for (const key in settings) if (settings[key].Icon === "@icon") icons[key] = n.getPluginData("fb_icon_" + key);
    let link = null;
    try { link = JSON.parse(n.getPluginData("fb_link") || "null"); } catch (e) {}
    return { id: n.id, name: n.name, type: n.type, tags: parseName(n.name).tags, settings, icons, link };
  });
}
let thumbFor = null;
function collectTagged(n, out) {
  if (!("children" in n)) return out;
  for (const ch of n.children) {
    if (!ch.visible) continue;
    const t = parseName(ch.name).tags;
    if (Object.keys(t).length && !t.ignore) out.push(ch);
    else collectTagged(ch, out);
  }
  return out;
}
function boundsOf(n) { return n.absoluteRenderBounds || n.absoluteBoundingBox || { x: 0, y: 0, width: n.width, height: n.height }; }
function layerInfo(n) {
  const settings = readSettings(n);
  const icons = {};
  for (const key in settings) if (settings[key].Icon === "@icon") icons[key] = n.getPluginData("fb_icon_" + key);
  return { id: n.id, name: n.name, type: n.type, tags: parseName(n.name).tags, settings, icons };
}
function pathTo(root, node) {
  const path = [];
  for (let n = node; n && n !== root; n = n.parent) path.unshift(n.parent.children.indexOf(n));
  return path;
}
function hasOwnPaint(n) {
  return visiblePaints("fills" in n ? n.fills : null).length > 0 || visiblePaints("strokes" in n ? n.strokes : null).length > 0 ||
    ("effects" in n && n.effects.some((e) => e.visible !== false));
}
// Paint order of the selection: a container's own fill/stroke, then its children; tagged layers are single items.
function paintItems(n, root, out) {
  if (n !== root) {
    if (!n.visible) return out;
    const t = parseName(n.name).tags;
    if (Object.keys(t).length && !t.ignore) { out.push({ kind: "layer", node: n }); return out; }
  }
  if ("children" in n && n.children.length) {
    if (hasOwnPaint(n)) out.push({ kind: "self", node: n });
    for (const ch of n.children) paintItems(ch, root, out);
  } else out.push({ kind: "leaf", node: n });
  return out;
}
async function postThumb() {
  const sel = figma.currentPage.selection;
  if (sel.length !== 1 || !("exportAsync" in sel[0])) return;
  const n = sel[0];
  if (thumbFor === n.id) return; // look unchanged by tag/setting edits
  thumbFor = n.id;
  const copies = [];
  selfEditUntil = Infinity;
  try {
    const rb = boundsOf(n);
    const scale = Math.min(2, 300 / Math.max(rb.width, rb.height, 1));
    const items = paintItems(n, n, []);
    const tagged = items.filter((it) => it.kind === "layer").slice(0, 12);
    const stack = [];
    if (!tagged.length) {
      stack.push({ type: "chunk", bytes: await n.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } }) });
    } else {
      // group consecutive static items into slices; each slice is rendered on a temporary off-canvas copy
      const groups = [[]];
      for (const it of items) {
        if (it.kind === "layer") { if (tagged.includes(it)) groups.push(it, []); }
        else groups[groups.length - 1].push(it);
      }
      for (const g of groups) {
        if (!Array.isArray(g)) {
          const t = g.node, tb = boundsOf(t);
          if (!tb || tb.width < 1 || tb.height < 1) continue;
          const bytes = await t.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } });
          stack.push(Object.assign({ type: "layer" }, layerInfo(t), { bytes, x: tb.x - rb.x, y: tb.y - rb.y, w: tb.width, h: tb.height }));
          continue;
        }
        if (!g.length && stack.length) continue; // empty slice between two animated layers
        const keep = new Set(g);
        const copy = n.clone();
        copies.push(copy);
        figma.currentPage.appendChild(copy);
        copy.x += 100000;
        for (const it of items) {
          if (keep.has(it)) continue;
          let m = copy;
          for (const i of pathTo(n, it.node)) m = m && "children" in m ? m.children[i] : null;
          if (!m) continue;
          if (it.kind === "self") {
            // drop only the container's own paint, keep its children
            if ("fills" in m) m.fills = [];
            if ("strokes" in m) m.strokes = [];
            if ("effects" in m) m.effects = [];
          } else if ("opacity" in m) m.opacity = 0; // opacity keeps the copy's bounds identical
        }
        stack.push({ type: "chunk", bytes: await copy.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } }) });
        copy.remove();
      }
    }
    figma.ui.postMessage({ type: "scene", id: n.id, w: rb.width, h: rb.height, stack });
  } catch (e) {
    thumbFor = null;
  } finally {
    for (const cp of copies) if (!cp.removed) cp.remove();
    selfEditUntil = Date.now() + 1000;
  }
}
// Windows a button can open: frames/groups on the page (inside Sections too), frames one level inside them,
// and any _panel layer.
const WINDOW_TYPES = ["FRAME", "GROUP", "COMPONENT", "INSTANCE", "COMPONENT_SET"];
function windowCandidates() {
  const out = [], seen = new Set();
  const add = (n) => { if (!seen.has(n.id)) { seen.add(n.id); out.push(n); } };
  const scan = (parent, depth) => {
    if (depth > 3 || !("children" in parent)) return;
    for (const n of parent.children) {
      if (n.type === "SECTION") { scan(n, depth); continue; } // sections don't count as a level
      if (!WINDOW_TYPES.includes(n.type)) continue;
      if (n.width >= 24 && n.height >= 24) add(n);
      scan(n, depth + 1);
    }
  };
  try {
    scan(figma.currentPage, 0);
    for (const n of figma.currentPage.findAll((x) => parseName(x.name).tags.panel !== undefined)) add(n);
  } catch (e) {}
  return out;
}
function describePage() {
  const kids = figma.currentPage.children;
  const counts = {};
  for (const n of kids) counts[n.type] = (counts[n.type] || 0) + 1;
  return "Page “" + figma.currentPage.name + "”: " + kids.length + " top-level layers (" +
    Object.entries(counts).map(([t, k]) => k + " " + t.toLowerCase()).join(", ") + ")";
}

// names of every _panel layer on this page, for the "On click" picker
function pagePanels() {
  const names = new Set();
  try {
    for (const n of figma.currentPage.findAll((n) => parseName(n.name).tags.panel !== undefined)) names.add(parseName(n.name).name);
    // top-level frames too: any of them can be opened by name (e.g. a Shop imported on its own)
    for (const n of windowCandidates()) names.add(parseName(n.name).name);
  } catch (e) {}
  return [...names].sort((a, b) => a.localeCompare(b));
}
function postSelection() {
  figma.ui.postMessage({ type: "selection", selection: selectionInfo(), panels: pagePanels() });
  postThumb();
}
figma.on("selectionchange", () => { thumbFor = null; });
let thumbTimer = null;
function onNodeChange(e) {
  // the scene export hides layers for a moment; don't react to that
  if (Date.now() < selfEditUntil) return; // our own export (copies, baking) — not a user edit
  thumbFor = null; clearTimeout(thumbTimer); thumbTimer = setTimeout(postThumb, 400);
}
figma.currentPage.on("nodechange", onNodeChange);
figma.on("currentpagechange", () => figma.currentPage.on("nodechange", onNodeChange));
figma.on("selectionchange", postSelection);

(async () => {
  const server = (await figma.clientStorage.getAsync("server")) || "http://localhost:7777";
  const size = await figma.clientStorage.getAsync("size");
  if (size && size.w && size.h) figma.ui.resize(size.w, size.h);
  const myPresets = (await figma.clientStorage.getAsync("myPresets")) || [];
  figma.ui.postMessage({ type: "init", server, tags: TAGS, defaults: DEFAULTS, presets: PRESETS, sections: SECTIONS, myPresets });
  postSelection();
})();

// ---------- pre-export check: things that won't look or behave the same in Roblox
async function checkDesign(root) {
  const issues = [];
  const add = (n, level, msg) => issues.push({ id: n.id, name: n.name, level, msg });
  const panels = {};
  const refs = [];
  const walk = async (n) => {
    if (!n.visible) return;
    const t = parseName(n.name).tags;
    if (t.panel !== undefined) panels[parseName(n.name).name] = true;
    for (const k of ["open", "toggle", "tab"]) if (typeof t[k] === "string") refs.push({ n, k, target: t[k] });
    if (n.type === "TEXT") {
      const fonts = n.fontName === figma.mixed ? n.getStyledTextSegments(["fontName"]).map((s) => s.fontName) : [n.fontName];
      for (const fnt of fonts) {
        const key = fnt.family.toLowerCase().replace(/[^a-z0-9]/g, "");
        if (!FAMILIES.some((f) => f.toLowerCase() === key) && !FAMILY_ALIAS[key]) { add(n, "warn", "Font “" + fnt.family + "” isn't in Roblox; BuilderSans will be used"); break; }
      }
      if (visiblePaints(n.fills).some((p) => p.type !== "SOLID")) add(n, "info", "Gradient/image text becomes an image (not editable)");
      if (n.fontSize !== figma.mixed && n.fontSize < 9) add(n, "warn", "Text under 9 px is hard to read on phones");
    }
    if ("effects" in n) for (const e of n.effects) {
      if (e.visible === false) continue;
      if (e.type === "INNER_SHADOW") add(n, "warn", "Inner shadow isn't supported");
      if (e.type === "LAYER_BLUR" || e.type === "BACKGROUND_BLUR") add(n, "warn", "Blur isn't supported");
    }
    if ("fills" in n) for (const p of visiblePaints(n.fills)) {
      if (p.type === "IMAGE" && p.imageHash) {
        const img = figma.getImageByHash(p.imageHash);
        const size = img && (await img.getSizeAsync());
        if (size && Math.max(size.width, size.height) > 1024) add(n, "info", "Image is " + size.width + "×" + size.height + "; Roblox caps it at 1024 px");
      }
    }
    if (isBlended(n)) add(n, "info", "Blend mode: flattened with its background into one image");
    if ("cornerRadius" in n && n.cornerRadius === figma.mixed) add(n, "info", "Different corner radii: Roblox uses one radius");
    if ("children" in n) for (const ch of n.children) await walk(ch);
  };
  await walk(root);
  for (const r of refs) if (!panels[r.target]) add(r.n, "error", "_" + r.k + ":" + r.target + " but no layer is named " + r.target + "_panel");
  if (Math.max(root.width, root.height) > 4000) add(root, "warn", "Frame is very large; consider 1920×1080");
  return issues;
}

// ---------- effects clipboard / presets: tags + their settings + picked icons
function readEffects(n) {
  const tags = parseName(n.name).tags;
  const settings = readSettings(n);
  const icons = {};
  for (const key in settings) if (settings[key].Icon === "@icon") icons[key] = n.getPluginData("fb_icon_" + key);
  return { tags, settings, icons };
}
function applyEffects(n, eff) {
  let name = n.name;
  for (const key of Object.keys(eff.tags)) name = name.replace(new RegExp("_" + key + "(:[^_]*)?(?=_|$)", "gi"), "");
  for (const [key, arg] of Object.entries(eff.tags)) name += "_" + key + (arg === true ? "" : ":" + arg);
  n.name = name;
  const st = readSettings(n);
  for (const key in eff.settings) st[key] = Object.assign({}, st[key], eff.settings[key]);
  n.setPluginData("fb_settings", JSON.stringify(st));
  for (const key in eff.icons) n.setPluginData("fb_icon_" + key, eff.icons[key]);
}

function tagToken(key, arg) { return "_" + key + (arg ? ":" + arg : ""); }

// ---------- export + live sync
let live = null;          // { rootId, code, exact, name } while live sync is on
let liveTimer = null, exportBusy = false, livePending = false;
let selfEditUntil = 0; // exports briefly toggle visibility while baking; ignore those echoes

function isLinkTarget(root) {
  try {
    return figma.currentPage.findAll((n) => {
      if (n.id === root.id) return false;
      try { const l = JSON.parse(n.getPluginData("fb_link") || "null"); if (l && l.id === root.id) return true; } catch (e) {}
      if ("reactions" in n && n.reactions) for (const r of n.reactions) {
        const acts = r.actions || (r.action ? [r.action] : []);
        if (acts.some((a) => a && a.type === "NODE" && a.destinationId === root.id)) return true;
      }
      return false;
    }).length > 0;
  } catch (e) { return false; }
}
async function runExport(root, exact, liveCode) {
  if (!("absoluteTransform" in root) || ["SLICE", "CONNECTOR", "STICKY", "WIDGET", "EMBED", "LINK_UNFURL", "MEDIA", "TABLE"].includes(root.type)) {
    figma.ui.postMessage({ type: "error", message: "A " + root.type.toLowerCase() + " can't be converted. Select a layer or frame." });
    return;
  }
  exportBusy = true;
  images = []; imageKeyByHash = {}; warnings = []; keyCounter = 0;
  computeBlendTargets(root);
  exactMode = exact;
  for (const k in unmappedFonts) delete unmappedFonts[k];
  try {
    figma.ui.postMessage({ type: "status", message: liveCode ? "Syncing…" : "Reading layers…" });
    selfEditUntil = Infinity;
    const tree = await exportNode(root, root.absoluteTransform, 0, true);
    selfEditUntil = Date.now() + 800;
    if (!tree) { exportBusy = false; figma.ui.postMessage({ type: "error", message: "This layer is skipped (_ignore or mask)." }); return; }
    for (const f in unmappedFonts) warnings.push("Font '" + f + "' not in Roblox; using BuilderSans");
    const doc = { version: 1, name: tree.name, w: round(root.width, 2), h: round(root.height, 2), root: tree, warnings };
    if (isLinkTarget(root)) {
      doc.startHidden = true; // a button opens it, so it starts closed in Roblox
      warnings.push(tree.name + ": a button opens this window, so it starts hidden in Roblox");
    }
    figma.ui.postMessage({ type: "exported", doc, images, live: liveCode });
  } catch (e) {
    exportBusy = false;
    selfEditUntil = Date.now() + 800;
    figma.ui.postMessage({ type: "error", message: "Export failed: " + (e && e.message ? e.message : e) });
  }
}

function insideLive(node) {
  for (let n = node; n; n = n.parent) if (n.id === live.rootId) return true;
  return false;
}
function scheduleLive(delay) {
  clearTimeout(liveTimer);
  liveTimer = setTimeout(async () => {
    if (!live) return;
    if (exportBusy) { livePending = true; return; }
    const root = await figma.getNodeByIdAsync(live.rootId);
    if (!root || root.removed) { live = null; figma.ui.postMessage({ type: "live", on: false, message: "The synced frame was deleted." }); return; }
    await runExport(root, live.exact, live.code);
  }, delay);
}
function onLiveChange(e) {
  if (!live) return;
  if (Date.now() < selfEditUntil) return; // our own export (copies, baking) — not a user edit
  const touched = e.nodeChanges.some((ch) => (ch.node && !ch.node.removed ? insideLive(ch.node) : false));
  if (!touched) return;
  if (exportBusy) livePending = true; // export again once the current upload finishes
  else scheduleLive(1000);            // wait until editing pauses
}
figma.currentPage.on("nodechange", onLiveChange);
figma.on("currentpagechange", () => figma.currentPage.on("nodechange", onLiveChange));

figma.ui.onmessage = async (msg) => {
  if (msg.type === "resize") {
    const w = Math.max(320, Math.min(1400, msg.w)), h = Math.max(420, Math.min(1400, msg.h));
    figma.ui.resize(w, h);
    if (msg.save) await figma.clientStorage.setAsync("size", { w, h });
  } else if (msg.type === "saveServer") {
    await figma.clientStorage.setAsync("server", msg.server);
  } else if (msg.type === "toggleTag") {
    const sel = figma.currentPage.selection;
    if (!sel.length) { figma.notify("Select layers first"); return; }
    for (const n of sel) {
      const parsed = parseName(n.name);
      const has = parsed.tags[msg.key] !== undefined;
      if (has) {
        // remove every token for this key (with or without argument)
        const re = new RegExp("_" + msg.key + "(:[^_]*)?(?=_|$)", "gi");
        n.name = n.name.replace(re, "");
      } else {
        n.name = n.name + tagToken(msg.key, msg.arg);
      }
    }
    postSelection();
  } else if (msg.type === "setIcon") {
    const target = await figma.getNodeByIdAsync(msg.targetId);
    const icon = await figma.getNodeByIdAsync(msg.iconId);
    if (!target || !icon || !("exportAsync" in icon)) { figma.notify("That layer can't be used as an icon"); return; }
    const scale = Math.min(4, 128 / Math.max(icon.width, icon.height, 1));
    const bytes = await icon.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } });
    target.setPluginData("fb_icon_" + msg.key, figma.base64Encode(bytes));
    const st = readSettings(target);
    st[msg.key] = Object.assign({}, st[msg.key], { Icon: "@icon" });
    target.setPluginData("fb_settings", JSON.stringify(st));
    figma.currentPage.selection = [target];
    figma.notify("Icon set from “" + icon.name + "”");
    postSelection();
  } else if (msg.type === "listWindows") {
    // candidates: loose frames on the page and any _panel layer, except the button's own window
    const btn = await figma.getNodeByIdAsync(msg.targetId);
    let own = btn;
    while (own && own.parent && own.parent.type !== "PAGE") own = own.parent;
    const seen = new Set(), list = [];
    const addNode = async (n) => {
      if (seen.has(n.id) || list.length >= 40) return;
      seen.add(n.id);
      let bytes = null;
      try {
        if ("exportAsync" in n) {
          const scale = Math.min(1, 160 / Math.max(n.width || 1, n.height || 1, 1));
          bytes = await n.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: scale } });
        }
      } catch (e) {}
      list.push({ id: n.id, name: parseName(n.name).name, bytes, own: own && n.id === own.id });
    };
    const isAncestorOrSelf = (n) => { for (let x = btn; x; x = x.parent) if (x.id === n.id) return true; return false; };
    const isInsideButton = (n) => { for (let x = n.parent; x; x = x.parent) if (btn && x.id === btn.id) return true; return false; };
    for (const n of windowCandidates()) {
      if (isInsideButton(n)) continue;                                  // pieces of the button itself
      if (isAncestorOrSelf(n) && !(own && n.id === own.id)) continue;   // what the button sits in
      await addNode(n);
    }
    figma.ui.postMessage({ type: "windows", targetId: msg.targetId, list, info: describePage() });
  } else if (msg.type === "setLink") {
    const btn = await figma.getNodeByIdAsync(msg.targetId);
    const dest = await figma.getNodeByIdAsync(msg.destId);
    if (!btn || !dest) return;
    if (dest.id === btn.id) { figma.notify("A button can't open itself — pick another window"); return; }
    btn.setPluginData("fb_link", JSON.stringify({ action: msg.action || "open", id: dest.id, name: parseName(dest.name).name }));
    figma.currentPage.selection = [btn];
    figma.notify("Clicking “" + parseName(btn.name).name + "” will open “" + parseName(dest.name).name + "”");
    postSelection();
  } else if (msg.type === "clearLink") {
    for (const n of figma.currentPage.selection) n.setPluginData("fb_link", "");
    postSelection();
  } else if (msg.type === "clearIcon") {
    for (const n of figma.currentPage.selection) {
      n.setPluginData("fb_icon_" + msg.key, "");
      const st = readSettings(n);
      if (st[msg.key]) { delete st[msg.key].Icon; if (!Object.keys(st[msg.key]).length) delete st[msg.key]; }
      n.setPluginData("fb_settings", JSON.stringify(st));
    }
    postSelection();
  } else if (msg.type === "check") {
    const sel = figma.currentPage.selection;
    if (sel.length !== 1) { figma.ui.postMessage({ type: "checked", issues: null }); return; }
    figma.ui.postMessage({ type: "checked", issues: await checkDesign(sel[0]) });
  } else if (msg.type === "focusNode") {
    const n = await figma.getNodeByIdAsync(msg.id);
    if (n) { figma.currentPage.selection = [n]; figma.viewport.scrollAndZoomIntoView([n]); }
  } else if (msg.type === "copyEffects") {
    const sel = figma.currentPage.selection;
    if (sel.length !== 1) { figma.notify("Select one layer to copy from"); return; }
    figma.ui.postMessage({ type: "effects", effects: readEffects(sel[0]), purpose: msg.purpose, name: msg.name });
  } else if (msg.type === "applyEffects") {
    const sel = figma.currentPage.selection;
    if (!sel.length) { figma.notify("Select the layers to paste onto"); return; }
    for (const n of sel) applyEffects(n, msg.effects);
    figma.notify("Effects applied to " + sel.length + " layer" + (sel.length > 1 ? "s" : ""));
    postSelection();
  } else if (msg.type === "savePresets") {
    await figma.clientStorage.setAsync("myPresets", msg.list);
  } else if (msg.type === "replaceTags") {
    // remove every tag in msg.remove, then append msg.add ([key, arg] pairs)
    const sel = figma.currentPage.selection;
    if (!sel.length) { figma.notify("Select a layer first"); return; }
    for (const n of sel) {
      let name = n.name;
      for (const key of msg.remove) name = name.replace(new RegExp("_" + key + "(:[^_]*)?(?=_|$)", "gi"), "");
      for (const [key, arg] of msg.add) name += tagToken(key, arg);
      n.name = name;
    }
    postSelection();
  } else if (msg.type === "preset") {
    const sel = figma.currentPage.selection;
    if (!sel.length) { figma.notify("Select layers first"); return; }
    for (const n of sel) {
      const tags = parseName(n.name).tags;
      for (const key of msg.keys) if (tags[key] === undefined) n.name += tagToken(key);
    }
    postSelection();
  } else if (msg.type === "setSetting") {
    for (const n of figma.currentPage.selection) {
      const s = readSettings(n);
      s[msg.key] = s[msg.key] || {};
      if (msg.value === null) delete s[msg.key][msg.field];
      else s[msg.key][msg.field] = msg.value;
      if (!Object.keys(s[msg.key]).length) delete s[msg.key];
      n.setPluginData("fb_settings", JSON.stringify(s));
    }
    postSelection();
  } else if (msg.type === "clearTags") {
    for (const n of figma.currentPage.selection) {
      const parsed = parseName(n.name);
      n.name = parsed.name;
    }
    postSelection();
  } else if (msg.type === "export") {
    const sel = figma.currentPage.selection;
    if (sel.length !== 1) { figma.ui.postMessage({ type: "error", message: "Select exactly one frame." }); return; }
    await runExport(sel[0], msg.exact !== false, null);
  } else if (msg.type === "liveStart") {
    const sel = figma.currentPage.selection;
    if (sel.length !== 1) { figma.ui.postMessage({ type: "live", on: false, message: "Select the frame to sync first." }); return; }
    const root = sel[0];
    let code = root.getPluginData("fb_live");
    if (!/^[A-Z0-9]{6}$/.test(code)) {
      const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
      code = "";
      for (let i = 0; i < 6; i++) code += A[Math.floor(Math.random() * A.length)];
      root.setPluginData("fb_live", code);
    }
    live = { rootId: root.id, code, exact: msg.exact !== false, name: root.name };
    figma.ui.postMessage({ type: "live", on: true, code, name: root.name });
    await runExport(root, live.exact, code);
  } else if (msg.type === "liveStop") {
    live = null;
    clearTimeout(liveTimer);
    figma.ui.postMessage({ type: "live", on: false });
  } else if (msg.type === "uploadDone") {
    exportBusy = false;
    if (livePending && live) { livePending = false; scheduleLive(0); }
  }
};
