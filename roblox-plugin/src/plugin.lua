--!nocheck
-- FigBridge — Roblox Studio side. Downloads a design by code and rebuilds it as native UI.
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StarterGui = game:GetService("StarterGui")
local Selection = game:GetService("Selection")

local RUNTIME_SOURCE = --@RUNTIME
local DEFAULTS = (function()
--@DEFAULTS
end)()

local CLICK_TAGS = { "button", "smooth", "press", "squish", "ripple", "burst", "open", "close", "toggle", "tab", "select", "sound", "buy" }
local FONT_WEIGHTS = {
	[100] = Enum.FontWeight.Thin, [200] = Enum.FontWeight.ExtraLight, [300] = Enum.FontWeight.Light,
	[400] = Enum.FontWeight.Regular, [500] = Enum.FontWeight.Medium, [600] = Enum.FontWeight.SemiBold,
	[700] = Enum.FontWeight.Bold, [800] = Enum.FontWeight.ExtraBold, [900] = Enum.FontWeight.Heavy,
}

---------------------------------------------------------------- helpers
local B64 = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do B64[string.byte(chars, i)] = i - 1 end
end

local function b64decode(s)
	local ok, res = pcall(function()
		return game:GetService("EncodingService"):Base64Decode(buffer.fromstring(s))
	end)
	if ok and typeof(res) == "buffer" then return res end
	local n = #s
	local pad = (string.sub(s, -2) == "==") and 2 or ((string.sub(s, -1) == "=") and 1 or 0)
	local len = n // 4 * 3 - pad
	local out = buffer.create(len)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		if o < len then buffer.writeu8(out, o, v // 65536) end
		if o + 1 < len then buffer.writeu8(out, o + 1, (v // 256) % 256) end
		if o + 2 < len then buffer.writeu8(out, o + 2, v % 256) end
		o += 3
		if i % 400000 == 1 then task.wait() end
	end
	return out
end

local function getJSON(url)
	local ok, res = pcall(HttpService.RequestAsync, HttpService, { Url = url, Method = "GET" })
	if not ok then error("Cannot reach the FigBridge server (" .. tostring(res) .. "). Is it running?", 0) end
	local data
	pcall(function() data = HttpService:JSONDecode(res.Body) end)
	if not res.Success then
		error((data and data.error) or ("Server error " .. res.StatusCode), 0)
	end
	return data
end

local function c3(t) return Color3.new(t[1], t[2], t[3]) end

local function tagString(tags)
	local parts = {}
	for k, v in tags do
		table.insert(parts, v == true and k or (k .. ":" .. tostring(v)))
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function isClickable(node)
	if node.link then return true end
	local t = node.tags or {}
	for _, k in CLICK_TAGS do if t[k] ~= nil then return true end end
	if node.children then
		for _, c in node.children do
			if c.tags and c.tags.select ~= nil and c.type ~= "text" then return true end
		end
	end
	return false
end

local function makeGradient(g, parent)
	local cs, ts = {}, {}
	local prev = -1
	for i, s in g.stops do
		local t = math.clamp(s[1], 0, 1)
		if i == 1 then t = 0 elseif i == #g.stops then t = 1 end
		if t <= prev then
			if i == #g.stops then
				cs[#cs], ts[#ts] = nil, nil -- replace previous with the final key
				t = 1
			else
				t = prev + 0.0001
			end
		end
		if t < 1 or i == #g.stops then
			table.insert(cs, ColorSequenceKeypoint.new(t, Color3.new(s[2], s[3], s[4])))
			table.insert(ts, NumberSequenceKeypoint.new(t, math.clamp(1 - s[5], 0, 1)))
			prev = t
		end
	end
	local u = Instance.new("UIGradient")
	u.Color = ColorSequence.new(cs)
	u.Transparency = NumberSequence.new(ts)
	u.Rotation = g.rot or 0
	u.Parent = parent
	return u
end

local function makeStroke(s, parent, isText, op)
	local st = Instance.new("UIStroke")
	st.Thickness = s.weight
	st.Color = c3(s.color)
	st.Transparency = 1 - (s.a or 1) * op
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.ApplyStrokeMode = isText and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	if not isText then
		pcall(function()
			st.BorderStrokePosition = (s.align == "INSIDE" and Enum.BorderStrokePosition.Inner)
				or (s.align == "OUTSIDE" and Enum.BorderStrokePosition.Outer)
				or Enum.BorderStrokePosition.Center
		end)
	end
	if s.gradient then makeGradient(s.gradient, st) end
	st.Parent = parent
	return st
end

local function setDefaults(inst, tags)
	for tag in tags do
		local d = DEFAULTS[tag]
		if d then
			for k, v in d do
				local name = tag .. "_" .. k
				if inst:GetAttribute(name) == nil then inst:SetAttribute(name, v) end
			end
		end
	end
end

local generateModule -- defined in the UI module section below

---------------------------------------------------------------- builder
local Builder = {}
Builder.__index = Builder

function Builder.new(doc, images)
	return setmetatable({ doc = doc, images = images, warnings = {} }, Builder)
end

function Builder:warn(msg) table.insert(self.warnings, msg) end

function Builder:setImage(el, img, op)
	local info = self.images[img.id]
	if info then
		if info.asset then
			el.Image = "rbxassetid://" .. info.asset
		elseif info.editable then
			pcall(function() el.ImageContent = Content.fromObject(info.editable) end)
		end
	else
		self:warn(el.Name .. ": image missing")
	end
	el.ImageTransparency = 1 - (img.a or 1) * op
	el.ScaleType = Enum.ScaleType[img.mode] or Enum.ScaleType.Stretch
	if img.tile then el.TileSize = UDim2.fromOffset(img.tile[1], img.tile[2]) end
end

function Builder:applyText(el, node, op)
	local t = node.text
	local fam = "rbxasset://fonts/families/" .. t.font.family .. ".json"
	el.FontFace = Font.new(fam, FONT_WEIGHTS[t.font.weight] or Enum.FontWeight.Regular,
		t.font.italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
	el.RichText = t.rich == true
	el.TextColor3 = c3(t.color)
	el.TextTransparency = 1 - (t.a or 1) * op
	el.TextWrapped = t.wrap
	el.LineHeight = t.lineH or 1
	el.TextXAlignment = (t.alignX == "CENTER" and Enum.TextXAlignment.Center)
		or (t.alignX == "RIGHT" and Enum.TextXAlignment.Right) or Enum.TextXAlignment.Left
	el.TextYAlignment = (t.alignY == "CENTER" and Enum.TextYAlignment.Center)
		or (t.alignY == "BOTTOM" and Enum.TextYAlignment.Bottom) or Enum.TextYAlignment.Top
	if t.autoW and not el:IsA("TextBox") then
		-- Figma box hugs the text; Roblox fonts are narrower, so scale the text to fill the same box, centred.
		el.TextScaled = true
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		el.TextSize = math.min(100, t.size)
	elseif t.size > 100 or (node.tags and node.tags.fit) then
		el.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = math.max(1, math.floor(t.size))
		c.Parent = el
		el.TextSize = math.min(100, t.size)
	else
		el.TextSize = t.size
	end
	if el:IsA("TextBox") then
		el.PlaceholderText = t.rich and node.name or t.text
		el.PlaceholderColor3 = c3(t.color)
		el.Text = ""
		el.ClearTextOnFocus = false
	else
		el.Text = t.text
	end
	if string.find(t.text, "{%w+}") or (node.tags and node.tags.bind) then
		el:SetAttribute("FB_Template", t.text)
	end
	if t.stroke then makeStroke(t.stroke, el, true, op) end
end

-- Builds node as a child of parent. pw/ph = parent content size in design pixels.
function Builder:build(node, parent, pw, ph, inheritedOp, index, ctx)
	local tags = node.tags or {}
	if node.link and tags.link == nil then
		tags = table.clone(tags)
		tags.link = true -- so the runtime wires the button
	end
	local op = inheritedOp * (node.opacity or 1)
	local clickable = isClickable(node)
	local cls
	if node.type == "text" then
		cls = (tags.textbox or ctx.inTextbox) and "TextBox" or (clickable and "TextButton" or "TextLabel")
	elseif node.type == "image" or node.img then
		cls = clickable and "ImageButton" or "ImageLabel"
	elseif tags.scroll then
		cls = "ScrollingFrame"
	elseif clickable then
		cls = "TextButton"
	elseif tags.canvas or (node.clip and (node.radius or 0) > 0) then
		cls = "CanvasGroup"
	else
		cls = "Frame"
	end

	local el = Instance.new(cls)
	el.Name = node.name
	el.BorderSizePixel = 0
	el.AnchorPoint = Vector2.new(0.5, 0.5)
	el.Position = UDim2.fromScale(node.x / pw, node.y / ph)
	el.Size = UDim2.fromScale(node.w / pw, node.h / ph)
	el.Rotation = node.rot or 0
	el.Visible = node.visible ~= false
	el.ZIndex = index * 2
	el.LayoutOrder = index
	el.BackgroundTransparency = 1
	el:SetAttribute("FB_Id", node.id)
	if node.link then
		el:SetAttribute("FB_Link", node.link.action)
		if node.link.id then el:SetAttribute("FB_LinkId", node.link.id) end
		if node.link.name then el:SetAttribute("FB_LinkName", node.link.name) end
	end
	if next(tags) then
		el:SetAttribute("FB_Tags", tagString(tags))
		setDefaults(el, tags)
		-- values tuned in the Figma plugin's settings panel
		for tag, fields in node.settings or {} do
			for k, v in fields do
				if type(v) == "string" and string.match(v, "^#%x%x%x%x%x%x$") then v = Color3.fromHex(v) end
				if type(v) == "table" and v.img then
					-- an icon picked in Figma: attributes hold the uploaded asset id
					local info = self.images[v.img]
					if info and info.asset then
						v = "rbxassetid://" .. info.asset
					else
						self:warn(node.name .. ": " .. tag .. " icon was not uploaded; using the default shape")
						v = ""
					end
				end
				el:SetAttribute(tag .. "_" .. k, v)
			end
		end
	end
	if el:IsA("GuiButton") then
		el.AutoButtonColor = false
		if el:IsA("TextButton") and node.type ~= "text" then el.Text = "" end
	end

	if node.type == "text" then
		self:applyText(el, node, op)
	else
		if node.img then self:setImage(el, node.img, op) end
		local f = node.fill
		if f and f.kind == "solid" then
			el.BackgroundColor3 = c3(f.color)
			el.BackgroundTransparency = 1 - (f.a or 1) * op
		elseif f and f.kind == "gradient" and el:IsA("CanvasGroup") then
			-- a UIGradient on a CanvasGroup tints the whole group, so the gradient goes on a background layer
			local bg = Instance.new("Frame")
			bg.Name = "FB_FillBg"
			bg.BorderSizePixel = 0
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = Color3.new(1, 1, 1)
			bg.BackgroundTransparency = 1 - op
			bg.ZIndex = 0
			makeGradient(f, bg)
			bg.Parent = el
		elseif f and f.kind == "gradient" then
			el.BackgroundColor3 = Color3.new(1, 1, 1)
			el.BackgroundTransparency = 1 - op
			makeGradient(f, el)
		end
		if node.radius and node.radius > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, node.radius)
			c.Parent = el
		end
		if node.stroke then makeStroke(node.stroke, el, false, op) end
		if node.clip and not el:IsA("CanvasGroup") then el.ClipsDescendants = true end
	end

	if tags.aspect then
		local a = Instance.new("UIAspectRatioConstraint")
		a.AspectRatio = node.w / math.max(node.h, 0.01)
		a.Parent = el
	end

	-- _flow on a layer with children: a CanvasGroup lets one gradient tint the whole group
	local container = el
	if tags.flow and node.type ~= "text" and node.children and #node.children > 0 and not el:IsA("ScrollingFrame") then
		container = Instance.new("CanvasGroup")
		container.Name = "FB_FlowGroup"
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.Position = UDim2.fromScale(0.5, 0.5)
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.ZIndex = 1
		-- move the element's own paint inside the group so it is tinted too
		if el.BackgroundTransparency < 1 then
			local bg = Instance.new("Frame")
			bg.Name = "FB_FillBg"
			bg.BorderSizePixel = 0
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = el.BackgroundColor3
			bg.BackgroundTransparency = el.BackgroundTransparency
			bg.ZIndex = 0
			local g = el:FindFirstChildWhichIsA("UIGradient")
			if g then g.Parent = bg end
			bg.Parent = container
			el.BackgroundTransparency = 1
		end
		if el:IsA("ImageLabel") or el:IsA("ImageButton") then
			local fill = Instance.new("ImageLabel")
			fill.Name = "FB_Fill"
			fill.BackgroundTransparency = 1
			fill.Size = UDim2.fromScale(1, 1)
			fill.Image = el.Image
			pcall(function() fill.ImageContent = el.ImageContent end)
			fill.ImageTransparency = el.ImageTransparency
			fill.ScaleType = el.ScaleType
			fill.TileSize = el.TileSize
			fill.ZIndex = 1
			fill.Parent = container
			el.ImageTransparency = 1
		end
		if node.radius and node.radius > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, node.radius)
			c.Parent = container
		end
		container.Parent = el
	end

	-- children
	local cw, ch = node.w, node.h
	if node.children and #node.children > 0 then
		if el:IsA("ScrollingFrame") then
			local maxR, maxB = node.w, node.h
			for _, c in node.children do
				maxR = math.max(maxR, c.x + c.w / 2)
				maxB = math.max(maxB, c.y + c.h / 2)
			end
			cw, ch = maxR, maxB
			el.CanvasSize = UDim2.fromOffset(cw, ch)
			local dx, dy = cw > node.w + 1, ch > node.h + 1
			el.ScrollingDirection = (dx and dy and Enum.ScrollingDirection.XY) or (dx and Enum.ScrollingDirection.X) or Enum.ScrollingDirection.Y
			el.ScrollBarThickness = 6
			el.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
			el.BorderSizePixel = 0
			if not dx and not dy then self:warn(node.name .. ": _scroll content fits inside the window; nothing to scroll") end
		elseif tags.scroll then
			self:warn(node.name .. ": _scroll works on frames only")
		end
		local childCtx = { inTextbox = ctx.inTextbox or (tags.textbox and node.type ~= "text") }
		local layout = tags.list or tags.grid
		local built = {}
		for i, c in node.children do
			local child = self:build(c, container, cw, ch, op, i, childCtx, layout)
			built[i] = child
		end
		if tags.grid then
			if not self:applyGrid(node, container, built, cw, ch) then self:applyList(node, container, built, cw, ch) end
		elseif tags.list then
			self:applyList(node, container, built, cw, ch)
		end
	end

	-- shadow (sibling below the element; skipped inside layouts)
	local shadow = node.shadow
	if tags.shadow and not shadow then shadow = { color = { 0, 0, 0 }, a = 0.35, x = 0, y = 4, blur = 12, spread = 0 } end
	if shadow and not ctx.noShadow then
		self:makeShadow(node, el, shadow, parent, pw, ph, op)
	end

	el.Parent = parent
	return el
end

function Builder:makeShadow(node, el, s, parent, pw, ph, op)
	local layers = s.blur > 0 and 3 or 1
	for i = 1, layers do
		local grow = s.spread * 2 + (layers > 1 and s.blur * (i - 1) / (layers - 1) or 0)
		local f = Instance.new("Frame")
		f.Name = node.name .. "_Shadow"
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale((node.x + s.x) / pw, (node.y + s.y) / ph)
		f.Size = UDim2.fromScale((node.w + grow) / pw, (node.h + grow) / ph)
		f.Rotation = node.rot or 0
		f.Visible = el.Visible
		f.ZIndex = el.ZIndex - 1
		f.BackgroundColor3 = c3(s.color)
		f.BackgroundTransparency = 1 - (s.a * op) / layers * (layers > 1 and 1.4 or 1)
		f:SetAttribute("FB_ShadowFor", node.id)
		local r = (node.radius or 0) + grow / 2
		if r > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, r)
			c.Parent = f
		end
		f.Parent = parent
	end
end

local function edges(c) return c.x - c.w / 2, c.y - c.h / 2, c.x + c.w / 2, c.y + c.h / 2 end

function Builder:applyList(node, el, built, cw, ch)
	local items = {}
	for i, c in node.children do
		if built[i] then table.insert(items, { n = c, el = built[i] }) end
	end
	if #items < 2 then return false end
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, it in items do
		minX = math.min(minX, it.n.x); maxX = math.max(maxX, it.n.x)
		minY = math.min(minY, it.n.y); maxY = math.max(maxY, it.n.y)
	end
	local horizontal = (maxX - minX) > (maxY - minY)
	table.sort(items, function(a, b)
		if horizontal then return a.n.x < b.n.x end
		return a.n.y < b.n.y
	end)
	local gaps = {}
	for i = 2, #items do
		local _, _, r, b = edges(items[i - 1].n)
		local l, t = edges(items[i].n)
		table.insert(gaps, horizontal and (l - r) or (t - b))
	end
	local gmin, gmax, gsum = math.huge, -math.huge, 0
	for _, g in gaps do gmin = math.min(gmin, g); gmax = math.max(gmax, g); gsum += g end
	if gmax - gmin > 2 then
		self:warn(node.name .. ": _list gaps are uneven; original positions kept")
		return false
	end
	-- cross-axis alignment
	local function cross(it)
		local l, t, r, b = edges(it.n)
		if horizontal then return t, it.n.y, b end
		return l, it.n.x, r
	end
	local same = { true, true, true }
	local ref = { cross(items[1]) }
	for _, it in items do
		local v = { cross(it) }
		for k = 1, 3 do if math.abs(v[k] - ref[k]) > 1 then same[k] = false end end
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gsum / #gaps)
	local pad = Instance.new("UIPadding")
	local size = horizontal and ch or cw
	local first = { edges(items[1].n) }
	if horizontal then pad.PaddingLeft = UDim.new(0, first[1]) else pad.PaddingTop = UDim.new(0, first[2]) end
	local A = horizontal and Enum.VerticalAlignment or Enum.HorizontalAlignment
	local function setAlign(v)
		if horizontal then layout.VerticalAlignment = v else layout.HorizontalAlignment = v end
	end
	if same[2] then
		setAlign(horizontal and A.Center or A.Center)
		local c = ref[2]
		local before, after = math.max(0, 2 * c - size), math.max(0, size - 2 * c)
		if horizontal then pad.PaddingTop = UDim.new(0, before); pad.PaddingBottom = UDim.new(0, after)
		else pad.PaddingLeft = UDim.new(0, before); pad.PaddingRight = UDim.new(0, after) end
	elseif same[1] then
		setAlign(horizontal and A.Top or A.Left)
		if horizontal then pad.PaddingTop = UDim.new(0, ref[1]) else pad.PaddingLeft = UDim.new(0, ref[1]) end
	elseif same[3] then
		setAlign(horizontal and A.Bottom or A.Right)
		if horizontal then pad.PaddingBottom = UDim.new(0, size - ref[3]) else pad.PaddingRight = UDim.new(0, size - ref[3]) end
	else
		self:warn(node.name .. ": _list items are not aligned; original positions kept")
		return false
	end
	for i, it in items do
		it.el.LayoutOrder = i
		it.el.AnchorPoint = Vector2.zero
	end
	layout.Parent = el
	pad.Parent = el
	return true
end

function Builder:applyGrid(node, el, built, cw, ch)
	local items = {}
	for i, c in node.children do
		if built[i] then table.insert(items, { n = c, el = built[i] }) end
	end
	if #items < 2 then return false end
	local w, h = items[1].n.w, items[1].n.h
	for _, it in items do
		if math.abs(it.n.w - w) > 1 or math.abs(it.n.h - h) > 1 then
			self:warn(node.name .. ": _grid cells differ in size; trying _list")
			return false
		end
	end
	table.sort(items, function(a, b)
		if math.abs(a.n.y - b.n.y) > h / 2 then return a.n.y < b.n.y end
		return a.n.x < b.n.x
	end)
	local cols = 0
	for _, it in items do
		if math.abs(it.n.y - items[1].n.y) <= h / 2 then cols += 1 end
	end
	local gx, gy = 0, 0
	if cols > 1 then gx = items[2].n.x - items[1].n.x - w end
	if #items > cols then gy = items[cols + 1].n.y - items[1].n.y - h end
	-- verify every cell sits where a grid would put it
	local x0, y0 = items[1].n.x, items[1].n.y
	for i, it in items do
		local r, c = (i - 1) // cols, (i - 1) % cols
		if math.abs(it.n.x - (x0 + c * (w + gx))) > 3 or math.abs(it.n.y - (y0 + r * (h + gy))) > 3 then
			self:warn(node.name .. ": _grid is irregular; original positions kept")
			return false
		end
	end
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(w, h)
	g.CellPadding = UDim2.fromOffset(gx, gy)
	g.FillDirectionMaxCells = cols
	g.SortOrder = Enum.SortOrder.LayoutOrder
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, x0 - w / 2)
	pad.PaddingTop = UDim.new(0, y0 - h / 2)
	for i, it in items do
		it.el.LayoutOrder = i
		it.el.AnchorPoint = Vector2.zero
	end
	g.Parent = el
	pad.Parent = el
	return true
end

-- Shadows inside layout containers would be laid out as items; build() checks ctx.noShadow.
local origBuild = Builder.build
function Builder:build(node, parent, pw, ph, op, index, ctx, inLayout)
	if inLayout then
		ctx = { inTextbox = ctx.inTextbox, noShadow = true }
		if node.shadow or (node.tags and node.tags.shadow) then self:warn(node.name .. ": shadow skipped inside _list/_grid") end
	end
	return origBuild(self, node, parent, pw, ph, op, index, ctx)
end

function Builder:buildRoot()
	local doc = self.doc
	local rootNode = doc.root
	local tags = rootNode.tags or {}
	local gui
	local cam = workspace.CurrentCamera
	if tags.billboard or tags.surface or tags.prompt then
		local set = rootNode.settings or {}
		local studs = (tags.surface and ((set.surface or {}).Width or DEFAULTS.surface.Width))
			or ((set.billboard or {}).Width or DEFAULTS.billboard.Width)
		local part = Instance.new("Part")
		part.Name = rootNode.name .. "_UIPart"
		part:SetAttribute("FB_Part", true)
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(studs, studs * doc.h / doc.w, 0.2)
		local pos = cam.CFrame.Position + cam.CFrame.LookVector * 15
		part.CFrame = CFrame.lookAt(pos, cam.CFrame.Position)
		part.Parent = workspace
		if tags.billboard or tags.prompt then
			part.Transparency = 1
			gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(studs, studs * doc.h / doc.w)
			gui.LightInfluence = 0
			gui.MaxDistance = 100
			if tags.prompt then
				-- custom-styled prompt: Roblox handles range/input, the imported design is its look
				local p = (rootNode.settings or {}).prompt or {}
				local pp = Instance.new("ProximityPrompt")
				pp.Style = Enum.ProximityPromptStyle.Custom
				pp.MaxActivationDistance = p.Distance or DEFAULTS.prompt.Distance
				pp.HoldDuration = p.Hold or DEFAULTS.prompt.Hold
				pp.RequiresLineOfSight = false
				pp.ActionText = rootNode.name
				pp.Parent = part
				gui.AlwaysOnTop = true
			end
		else
			gui = Instance.new("SurfaceGui")
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(doc.w, doc.h)
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
		end
		gui.Adornee = part
	else
		gui = Instance.new("ScreenGui")
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		local refW, refH = doc.w, doc.h
		if doc.w < 1000 then refW, refH = 1920, 1080 end
		gui:SetAttribute("FB_RefW", refW)
		gui:SetAttribute("FB_RefH", refH)
	end
	gui.Name = rootNode.name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Transparent holder sized to the Figma frame; the design (and its outer stroke/shadow) sits inside.
	local root = Instance.new("Frame")
	root.Name = "FB_Holder"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(doc.w, doc.h)
	root:SetAttribute("FB_Root", true)
	self:build(rootNode, root, doc.w, doc.h, 1, 1, {})
	root:SetAttribute("FB_W", doc.w)
	root:SetAttribute("FB_H", doc.h)
	local scale = Instance.new("UIScale")
	scale.Name = "FB_Scale"
	if gui:IsA("ScreenGui") then
		local vp = cam.ViewportSize
		scale.Scale = math.min(vp.X / gui:GetAttribute("FB_RefW"), vp.Y / gui:GetAttribute("FB_RefH"))
	end
	scale.Parent = root
	root.Parent = gui

	local rt = Instance.new("LocalScript")
	rt.Name = "FigBridgeRuntime"
	rt.Source = RUNTIME_SOURCE
	rt.Parent = gui
	local cmd = Instance.new("BindableEvent")
	cmd.Name = "FB_Command"
	cmd.Parent = gui
	local panelEvent = Instance.new("BindableEvent")
	panelEvent.Name = "FB_PanelEvent"
	panelEvent.Parent = gui
	generateModule(gui)
	return gui
end

---------------------------------------------------------------- UI module
local KEYWORDS = {}
for _, k in { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not",
	"or", "repeat", "return", "then", "true", "until", "while", "continue", "type", "export" } do KEYWORDS[k] = true end

local function ident(name)
	local id = string.gsub(name, "[^%w_]", "")
	if id == "" or string.match(id, "^%d") then id = "_" .. id end
	if KEYWORDS[id] then id ..= "_" end
	return id
end

-- Writes a ModuleScript "UI" listing every element with its class, so scripts get autocomplete.
generateModule = function(gui)
	local used = { Open = true, Close = true, Toggle = true, All = true, Gui = true }
	local entries, panels = {}, {}
	local function walk(inst, path)
		for _, c in inst:GetChildren() do
			if not c:IsA("GuiObject") then continue end
			local p = table.clone(path)
			table.insert(p, c.Name)
			-- importer-made wrappers are walked through, its helper layers are skipped
			if c.Name == "FB_Holder" or c.Name == "FB_FlowGroup" then walk(c, p) continue end
			if c.Name == "FB_Fill" or c.Name == "FB_FillBg" or c:GetAttribute("FB_ShadowFor") then continue end
			local base = ident(c.Name)
			local id, n = base, 2
			while used[id] do id = base .. "_" .. n n += 1 end
			used[id] = true
			table.insert(entries, { id = id, path = p, class = c.ClassName, fid = c:GetAttribute("FB_Id") })
			local tags = c:GetAttribute("FB_Tags")
			if tags and string.find(" " .. tags .. " ", " panel ", 1, true) then table.insert(panels, c.Name) end
			walk(c, p)
		end
	end
	walk(gui, {})
	local out = {
		"-- Generated by FigBridge. Re-importing rewrites this file, so keep your code in your own scripts.",
		"-- From a LocalScript inside this ScreenGui:",
		"--   local UI = require(script.Parent:WaitForChild(\"UI\"))",
		entries[1] and ("--   UI." .. entries[#entries > 1 and 2 or 1].id .. " ...") or "",
		#panels > 0 and ("--   UI.Open(\"" .. panels[1] .. "\")  -- plays its entrance animation") or "",
		"local gui = script.Parent",
		"local command = gui:WaitForChild(\"FB_Command\") :: BindableEvent",
		"-- elements are found by their Figma id, so repeated names still resolve to the right layer",
		"local byId = {}",
		"for _, d in gui:GetDescendants() do",
		"\tlocal id = d:GetAttribute(\"FB_Id\")",
		"\tif id then byId[id] = d end",
		"end",
		"local function get(id: string): any return byId[id] end",
		"",
		"local UI = {}",
		"UI.Gui = gui",
	}
	for _, e in entries do
		table.insert(out, ("UI.%s = get(%q) :: %s -- %s"):format(e.id, tostring(e.fid), e.class, table.concat(e.path, "/")))
	end
	table.insert(out, "")
	table.insert(out, "-- Panels (layers tagged _panel): " .. (#panels > 0 and table.concat(panels, ", ") or "none"))
	table.insert(out, "function UI.Open(name: string) command:Fire(\"open\", name) end")
	table.insert(out, "function UI.Close(name: string) command:Fire(\"close\", name) end")
	table.insert(out, "function UI.Toggle(name: string) command:Fire(\"toggle\", name) end")
	table.insert(out, "-- small notification at the top of the screen")
	table.insert(out, "function UI.Toast(text: string, seconds: number?) command:Fire(\"toast\", text, seconds) end")
	table.insert(out, "local panelEvent = gui:WaitForChild(\"FB_PanelEvent\") :: BindableEvent")
	table.insert(out, "-- run fn every time the panel finishes opening / closing")
	table.insert(out, "function UI.OnOpen(name: string, fn: () -> ()) return panelEvent.Event:Connect(function(kind, n) if kind == \"opened\" and n == name then fn() end end) end")
	table.insert(out, "function UI.OnClose(name: string, fn: () -> ()) return panelEvent.Event:Connect(function(kind, n) if kind == \"closed\" and n == name then fn() end end) end")
	table.insert(out, "-- clone the layer named template once per item (it keeps its effects); the template itself is hidden")
	table.insert(out, "function UI.Fill(template: string, items: { any }, fill: (clone: GuiObject, item: any, index: number) -> ()): { GuiObject }")
	table.insert(out, "\tlocal base: GuiObject? = nil")
	table.insert(out, "\tfor _, d in gui:GetDescendants() do if d.Name == template and d:IsA(\"GuiObject\") and not d:GetAttribute(\"FB_Clone\") then base = d break end end")
	table.insert(out, "\tassert(base, \"UI.Fill: no layer named \" .. template)")
	table.insert(out, "\tfor _, d in base.Parent:GetChildren() do if d:GetAttribute(\"FB_Clone\") == template then d:Destroy() end end")
	table.insert(out, "\tbase.Visible = false")
	table.insert(out, "\tlocal clones = {}")
	table.insert(out, "\tfor i, item in items do")
	table.insert(out, "\t\tlocal c = base:Clone()")
	table.insert(out, "\t\tc:SetAttribute(\"FB_Clone\", template)")
	table.insert(out, "\t\tc.Visible = true")
	table.insert(out, "\t\tc.LayoutOrder = (base.LayoutOrder or 0) + i")
	table.insert(out, "\t\tfill(c, item, i)")
	table.insert(out, "\t\tc.Parent = base.Parent")
	table.insert(out, "\t\tcommand:Fire(\"setup\", c)")
	table.insert(out, "\t\ttable.insert(clones, c)")
	table.insert(out, "\tend")
	table.insert(out, "\treturn clones")
	table.insert(out, "end")
	table.insert(out, "-- every element with this name (for repeated names such as list items)")
	table.insert(out, "function UI.All(name: string): { GuiObject }")
	table.insert(out, "\tlocal list = {}")
	table.insert(out, "\tfor _, d in gui:GetDescendants() do if d.Name == name and d:IsA(\"GuiObject\") then table.insert(list, d) end end")
	table.insert(out, "\treturn list")
	table.insert(out, "end")
	table.insert(out, "")
	table.insert(out, "return UI")
	local m = Instance.new("ModuleScript")
	m.Name = "UI"
	m:SetAttribute("FB_Generated", true)
	m.Source = table.concat(out, "\n")
	m.Parent = gui
	return #entries
end

---------------------------------------------------------------- images
local function loadImages(server, code, list, upload, status, warnings)
	local cache = plugin:GetSetting("FB_AssetCache") or {}
	local out = {}
	local decalCache = plugin:GetSetting("FB_DecalImage") or {}
	local InsertService = game:GetService("InsertService")
	-- Open Cloud gives a Decal id; ImageLabels need the Image id inside it.
	local function imageFromDecal(decal)
		if decalCache[decal] then return decalCache[decal] end
		for attempt = 1, 6 do
			local ok, model = pcall(InsertService.LoadAsset, InsertService, tonumber(decal))
			if ok and model then
				local d = model:FindFirstChildWhichIsA("Decal", true)
				local id = d and string.match(d.Texture, "%d+$")
				model:Destroy()
				if id then
					decalCache[decal] = id
					plugin:SetSetting("FB_DecalImage", decalCache)
					return id
				end
			end
			task.wait(attempt)
		end
		return nil
	end
	for i, im in list do
		status(("Images %d/%d…"):format(i, #list))
		if im.decal then
			local imageId = imageFromDecal(im.decal)
			if imageId then
				out[im.id] = { asset = imageId }
				continue
			end
			table.insert(warnings, "Decal " .. im.decal .. " uploaded but its image id could not be read yet (moderation?); using a temporary preview")
		elseif im.uploadError then
			table.insert(warnings, "Server upload failed: " .. im.uploadError)
		end
		if upload and cache[im.id] then
			out[im.id] = { asset = cache[im.id] }
			continue
		end
		local data = getJSON(server .. "/api/c/" .. code .. "/img/" .. im.id)
		local buf = b64decode(data.data)
		local size = Vector2.new(data.w, data.h)
		local ok, ei = pcall(function()
			local e = AssetService:CreateEditableImage({ Size = size })
			e:WritePixelsBuffer(Vector2.zero, size, buf)
			return e
		end)
		if not ok then
			table.insert(warnings, "Image " .. im.id .. " could not be created: " .. tostring(ei))
			continue
		end
		if upload then
			local ok2, result, assetId = pcall(function()
				return AssetService:CreateAssetAsync(ei, Enum.AssetType.Image, {
					Name = "FigBridge " .. string.sub(im.id, 1, 8),
					Description = "Uploaded by FigBridge",
				})
			end)
			if ok2 and result == Enum.CreateAssetResult.Success and assetId then
				cache[im.id] = assetId
				out[im.id] = { asset = assetId }
				ei:Destroy()
			else
				out[im.id] = { editable = ei }
				table.insert(warnings, "Upload failed (" .. tostring(ok2 and result or result) .. "); image " .. string.sub(im.id, 1, 8) .. " is a temporary preview and will not be saved")
			end
		else
			out[im.id] = { editable = ei }
		end
	end
	plugin:SetSetting("FB_AssetCache", cache)
	return out
end

---------------------------------------------------------------- UI
local TweenService = game:GetService("TweenService")
local toolbar = plugin:CreateToolbar("FigBridge")
local toggleBtn = toolbar:CreateButton("FigBridge", "Import a Figma design by code", "rbxasset://textures/ui/GuiImagePlaceholder.png")
toggleBtn.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui("FigBridge",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 320, 400, 280, 340))
widget.Title = "FigBridge"
toggleBtn.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() toggleBtn:SetActive(widget.Enabled) end)

-- Palette follows Studio's light/dark theme
local dark = settings().Studio.Theme.Name ~= "Light"
local C = dark and {
	bg = Color3.fromRGB(28, 28, 30), card = Color3.fromRGB(44, 44, 46), fill = Color3.fromRGB(58, 58, 60),
	label = Color3.fromRGB(245, 245, 247), label2 = Color3.fromRGB(152, 152, 159),
	accent = Color3.fromRGB(10, 132, 255), green = Color3.fromRGB(48, 209, 88), red = Color3.fromRGB(255, 69, 58),
} or {
	bg = Color3.fromRGB(242, 242, 247), card = Color3.fromRGB(255, 255, 255), fill = Color3.fromRGB(229, 229, 234),
	label = Color3.fromRGB(29, 29, 31), label2 = Color3.fromRGB(110, 110, 115),
	accent = Color3.fromRGB(0, 122, 255), green = Color3.fromRGB(52, 199, 89), red = Color3.fromRGB(255, 59, 48),
}
local SANS = "rbxasset://fonts/families/BuilderSans.json"
local function font(weight) return Font.new(SANS, weight or Enum.FontWeight.Regular) end
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local SPRING = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end
local function padding(inst, x, y)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, x), UDim.new(0, x)
	p.PaddingTop, p.PaddingBottom = UDim.new(0, y), UDim.new(0, y)
	p.Parent = inst
end
local function vlist(inst, gap)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = inst
	return l
end
local function text(parent, str, size, color, weight, order)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font(weight)
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1, 0, 0, 0)
	l.Text = str
	l.LayoutOrder = order or 0
	l.Parent = parent
	return l
end
-- Press feedback starts on pointer-down and springs back on release
local function pressable(btn, scaleTo)
	local s = Instance.new("UIScale")
	s.Parent = btn
	btn.MouseButton1Down:Connect(function() TweenService:Create(s, FAST, { Scale = scaleTo or 0.97 }):Play() end)
	local function up() TweenService:Create(s, SPRING, { Scale = 1 }):Play() end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
end

local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.ScrollBarThickness = 4
root.ScrollBarImageColor3 = C.label2
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.Parent = widget
padding(root, 14, 14)
vlist(root, 12)

local head = Instance.new("Frame")
head.BackgroundTransparency = 1
head.Size = UDim2.new(1, 0, 0, 0)
head.AutomaticSize = Enum.AutomaticSize.Y
head.LayoutOrder = 1
head.Parent = root
vlist(head, 2)
text(head, "FigBridge", 22, C.label, Enum.FontWeight.Bold, 1)
text(head, "Paste the code from the Figma plugin.", 14, C.label2, Enum.FontWeight.Regular, 2)

-- code card
local card = Instance.new("Frame")
card.BackgroundColor3 = C.card
card.Size = UDim2.new(1, 0, 0, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.LayoutOrder = 2
card.Parent = root
corner(card, 12)
padding(card, 12, 12)
vlist(card, 10)

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.new(1, 0, 0, 52)
codeBox.BackgroundColor3 = C.fill
codeBox.FontFace = MONO
codeBox.TextSize = 28
codeBox.TextColor3 = C.label
codeBox.PlaceholderColor3 = C.label2
codeBox.PlaceholderText = "K7P2QX"
codeBox.Text = ""
codeBox.ClearTextOnFocus = false
codeBox.LayoutOrder = 1
codeBox.Parent = card
corner(codeBox, 10)
local focusRing = Instance.new("UIStroke")
focusRing.Color = C.accent
focusRing.Thickness = 2
focusRing.Transparency = 1
focusRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
focusRing.Parent = codeBox
codeBox.Focused:Connect(function() TweenService:Create(focusRing, FAST, { Transparency = 0.3 }):Play() end)
codeBox.FocusLost:Connect(function() TweenService:Create(focusRing, FAST, { Transparency = 1 }):Play() end)
codeBox:GetPropertyChangedSignal("Text"):Connect(function()
	local clean = string.sub((codeBox.Text:upper():gsub("[^%w]", "")), 1, 6)
	if clean ~= codeBox.Text then codeBox.Text = clean end
end)

-- upload switch row
local row = Instance.new("TextButton")
row.Text = ""
row.AutoButtonColor = false
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, 0, 0, 30)
row.LayoutOrder = 2
row.Parent = card
local rowLabel = text(row, "Upload images to my account", 14, C.label, Enum.FontWeight.Medium)
rowLabel.AutomaticSize = Enum.AutomaticSize.None
rowLabel.Size = UDim2.new(1, -56, 1, 0)
rowLabel.TextYAlignment = Enum.TextYAlignment.Center
local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(1, 0.5)
track.Position = UDim2.fromScale(1, 0.5)
track.Size = UDim2.fromOffset(44, 26)
track.Parent = row
corner(track, 13)
local knob = Instance.new("Frame")
knob.AnchorPoint = Vector2.new(0, 0.5)
knob.Size = UDim2.fromOffset(22, 22)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.Parent = track
corner(knob, 11)

local liveRow = row:Clone()
liveRow.LayoutOrder = 2
liveRow.Parent = card
liveRow:FindFirstChildWhichIsA("TextLabel").Text = "Live sync from Figma"
local liveTrack = liveRow:FindFirstChildWhichIsA("Frame")
local liveKnob = liveTrack:FindFirstChildWhichIsA("Frame")
row.LayoutOrder = 2

local importBtn = Instance.new("TextButton")
importBtn.Size = UDim2.new(1, 0, 0, 44)
importBtn.BackgroundColor3 = C.accent
importBtn.AutoButtonColor = false
importBtn.FontFace = font(Enum.FontWeight.SemiBold)
importBtn.TextSize = 16
importBtn.TextColor3 = Color3.new(1, 1, 1)
importBtn.Text = "Import"
importBtn.LayoutOrder = 4
importBtn.Parent = card
corner(importBtn, 12)
pressable(importBtn)

-- placement: where the imported UI sits on screen, with a mini screen preview
local PLACES = {
	{ "TopLeft", 0, 0 }, { "Top", 0.5, 0 }, { "TopRight", 1, 0 },
	{ "Left", 0, 0.5 }, { "Center", 0.5, 0.5 }, { "Right", 1, 0.5 },
	{ "BottomLeft", 0, 1 }, { "Bottom", 0.5, 1 }, { "BottomRight", 1, 1 },
}
local function placeOf(name)
	for _, pl in PLACES do if pl[1] == name then return pl end end
	return PLACES[5]
end
local place = plugin:GetSetting("FB_Place") or "Center"
local startHidden = plugin:GetSetting("FB_StartHidden") == true

local placeCard = Instance.new("Frame")
placeCard.BackgroundColor3 = C.card
placeCard.Size = UDim2.new(1, 0, 0, 0)
placeCard.AutomaticSize = Enum.AutomaticSize.Y
placeCard.LayoutOrder = 3
placeCard.Parent = root
corner(placeCard, 12)
padding(placeCard, 12, 10)
vlist(placeCard, 8)
local placeLabel = text(placeCard, "PLACEMENT · Center", 11, C.label2, Enum.FontWeight.SemiBold, 1)
local screen = Instance.new("Frame")
screen.Size = UDim2.new(1, 0, 0, 96)
screen.BackgroundColor3 = C.fill
screen.LayoutOrder = 2
screen.ClipsDescendants = true
screen.Parent = placeCard
corner(screen, 8)
local marker = Instance.new("Frame")
marker.Size = UDim2.fromScale(0.34, 0.34)
marker.BackgroundColor3 = C.accent
marker.Parent = screen
corner(marker, 5)
local function markerPos(pl)
	local mx = pl[2] == 0 and 6 or (pl[2] == 1 and -6 or 0)
	local my = pl[3] == 0 and 6 or (pl[3] == 1 and -6 or 0)
	return Vector2.new(pl[2], pl[3]), UDim2.new(pl[2], mx, pl[3], my)
end
local function renderPlace(animate)
	local pl = placeOf(place)
	local ap, pos = markerPos(pl)
	marker.AnchorPoint = ap
	if animate then TweenService:Create(marker, SPRING, { Position = pos }):Play() else marker.Position = pos end
	placeLabel.Text = "PLACEMENT · " .. pl[1]:gsub("(%l)(%u)", "%1 %2")
end
for i, pl in PLACES do
	local cell = Instance.new("TextButton")
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromScale(1 / 3, 1 / 3)
	cell.Position = UDim2.fromScale(((i - 1) % 3) / 3, ((i - 1) // 3) / 3)
	cell.ZIndex = 2
	cell.Parent = screen
	cell.MouseButton1Click:Connect(function()
		place = pl[1]
		plugin:SetSetting("FB_Place", place)
		renderPlace(true)
	end)
end
renderPlace(false)

local hideRow = row:Clone()
hideRow.LayoutOrder = 3
hideRow.Parent = placeCard
hideRow:FindFirstChildWhichIsA("TextLabel").Text = "Start hidden (open it from a button or script)"
local hideTrack = hideRow:FindFirstChildWhichIsA("Frame")
local hideKnob = hideTrack:FindFirstChildWhichIsA("Frame")
local function renderHidden(animate)
	local info = animate and SPRING or TweenInfo.new(0)
	TweenService:Create(hideTrack, info, { BackgroundColor3 = startHidden and C.green or C.fill }):Play()
	TweenService:Create(hideKnob, info, { Position = startHidden and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }):Play()
end
renderHidden(false)
hideRow.MouseButton1Click:Connect(function()
	startHidden = not startHidden
	plugin:SetSetting("FB_StartHidden", startHidden)
	renderHidden(true)
end)

-- status line with a colored dot
local statusRow = Instance.new("Frame")
statusRow.BackgroundTransparency = 1
statusRow.Size = UDim2.new(1, 0, 0, 0)
statusRow.AutomaticSize = Enum.AutomaticSize.Y
statusRow.LayoutOrder = 4
statusRow.Parent = root
local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(8, 8)
dot.Position = UDim2.fromOffset(2, 6)
dot.BackgroundColor3 = C.label2
dot.Parent = statusRow
corner(dot, 4)
local status = text(statusRow, "Ready.", 14, C.label2)
status.Size = UDim2.new(1, -18, 0, 0)
status.Position = UDim2.fromOffset(18, 0)

-- server (secondary, below)
local serverCard = Instance.new("Frame")
serverCard.BackgroundColor3 = C.card
serverCard.Size = UDim2.new(1, 0, 0, 0)
serverCard.AutomaticSize = Enum.AutomaticSize.Y
serverCard.LayoutOrder = 5
serverCard.Parent = root
corner(serverCard, 12)
padding(serverCard, 12, 10)
vlist(serverCard, 6)
text(serverCard, "SERVER", 11, C.label2, Enum.FontWeight.SemiBold, 1)
local serverBox = Instance.new("TextBox")
serverBox.Size = UDim2.new(1, 0, 0, 30)
serverBox.BackgroundColor3 = C.fill
serverBox.FontFace = font()
serverBox.TextSize = 14
serverBox.TextColor3 = C.label
serverBox.TextXAlignment = Enum.TextXAlignment.Left
serverBox.ClearTextOnFocus = false
serverBox.Text = plugin:GetSetting("FB_Server") or "http://localhost:7777"
serverBox.LayoutOrder = 2
serverBox.Parent = serverCard
corner(serverBox, 8)
padding(serverBox, 8, 0)

local uploadImages = plugin:GetSetting("FB_Upload")
if uploadImages == nil then uploadImages = true end
local function renderToggle(animate)
	local info = animate and SPRING or TweenInfo.new(0)
	TweenService:Create(track, info, { BackgroundColor3 = uploadImages and C.green or C.fill }):Play()
	TweenService:Create(knob, info, { Position = uploadImages and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }):Play()
end
renderToggle(false)
row.MouseButton1Click:Connect(function()
	uploadImages = not uploadImages
	plugin:SetSetting("FB_Upload", uploadImages)
	renderToggle(true)
end)
serverBox.FocusLost:Connect(function()
	plugin:SetSetting("FB_Server", (serverBox.Text:gsub("/+$", "")))
end)

local RunService = game:GetService("RunService")
local liveOn = false
local liveCode, liveVersion = nil, 0

-- move user scripts from the old import to the same place in the new one
local function carryScripts(old, new)
	local scripts = {}
	for _, d in old:GetDescendants() do
		if d:IsA("LuaSourceContainer") and d.Name ~= "FigBridgeRuntime" and not d:GetAttribute("FB_Generated")
			and not d.Parent:IsA("LuaSourceContainer") then
			table.insert(scripts, d)
		end
	end
	for _, sc in scripts do
		local path, p = {}, sc.Parent
		while p and p ~= old do table.insert(path, 1, p.Name) p = p.Parent end
		local target = new
		for _, name in path do
			local n = target:FindFirstChild(name)
			if not n then target = new break end
			target = n
		end
		sc.Parent = target
	end
	return #scripts
end
local function findImport(code, source)
	for _, g in StarterGui:GetChildren() do
		if g:GetAttribute("FB_Code") == code then return g end
	end
	if source then
		for _, g in StarterGui:GetChildren() do
			if g:GetAttribute("FB_Source") == source then return g end
		end
	end
	return nil
end

local busy = false
local function setStatus(t, kind)
	status.Text = t
	local c = (kind == "ok" and C.green) or (kind == "err" and C.red) or (kind == "busy" and C.accent) or C.label2
	TweenService:Create(dot, FAST, { BackgroundColor3 = c }):Play()
	status.TextColor3 = (kind == "err" and C.red) or (kind == "ok" and C.label) or C.label2
end

local function import(fromLive)
	if busy then return end
	local code = codeBox.Text:upper():gsub("%s", "")
	if fromLive then code = liveCode end
	if #code ~= 6 then setStatus("The code has 6 characters.", "err"); return end
	local server = serverBox.Text:gsub("/+$", "")
	busy = true
	importBtn.Text = "Importing…"
	TweenService:Create(importBtn, FAST, { BackgroundTransparency = 0.35 }):Play()
	local ok, err = pcall(function()
		setStatus("Downloading " .. code .. "…", "busy")
		local data = getJSON(server .. "/api/c/" .. code)
		local warnings = table.clone(data.doc.warnings or {})
		local images = loadImages(server, code, data.images or {}, uploadImages, function(t) setStatus(t, "busy") end, warnings)
		setStatus("Building UI…", "busy")
		local recording = ChangeHistoryService:TryBeginRecording("FigBridge import")
		local builder = Builder.new(data.doc, images)
		local gui = builder:buildRoot()
		gui:SetAttribute("FB_Code", code)
		local holder = gui:FindFirstChild("FB_Holder")
		if holder and gui:IsA("ScreenGui") then
			local pl = placeOf(place)
			holder.AnchorPoint = Vector2.new(pl[2], pl[3])
			holder.Position = UDim2.new(pl[2], pl[2] == 0 and 16 or (pl[2] == 1 and -16 or 0), pl[3], pl[3] == 0 and 16 or (pl[3] == 1 and -16 or 0))
			gui:SetAttribute("FB_Place", pl[1])
		end
		gui:SetAttribute("FB_StartHidden", (startHidden or data.doc.startHidden) or nil)
		local source = data.doc.root and data.doc.root.id
		if source then gui:SetAttribute("FB_Source", source) end
		local old = findImport(code, source)
		local kept = 0
		if old then
			-- same design imported before: swap it in place
			kept = carryScripts(old, gui)
			if old:IsA("LayerCollector") and gui:IsA("LayerCollector") then gui.Enabled = old.Enabled end
			local oldPart = (old:IsA("BillboardGui") or old:IsA("SurfaceGui")) and old.Adornee
			local newPart = (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) and gui.Adornee
			if oldPart and oldPart:GetAttribute("FB_Part") then
				if newPart then newPart.CFrame = oldPart.CFrame end
				oldPart:Destroy()
			end
			old:Destroy()
		end
		gui.Parent = StarterGui
		liveVersion = data.version or liveVersion
		if not old then
			-- first import: a starter script showing how to use the UI module (all examples commented out)
			local firstButton, firstPanel
			for _, d in gui:GetDescendants() do
				if not firstButton and d:IsA("GuiButton") then firstButton = d end
				local tg = d:GetAttribute("FB_Tags")
				if not firstPanel and tg and string.find(" " .. tg .. " ", " panel ", 1, true) then firstPanel = d end
			end
			local ex = Instance.new("LocalScript")
			ex.Name = "MyUI"
			ex.Source = table.concat({
				"-- Your code for this UI. FigBridge keeps this script when you re-import.",
				"local UI = require(script.Parent:WaitForChild(\"UI\"))",
				"",
				firstButton and ("-- UI." .. ident(firstButton.Name) .. ".Activated:Connect(function()") or "-- UI.MyButton.Activated:Connect(function()",
				firstPanel and ("--\tUI.Open(\"" .. firstPanel.Name .. "\")") or "--\tUI.Toast(\"Hello!\")",
				"-- end)",
				"",
				"-- UI.Toast(\"+100 coins\")",
				firstPanel and ("-- UI.OnOpen(\"" .. firstPanel.Name .. "\", function() print(\"opened\") end)") or "",
				"-- UI.Fill(\"ItemCard\", { \"Sword\", \"Shield\" }, function(card, item) card.Title.Text = item end)",
			}, "\n")
			ex.Parent = gui
		end
		if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
		if not fromLive then Selection:Set({ gui }) end
		for _, w in builder.warnings do table.insert(warnings, w) end
		for _, w in warnings do warn("[FigBridge] " .. w) end
		if fromLive then
			setStatus(("Live · synced “%s” at %s%s"):format(gui.Name, os.date("%H:%M:%S"),
				kept > 0 and (" · kept " .. kept .. " script(s)") or ""), "ok")
		else
			setStatus(("%s “%s” in StarterGui.%s%s Script it with the UI module. Press Play to try the animations."):format(
				old and "Updated" or "Imported", gui.Name, kept > 0 and (" Kept " .. kept .. " script(s).") or "",
				#warnings > 0 and (" " .. #warnings .. " note(s) in Output.") or ""), "ok")
		end
	end)
	if not ok then setStatus(tostring(err), "err") end
	busy = false
	importBtn.Text = "Import"
	TweenService:Create(importBtn, FAST, { BackgroundTransparency = 0 }):Play()
end
local function renderLive(animate)
	local info = animate and SPRING or TweenInfo.new(0)
	TweenService:Create(liveTrack, info, { BackgroundColor3 = liveOn and C.green or C.fill }):Play()
	TweenService:Create(liveKnob, info, { Position = liveOn and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }):Play()
end
renderLive(false)
liveRow.MouseButton1Click:Connect(function()
	liveOn = not liveOn
	renderLive(true)
	if liveOn then
		local code = codeBox.Text:upper():gsub("%s", "")
		if #code ~= 6 then liveOn = false renderLive(true) setStatus("Paste the live code from Figma first.", "err") return end
		liveCode, liveVersion = code, 0
		setStatus("Live · connecting to " .. code .. "…", "busy")
	else
		setStatus("Live sync off.")
	end
end)
-- poll the server for a newer version and re-import it (edit mode only)
task.spawn(function()
	while true do
		task.wait(1.5)
		if liveOn and liveCode and not busy and not RunService:IsRunning() then
			local server = serverBox.Text:gsub("/+$", "")
			local ok, res = pcall(function()
				return HttpService:JSONDecode(HttpService:GetAsync(server .. "/api/v/" .. liveCode, true))
			end)
			if ok and res and (res.version or 0) > liveVersion then
				import(true)
			elseif not ok and string.find(tostring(res), "404") then
				setStatus("Live · code " .. liveCode .. " not found. Turn Live sync on in Figma.", "err")
			end
		end
	end
end)

importBtn.MouseButton1Click:Connect(function() task.spawn(import) end)
codeBox.FocusLost:Connect(function(enter) if enter then task.spawn(import) end end)
