--!nocheck
-- FigmaToRoblox — Roblox Studio side. Downloads a design by code and rebuilds it as native UI.
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StarterGui = game:GetService("StarterGui")
local Selection = game:GetService("Selection")

local RUNTIME_SOURCE = [==[--!nocheck
-- FigmaToRoblox runtime: wires buttons, panels, tabs, live data and animations for an imported design.
-- Settings live as attributes named "<tag>_<Setting>" on each tagged instance.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local DEFAULTS = (function()
-- Default settings per tag. The importer writes them as attributes named "<tag>_<Setting>"
-- on each tagged instance, so they can be tuned in Studio's Properties panel.
return {
	button = { Darken = 0.12, Time = 0.12 },
	grow = { Scale = 1.1, Time = 0.2, Style = "Smooth" },
	press = { Scale = 0.92, Time = 0.1, Style = "Bouncy" },
	sound = { Hover = "", Click = "", Volume = 0.5 },
	popout = { To = 0.6, Time = 0.22 },
	fadeout = { Time = 0.25 },
	dropout = { Distance = 60, Time = 0.3 },
	smooth = { HoverScale = 1.1, PressScale = 0.94, Time = 0.15, HoverSound = "", ClickSound = "" },
	up = { Lift = 6, Time = 0.15, Style = "Smooth" },
	turn = { Angle = 6, Time = 0.15 },
	squish = { Squash = 0.85, Time = 0.35 },
	ripple = { Color = Color3.new(1, 1, 1), Opacity = 0.35, Time = 0.5 },
	burst = { Count = 10, Distance = 70, Size = 8, Life = 0.55, Spin = 180, Color = Color3.fromRGB(255, 230, 120), Shape = "Circle", Icon = "" },
	magnet = { Strength = 0.25, Radius = 120 },
	select = { Color = Color3.fromRGB(255, 215, 0), Thickness = 3 },
	lean = { Angle = 12, Time = 0.15 },
	color = { HoverColor = Color3.fromRGB(255, 220, 120), Time = 0.15 },
	glint = { Time = 0.5 },
	card = { Delay = 0.15, Time = 0.15 },
	pop = { From = 0.6, Time = 0.45, Delay = 0, Style = "Bouncy" },
	fadein = { Time = 0.4, Delay = 0 },
	drop = { Height = 80, Time = 0.7, Delay = 0 },
	swing = { Angle = 14, Time = 1, Delay = 0 },
	cascade = { Step = 0.07, Time = 0.3, Distance = 12 },
	spin = { Speed = 90 },
	rays = { Speed = 20, Pulse = 0.05, Rate = 0.5 },
	pulse = { Amount = 0.06, Rate = 1.2 },
	float = { Distance = 6, Rate = 0.5, Angle = 0 },
	jelly = { Amount = 0.04, Rate = 1 },
	blink = { On = 1, Off = 0.5, Fade = 0.2, Delay = 0 },
	shake = { Distance = 4, Duration = 0.4, Every = 3 },
	wiggle = { Angle = 8, Duration = 0.5, Every = 3 },
	glow = { Color = Color3.fromRGB(255, 255, 255), Size = 14, Rate = 1 },
	reveal = { Angle = 10, From = 0.85, Time = 0.8, Delay = 0 },
	tilt3d = { Strength = 14, Depth = 0.25 },
	tilt = { X = 0, Y = 20 },
	pointer = { Time = 0.25, Hide = 0.4 },
	pixels = { Size = 8, Rate = 8, Color = Color3.new(1, 1, 1), Opacity = 0.35 },
	fall = { Count = 8, Speed = 60, MinSize = 0.5, MaxSize = 1 },
	drift = { SpeedX = 20, SpeedY = 0 },
	prompt = { Distance = 10, Hold = 0 },
	hold = { Color = Color3.new(1, 1, 1) },
	type = { Speed = 30, Delay = 0, Loop = false, Pause = 1.5 },
	sparkle = { Count = 6, MinSize = 8, MaxSize = 16, Life = 1.2, Spin = 90, Rise = 0, Color = Color3.new(1, 1, 1), Shape = "Star", Icon = "", Trigger = "Always" },
	shiny = { Time = 0.8, Pause = 1.5 },
	beam = { Speed = 60 },
	gleam = { Time = 0.8, Pause = 1.5, Color = Color3.new(1, 1, 1) },
	stroke = { Speed = 90, Mode = "Rotate" },
	flow = { Speed = 60, Mode = "Rotate", Bands = 2, Rainbow = false },
	bar = { Max = 100, MaxPath = "", Direction = "Right", Time = 0.3 },
	buy = { Type = "Product" },
	focus = { Blur = 12 },
	billboard = { Width = 6 },
	surface = { Width = 6 },
}

end)()

local gui = script.Parent
local player = Players.LocalPlayer

local root
for _, c in gui:GetChildren() do
	if c:IsA("GuiObject") and c:GetAttribute("FB_Root") then root = c end
end
if not root then return end

---------------------------------------------------------------- basics
local TAGS = {} -- instance -> { tag = true | "arg" }
local function parseTags(s)
	local t = {}
	for tok in string.gmatch(s, "%S+") do
		local k, a = string.match(tok, "^([^:]+):(.+)$")
		if k then t[k] = a else t[tok] = true end
	end
	return t
end
local function P(el, tag, key)
	local v = el:GetAttribute(tag .. "_" .. key)
	if v == nil then
		local d = DEFAULTS[tag]
		v = d and d[key]
	end
	return v
end
local function ancestorWith(el, tag, includeSelf)
	local p = includeSelf and el or el.Parent
	while p and p ~= gui do
		local t = TAGS[p]
		if t and t[tag] ~= nil then return p end
		p = p.Parent
	end
	return nil
end
local function buttonOf(el)
	local p = el
	while p and p ~= gui do
		if p:IsA("GuiButton") then return p end
		p = p.Parent
	end
	return nil
end

-- root scaling: fit the design to the screen / surface
local rootScale = root:FindFirstChild("FB_Scale")
local designW, designH = root:GetAttribute("FB_W"), root:GetAttribute("FB_H")
local function scaleNow() return rootScale and rootScale.Scale or 1 end
local function fit()
	if not rootScale then return end
	local abs = gui.AbsoluteSize
	if gui:IsA("ScreenGui") then
		if abs.X < 2 then abs = workspace.CurrentCamera.ViewportSize end
		local rw = gui:GetAttribute("FB_RefW") or designW
		local rh = gui:GetAttribute("FB_RefH") or designH
		rootScale.Scale = math.min(abs.X / rw, abs.Y / rh)
	elseif abs.X > 0 then
		rootScale.Scale = math.min(abs.X / designW, abs.Y / designH)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

---------------------------------------------------------------- animation channels
-- Every effect writes into a named slot of a channel; the final value combines all slots, so
-- effects stack (a _pulse on a _smooth button, a _float with a _pop entrance…).
local states = {}
local dirty = {}

local function transparencyProps(o)
	local p = {}
	if o:IsA("GuiObject") then p.BackgroundTransparency = o.BackgroundTransparency end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then p.TextTransparency = o.TextTransparency end
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then p.ImageTransparency = o.ImageTransparency end
	if o:IsA("ScrollingFrame") then p.ScrollBarImageTransparency = o.ScrollBarImageTransparency end
	if o:IsA("UIStroke") then p.Transparency = o.Transparency end
	return p
end

local function S(el)
	local st = states[el]
	if st then return st end
	st = { el = el, pos = el.Position, size = el.Size, rot = el.Rotation,
		s = {}, sx = {}, sy = {}, x = {}, y = {}, r = {}, a = {}, followers = {}, lastA = 1 }
	local id = el:GetAttribute("FB_Id")
	if id and el.Parent then
		for _, sib in el.Parent:GetChildren() do
			if sib ~= el and sib:GetAttribute("FB_ShadowFor") == id then
				table.insert(st.followers, { el = sib, pos = sib.Position, size = sib.Size, rot = sib.Rotation })
			end
		end
	end
	states[el] = st
	return st
end

local function prod(t) local v = 1 for _, x in t do v *= x end return v end
local function sum(t) local v = 0 for _, x in t do v += x end return v end

local function setAlpha(st, a)
	st.lastA = a
	if st.el:IsA("CanvasGroup") then st.el.GroupTransparency = 1 - a return end
	if not st.alphaBase then
		st.alphaBase = {}
		local objs = st.el:GetDescendants()
		table.insert(objs, st.el)
		for _, f in st.followers do table.insert(objs, f.el) end
		for _, o in objs do
			local p = transparencyProps(o)
			if next(p) then st.alphaBase[o] = p end
		end
	end
	for o, props in st.alphaBase do
		if o.Parent then
			for k, b in props do o[k] = 1 - (1 - b) * a end
		end
	end
end

local function applyState(st)
	local s = prod(st.s)
	if s ~= 1 or st.us then
		if not st.us then
			st.us = Instance.new("UIScale")
			st.us.Name = "FB_AnimScale"
			st.us.Parent = st.el
			for _, f in st.followers do
				f.us = Instance.new("UIScale")
				f.us.Parent = f.el
			end
		end
		st.us.Scale = s
		for _, f in st.followers do f.us.Scale = s end
	end
	local ox, oy, r = sum(st.x), sum(st.y), sum(st.r)
	local sx, sy = prod(st.sx), prod(st.sy)
	local function put(o, base)
		o.Position = base.pos + UDim2.fromOffset(ox, oy)
		o.Rotation = base.rot + r
		if sx ~= 1 or sy ~= 1 or base.sized then
			base.sized = true
			o.Size = UDim2.new(base.size.X.Scale * sx, base.size.X.Offset * sx, base.size.Y.Scale * sy, base.size.Y.Offset * sy)
		end
	end
	put(st.el, st)
	for _, f in st.followers do put(f.el, f) end
	local a = prod(st.a)
	if math.abs(a - st.lastA) > 1e-4 then setAlpha(st, a) end
end

local function setCh(st, ch, key, v)
	st[ch][key] = v
	dirty[st] = true
end

local tweens = {} -- [st][ch..key] = tween
local function anim(st, ch, key, to, dur, style, dir, onDone)
	local def = (ch == "x" or ch == "y" or ch == "r") and 0 or 1
	local from = st[ch][key]
	if from == nil then from = def end
	tweens[st] = tweens[st] or {}
	tweens[st][ch .. "|" .. key] = {
		ch = ch, key = key, from = from, to = to, t0 = os.clock(), dur = math.max(dur, 1e-3),
		style = style or Enum.EasingStyle.Quad, dir = dir or Enum.EasingDirection.Out, done = onDone,
	}
	dirty[st] = true
end

local loops = {} -- functions(now, dt)
local timed = {} -- { t0, dur, fn(p), done }
local function runTimed(dur, fn, done) table.insert(timed, { t0 = os.clock(), dur = dur, fn = fn, done = done }) end

local function propTween(o, dur, props)
	TweenService:Create(o, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for st, list in tweens do
		for k, tw in list do
			local p = math.clamp((now - tw.t0) / tw.dur, 0, 1)
			st[tw.ch][tw.key] = tw.from + (tw.to - tw.from) * TweenService:GetValue(p, tw.style, tw.dir)
			dirty[st] = true
			if p >= 1 then
				list[k] = nil
				if tw.done then task.spawn(tw.done) end
			end
		end
		if next(list) == nil then tweens[st] = nil end
	end
	for i = #timed, 1, -1 do
		local t = timed[i]
		local p = math.clamp((now - t.t0) / t.dur, 0, 1)
		t.fn(p)
		if p >= 1 then
			table.remove(timed, i)
			if t.done then task.spawn(t.done) end
		end
	end
	for _, fn in loops do fn(now, dt) end
	for st in dirty do applyState(st) end
	table.clear(dirty)
end)

---------------------------------------------------------------- hover / press tracking
local watches = {}
local function watch(el)
	if watches[el] then return watches[el] end
	local w = { hover = false, press = false, cbs = {} }
	watches[el] = w
	local function fire() for _, cb in w.cbs do cb(w.hover, w.press) end end
	el.MouseEnter:Connect(function() w.hover = true fire() end)
	el.MouseLeave:Connect(function() w.hover = false w.press = false fire() end)
	if el:IsA("GuiButton") then
		el.MouseButton1Down:Connect(function() w.press = true fire() end)
		el.MouseButton1Up:Connect(function() w.press = false fire() end)
		el.SelectionGained:Connect(function() w.hover = true fire() end)
		el.SelectionLost:Connect(function() w.hover = false w.press = false fire() end)
	end
	w.fire = fire
	return w
end
local function onHover(el, cb) table.insert(watch(el).cbs, cb) end
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		for _, w in watches do
			if w.press then w.press = false w.fire() end
			if input.UserInputType == Enum.UserInputType.Touch and w.hover then w.hover = false w.fire() end
		end
	end
end)

-- "Style" setting -> easing curve (Figma preview uses the same names)
local STYLES = {
	Smooth = Enum.EasingStyle.Quint, Bouncy = Enum.EasingStyle.Back, Elastic = Enum.EasingStyle.Elastic,
	Snappy = Enum.EasingStyle.Quad, Linear = Enum.EasingStyle.Linear,
}
local function easeOf(el, tag, fallback)
	return STYLES[P(el, tag, "Style")] or fallback or Enum.EasingStyle.Quint
end

-- One particle: the uploaded Icon if set, otherwise a drawn Shape (Star, Plus, Circle, Diamond)
local function makeParticle(el, tag, z)
	local icon = P(el, tag, "Icon")
	local color = P(el, tag, "Color")
	local p
	if type(icon) == "string" and icon ~= "" then
		p = Instance.new("ImageLabel")
		p.BackgroundTransparency = 1
		p.Image = icon
		p.ScaleType = Enum.ScaleType.Fit
		p.ImageColor3 = (color == Color3.new(1, 1, 1)) and Color3.new(1, 1, 1) or color
	else
		local shape = P(el, tag, "Shape") or "Circle"
		p = Instance.new("Frame")
		p.BorderSizePixel = 0
		if shape == "Star" or shape == "Plus" then
			p.BackgroundTransparency = 1
			for k = 0, 1 do
				local bar = Instance.new("Frame")
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.fromScale(0.5, 0.5)
				bar.Size = k == 0 and UDim2.fromScale(1, shape == "Star" and 0.22 or 0.3) or UDim2.fromScale(shape == "Star" and 0.22 or 0.3, 1)
				bar.BackgroundColor3 = color
				bar.BorderSizePixel = 0
				bar.ZIndex = z
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = bar
				bar.Parent = p
			end
		else
			p.BackgroundColor3 = color
			local c = Instance.new("UICorner")
			c.CornerRadius = shape == "Circle" and UDim.new(1, 0) or UDim.new(0.15, 0)
			c.Parent = p
			if shape == "Diamond" then p.Rotation = 45 end
		end
	end
	p.Name = "FB_Particle"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.ZIndex = z
	return p
end
-- fade a particle made by makeParticle (image, bars or plain frame)
local function particleAlpha(p, a)
	if p:IsA("ImageLabel") then p.ImageTransparency = 1 - a return end
	local bars = false
	for _, b in p:GetChildren() do
		if b:IsA("Frame") then b.BackgroundTransparency = 1 - a bars = true end
	end
	if not bars then p.BackgroundTransparency = 1 - a end
end

local function sound(id, volume)
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = tostring(id):match("^%d+$") and ("rbxassetid://" .. id) or tostring(id)
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
	task.delay(5, function() s:Destroy() end)
end

---------------------------------------------------------------- entrances
local function playEntrance(el)
	local t = TAGS[el]
	if not t then return end
	local st = S(el)
	if t.pop then
		local d, dur = P(el, "pop", "Delay"), P(el, "pop", "Time")
		setCh(st, "s", "pop", P(el, "pop", "From"))
		setCh(st, "a", "pop", 0)
		task.delay(d, function()
			anim(st, "s", "pop", 1, dur, easeOf(el, "pop", Enum.EasingStyle.Back))
			anim(st, "a", "pop", 1, dur * 0.5)
		end)
	end
	if t.fadein then
		setCh(st, "a", "fade", 0)
		task.delay(P(el, "fadein", "Delay"), function() anim(st, "a", "fade", 1, P(el, "fadein", "Time")) end)
	end
	if t.drop then
		setCh(st, "y", "drop", -P(el, "drop", "Height"))
		setCh(st, "a", "drop", 0)
		task.delay(P(el, "drop", "Delay"), function()
			anim(st, "y", "drop", 0, P(el, "drop", "Time"), Enum.EasingStyle.Bounce)
			anim(st, "a", "drop", 1, 0.15)
		end)
	end
	if t.swing then
		local angle, dur = P(el, "swing", "Angle"), P(el, "swing", "Time")
		setCh(st, "r", "swing", angle)
		setCh(st, "a", "swing", 0)
		task.delay(P(el, "swing", "Delay"), function()
			anim(st, "a", "swing", 1, 0.2)
			runTimed(dur, function(p)
				setCh(st, "r", "swing", angle * math.exp(-4 * p) * math.cos(p * math.pi * 5) * (1 - p))
			end)
		end)
	end
	if t.reveal then
		local angle, dur = P(el, "reveal", "Angle"), P(el, "reveal", "Time")
		setCh(st, "s", "reveal", P(el, "reveal", "From"))
		setCh(st, "a", "reveal", 0)
		setCh(st, "r", "reveal", angle)
		task.delay(P(el, "reveal", "Delay"), function()
			anim(st, "s", "reveal", 1, dur * 0.6, Enum.EasingStyle.Back)
			anim(st, "a", "reveal", 1, 0.2)
			runTimed(dur, function(p)
				setCh(st, "r", "reveal", angle * math.exp(-5 * p) * math.cos(p * math.pi * 4))
				-- rocking reads as 3D by narrowing the width while it turns
				setCh(st, "sx", "reveal", 1 - 0.12 * math.abs(math.sin(p * math.pi * 4)) * math.exp(-4 * p))
			end)
		end)
	end
	if t.cascade then
		local kids = {}
		for _, c in el:GetChildren() do
			if c:IsA("GuiObject") and c.Visible and not c:GetAttribute("FB_ShadowFor") then table.insert(kids, c) end
		end
		table.sort(kids, function(a, b)
			if math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) > 4 then return a.AbsolutePosition.Y < b.AbsolutePosition.Y end
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
		local step, dur, dist = P(el, "cascade", "Step"), P(el, "cascade", "Time"), P(el, "cascade", "Distance")
		for i, c in kids do
			local cs = S(c)
			setCh(cs, "a", "cascade", 0)
			setCh(cs, "y", "cascade", dist)
			task.delay((i - 1) * step, function()
				anim(cs, "a", "cascade", 1, dur)
				anim(cs, "y", "cascade", 0, dur, Enum.EasingStyle.Back)
			end)
		end
	end
end
local ENTRANCE = { pop = true, fadein = true, drop = true, swing = true, cascade = true, reveal = true }
local function hasEntrance(t) for k in ENTRANCE do if t[k] then return true end end return false end

local function playEntrancesIn(el)
	playEntrance(el)
	for _, d in el:GetDescendants() do
		local t = TAGS[d]
		if t and hasEntrance(t) then
			local ok, p = true, d
			while p and p ~= el do
				if p:IsA("GuiObject") and not p.Visible then ok = false break end
				p = p.Parent
			end
			if ok then playEntrance(d) end
		end
	end
end

---------------------------------------------------------------- panels & tabs
local panels = {}
local focusPanels = {}
local holdStrokes = {} -- el -> UIStroke filled while a _prompt is held
local blur

local function setVisible(el, v)
	el.Visible = v
	local st = states[el]
	if st then for _, f in st.followers do f.el.Visible = v end
	elseif el.Parent then
		local id = el:GetAttribute("FB_Id")
		for _, sib in el.Parent:GetChildren() do
			if id and sib:GetAttribute("FB_ShadowFor") == id then sib.Visible = v end
		end
	end
end

local function updateFocus()
	local size = 0
	for el in focusPanels do
		if el.Visible and gui.Enabled then size = math.max(size, P(el, "focus", "Blur")) end
	end
	if size > 0 then
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "FigBridgeFocus"
			blur.Size = 0
			blur.Parent = Lighting
		end
		propTween(blur, 0.25, { Size = size })
	elseif blur then
		propTween(blur, 0.25, { Size = 0 })
	end
end

local showFromExit
-- one bus in PlayerGui lets separately imported UIs open each other's panels
local bus
local function getBus()
	if bus then return bus end
	local pg = gui.Parent
	if not pg then return nil end
	bus = pg:FindFirstChild("FB_Bus")
	if not bus then
		bus = Instance.new("BindableEvent")
		bus.Name = "FB_Bus"
		bus.Parent = pg
	end
	return bus
end
local function sendOther(action, name, id)
	local b = getBus()
	if b then b:Fire(action, name, gui, id) end
end
local panelEvent = gui:FindFirstChild("FB_PanelEvent")
local function firePanel(kind, el) if panelEvent then panelEvent:Fire(kind, el.Name) end end
local function show(el)
	if not el then return end
	if showFromExit then showFromExit(el) end
	if el.Visible then return end
	setVisible(el, true)
	playEntrancesIn(el)
	updateFocus()
	firePanel("opened", el)
end
-- Exit animations play before the layer is hidden; a show() during the exit cancels it.
local exitToken = {}
local function hide(el)
	if not el or not el.Visible then return end
	local t = TAGS[el] or {}
	local st = S(el)
	local dur = 0
	if t.popout then
		dur = math.max(dur, P(el, "popout", "Time"))
		anim(st, "s", "exit", P(el, "popout", "To"), P(el, "popout", "Time"), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		anim(st, "a", "exit", 0, P(el, "popout", "Time"), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	if t.fadeout then
		dur = math.max(dur, P(el, "fadeout", "Time"))
		anim(st, "a", "exit", 0, P(el, "fadeout", "Time"))
	end
	if t.dropout then
		dur = math.max(dur, P(el, "dropout", "Time"))
		anim(st, "y", "exit", P(el, "dropout", "Distance"), P(el, "dropout", "Time"), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		anim(st, "a", "exit", 0, P(el, "dropout", "Time"), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	local token = {}
	exitToken[el] = token
	local function finish()
		if exitToken[el] ~= token then return end
		setVisible(el, false)
		-- reset exit channels so the next show starts clean
		if tweens[st] then for k in tweens[st] do if string.find(k, "|exit$") then tweens[st][k] = nil end end end
		st.s.exit, st.a.exit, st.y.exit = nil, nil, nil
		dirty[st] = true
		updateFocus()
		firePanel("closed", el)
	end
	if dur > 0 then task.delay(dur, finish) else finish() end
end
showFromExit = function(el)
	if exitToken[el] then
		exitToken[el] = nil
		local st = S(el)
		if tweens[st] then for k in tweens[st] do if string.find(k, "|exit$") then tweens[st][k] = nil end end end
		st.s.exit, st.a.exit, st.y.exit = nil, nil, nil
		dirty[st] = true
	end
end

-- find what a button/script wants to open: Figma id first (prototype links), then panel or layer name
local function findTarget(id, name)
	if id then
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiObject") and d:GetAttribute("FB_Id") == id then return d end
		end
	end
	if name then
		if panels[name] then return panels[name] end
		-- "Group 1", "group1" and "Group_1" all match
		local function norm(x) return string.lower((string.gsub(x, "[%s_]", ""))) end
		local want = norm(name)
		for pname, p in panels do if norm(pname) == want then return p end end
		local top = root:FindFirstChildWhichIsA("GuiObject")
		if top and norm(top.Name) == want then return top end
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") and norm(d.Name) == want then return d end
		end
	end
	return nil
end
local function act(action, el)
	if action == "open" then show(el)
	elseif action == "close" then hide(el)
	elseif action == "toggle" then if el.Visible then hide(el) else show(el) end end
end
local function request(action, name, id)
	local el = findTarget(id, name)
	if el then act(action, el) else sendOther(action, name, id) end
end

local tabGroups = {} -- groupInst -> { buttons }
local function selectTab(groupKey, btn)
	for _, b in tabGroups[groupKey] do
		local target = panels[TAGS[b].tab]
		local on = b == btn
		if target then if on then show(target) else hide(target) end end
		for _, d in b:GetDescendants() do
			local t = TAGS[d]
			if t and t.active then d.Visible = on end
		end
		b:SetAttribute("FB_Selected", on)
	end
end

---------------------------------------------------------------- live data
local liveTexts = {}
local function formatValue(v)
	if typeof(v) == "number" then
		if v == math.floor(v) then
			local s = tostring(math.floor(v))
			local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
			return (formatted:gsub("^(-?),", "%1"))
		end
		return string.format("%.2f", v)
	end
	return tostring(v)
end
local function resolve(path)
	local cur = player
	for part in string.gmatch(path, "[^%.]+") do
		cur = cur and cur:FindFirstChild(part)
	end
	if cur and cur:IsA("ValueBase") then return cur.Value end
	return nil
end
-- Numbers roll up/down to their new value instead of jumping.
local counters = {}
local COUNT_TIME = 0.6
local function valueFor(el, k)
	if k == "PlayerName" then return player.Name end
	if k == "DisplayName" then return player.DisplayName end
	local t = TAGS[el]
	if k == "__bind" and t and t.bind then return resolve(t.bind) end
	return resolve("leaderstats." .. k)
end
local function renderText(el, c)
	local function fmt(k)
		local v = c.shown[k]
		if v == nil then return "0" end
		return formatValue(v)
	end
	local t = TAGS[el]
	if t and t.bind then el.Text = fmt("__bind") return end
	el.Text = (string.gsub(el:GetAttribute("FB_Template"), "{(%w+)}", fmt))
end
local function refreshText(el)
	local c = counters[el]
	if not c then c = { shown = {}, from = {}, to = {} } counters[el] = c end
	local keys = {}
	local t = TAGS[el]
	if t and t.bind then keys = { "__bind" }
	else for k in string.gmatch(el:GetAttribute("FB_Template") or "", "{(%w+)}") do table.insert(keys, k) end end
	for _, k in keys do
		local v = valueFor(el, k)
		if typeof(v) == "number" and typeof(c.shown[k]) == "number" then
			if v ~= c.to[k] then c.from[k] = c.shown[k] c.to[k] = v c.t0 = os.clock() end
		else
			c.shown[k] = v
			c.to[k] = v
		end
	end
	if not c.t0 then renderText(el, c) end
end
table.insert(loops, function(now)
	for el, c in counters do
		if not c.t0 then continue end
		local p = math.clamp((now - c.t0) / COUNT_TIME, 0, 1)
		local e = 1 - (1 - p) ^ 4
		for k, to in c.to do
			local from = c.from[k]
			if from ~= nil and typeof(to) == "number" then
				local v = from + (to - from) * e
				c.shown[k] = (to == math.floor(to)) and math.round(v) or v
			end
		end
		if p >= 1 then
			for k, to in c.to do c.shown[k] = to c.from[k] = nil end
			c.t0 = nil
		end
		renderText(el, c)
	end
end)

---------------------------------------------------------------- setup per tag
local function colorProp(el)
	if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then return "TextColor3" end
	if el:IsA("ImageLabel") or el:IsA("ImageButton") then return "ImageColor3" end
	return "BackgroundColor3"
end

local function setupButton(btn, t)
	local w = watch(btn)
	local st = S(btn)
	-- variants
	local variants = {}
	for _, d in btn:GetDescendants() do
		local dt = TAGS[d]
		if dt and buttonOf(d.Parent) == btn then
			for _, kind in { "hover", "clicked", "default", "disabled" } do
				if dt[kind] then table.insert(variants, { el = d, kind = kind }) end
			end
		end
	end
	local function interactable()
		local ok, v = pcall(function() return btn.Interactable end)
		return (not ok or v ~= false) and btn.Active ~= false
	end
	local function updateVariants()
		if #variants == 0 then return end
		local state = "none"
		if not interactable() then state = "disabled"
		elseif w.press then state = "clicked"
		elseif w.hover then state = "hover" end
		local has = {}
		for _, v in variants do has[v.kind] = true end
		if state == "clicked" and not has.clicked and has.hover then state = "hover" end
		for _, v in variants do
			if v.kind == "default" then v.el.Visible = state == "none" or not has[state]
			else v.el.Visible = v.kind == state end
		end
	end
	updateVariants()
	pcall(function() btn:GetPropertyChangedSignal("Interactable"):Connect(updateVariants) end)
	btn:GetPropertyChangedSignal("Active"):Connect(updateVariants)

	-- darken feedback for plain buttons without drawn variants
	local darkTargets = {}
	if t.button and #variants == 0 then
		local objs = btn:GetDescendants()
		table.insert(objs, btn)
		for _, o in objs do
			if o:IsA("GuiObject") and not (TAGS[o] and TAGS[o].nodim) and buttonOf(o) == btn then
				local prop = (o:IsA("ImageLabel") or o:IsA("ImageButton")) and "ImageColor3" or (not o:IsA("TextLabel") and not o:IsA("TextButton") and "BackgroundColor3")
				if prop then table.insert(darkTargets, { o = o, prop = prop, base = o[prop] }) end
			end
		end
	end
	onHover(btn, function(hover, press)
		updateVariants()
		if t.button and #darkTargets > 0 then
			local k = press and P(btn, "button", "Darken") * 2 or (hover and P(btn, "button", "Darken") or 0)
			for _, d in darkTargets do
				propTween(d.o, P(btn, "button", "Time"), { [d.prop] = d.base:Lerp(Color3.new(0, 0, 0), k) })
			end
		end
		if t.smooth then
			local target = press and P(btn, "smooth", "PressScale") or (hover and P(btn, "smooth", "HoverScale") or 1)
			anim(st, "s", "smooth", target, P(btn, "smooth", "Time"), Enum.EasingStyle.Quad)
		end
		if t.press then
			anim(st, "s", "press", press and P(btn, "press", "Scale") or 1, press and P(btn, "press", "Time") or P(btn, "press", "Time") * 2.5,
				press and Enum.EasingStyle.Quad or easeOf(btn, "press", Enum.EasingStyle.Back))
		end
		if t.squish then
			local dur = P(btn, "squish", "Time")
			if press then
				local q = P(btn, "squish", "Squash")
				anim(st, "sx", "squish", 1 + (1 - q) * 0.6, 0.08)
				anim(st, "sy", "squish", q, 0.08)
			else
				anim(st, "sx", "squish", 1, dur, Enum.EasingStyle.Elastic)
				anim(st, "sy", "squish", 1, dur, Enum.EasingStyle.Elastic)
			end
		end
	end)
	if t.smooth then
		local wasHover = false
		onHover(btn, function(hover)
			if hover and not wasHover then sound(P(btn, "smooth", "HoverSound")) end
			wasHover = hover
		end)
		btn.Activated:Connect(function() sound(P(btn, "smooth", "ClickSound")) end)
	end

	if t.ripple then
		btn.ClipsDescendants = true
		btn.MouseButton1Down:Connect(function()
			local m = UserInputService:GetMouseLocation()
			local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
			if as.X < 1 or as.Y < 1 then return end
			local fx, fy = (m.X - ap.X) / as.X, (m.Y - ap.Y) / as.Y
			if fx < 0 or fx > 1 or fy < 0 or fy > 1 then fx, fy = 0.5, 0.5 end
			local c = Instance.new("Frame")
			c.Name = "FB_Ripple"
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(fx, fy)
			c.Size = UDim2.fromScale(0, 0)
			c.BackgroundColor3 = P(btn, "ripple", "Color")
			c.BackgroundTransparency = 1 - P(btn, "ripple", "Opacity")
			c.BorderSizePixel = 0
			c.ZIndex = 1000
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = c
			c.Parent = btn
			local px = math.max(as.X, as.Y) * 2.4
			local dur = P(btn, "ripple", "Time")
			TweenService:Create(c, TweenInfo.new(dur, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(px / as.X, px / as.Y), BackgroundTransparency = 1,
			}):Play()
			task.delay(dur, function() c:Destroy() end)
		end)
	end

	if t.burst then
		btn.Activated:Connect(function()
			local parent = btn.Parent
			local inLayout = parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
			local count, dist, size, life = P(btn, "burst", "Count"), P(btn, "burst", "Distance"), P(btn, "burst", "Size"), P(btn, "burst", "Life")
			for i = 1, count do
				local z = inLayout and btn.ZIndex + 1 or btn.ZIndex - 1
				local p = makeParticle(btn, "burst", z)
				p.Size = UDim2.fromOffset(size, size)
				local start
				if inLayout then
					p.Parent = btn
					start = UDim2.fromScale(0.5, 0.5)
				else
					p.Parent = parent
					start = btn.Position
				end
				p.Position = start
				local ang = (i / count) * math.pi * 2 + math.random() * 0.6
				local d = dist * (0.6 + math.random() * 0.6)
				local spin = P(btn, "burst", "Spin") * (math.random() < 0.5 and -1 or 1) * life
				local rot0 = p.Rotation
				TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = start + UDim2.fromOffset(math.cos(ang) * d, math.sin(ang) * d),
					Size = UDim2.fromOffset(size * 0.3, size * 0.3), Rotation = rot0 + spin,
				}):Play()
				local t0 = os.clock()
				task.spawn(function()
					while p.Parent do
						local k = (os.clock() - t0) / life
						if k >= 1 then break end
						particleAlpha(p, 1 - k * k)
						RunService.RenderStepped:Wait()
					end
					p:Destroy()
				end)
			end
		end)
	end

	-- navigation
	btn.Activated:Connect(function()
		if not interactable() then return end
		if t.open then request("open", t.open) end
		if t.toggle then request("toggle", t.toggle) end
		-- connected in Figma's Prototype tab
		local link = btn:GetAttribute("FB_Link")
		if link == "open" or link == "toggle" then
			request(link, btn:GetAttribute("FB_LinkName"), btn:GetAttribute("FB_LinkId"))
		elseif link == "close" and not t.close then
			local panel = ancestorWith(btn, "panel", true)
			if panel then hide(panel) else local top = root:FindFirstChildWhichIsA("GuiObject") if top then hide(top) end end
		end
		if t.close then
			local panel = ancestorWith(btn, "panel", true)
			if panel then
				hide(panel)
			else
				-- not inside a panel: hide the whole design, playing its exit animation (UI.Open brings it back)
				local top = root:FindFirstChildWhichIsA("GuiObject")
				if top then hide(top) else gui.Enabled = false updateFocus() end
			end
		end
		if t.tab then
			local g = ancestorWith(btn, "tabgroup", false) or root
			selectTab(g, btn)
		end
	end)
	for _, k in { "open", "toggle", "tab" } do
		if t[k] and not panels[t[k]] then warn("[FigmaToRoblox] " .. btn.Name .. ": no panel named '" .. t[k] .. "' (add _panel to it)") end
	end
end

local function setup(el, t)
	local st
	local function ST() st = st or S(el) return st end

	if el:IsA("GuiButton") then setupButton(el, t) end

	if t.grow then
		local hb = buttonOf(el) or el
		onHover(hb, function(hover)
			anim(ST(), "s", "grow", hover and P(el, "grow", "Scale") or 1, P(el, "grow", "Time"), easeOf(el, "grow"))
		end)
	end
	if t.sound then
		local hb = buttonOf(el) or el
		local was = false
		onHover(hb, function(hover)
			if hover and not was then sound(P(el, "sound", "Hover"), P(el, "sound", "Volume")) end
			was = hover
		end)
		if hb:IsA("GuiButton") then
			hb.Activated:Connect(function() sound(P(el, "sound", "Click"), P(el, "sound", "Volume")) end)
		end
	end
	if t.up or t.turn then
		local hb = buttonOf(el) or el
		onHover(hb, function(hover)
			if t.up then anim(ST(), "y", "up", hover and -P(el, "up", "Lift") or 0, P(el, "up", "Time"), easeOf(el, "up")) end
			if t.turn then anim(ST(), "r", "turn", hover and P(el, "turn", "Angle") or 0, P(el, "turn", "Time")) end
		end)
	end
	if t.lean then
		local hb = buttonOf(el.Parent)
		if hb then onHover(hb, function(hover) anim(ST(), "r", "lean", hover and P(el, "lean", "Angle") or 0, P(el, "lean", "Time"), Enum.EasingStyle.Back) end) end
	end
	if t.color then
		local hb = buttonOf(el) or el
		local prop = colorProp(el)
		local base = el[prop]
		onHover(hb, function(hover)
			propTween(el, P(el, "color", "Time"), { [prop] = hover and P(el, "color", "HoverColor") or base })
		end)
	end
	if t.magnet then
		local cur = { 0, 0 }
		table.insert(loops, function(_, dt)
			if not el.Visible then return end
			local m = UserInputService:GetMouseLocation()
			local sc = scaleNow()
			local c = el.AbsolutePosition + el.AbsoluteSize / 2 - Vector2.new(cur[1], cur[2]) * sc
			local d = m - c
			local tx, ty = 0, 0
			if d.Magnitude < P(el, "magnet", "Radius") * sc then
				tx, ty = d.X * P(el, "magnet", "Strength") / sc, d.Y * P(el, "magnet", "Strength") / sc
			end
			local k = math.min(1, dt * 12)
			cur[1] += (tx - cur[1]) * k
			cur[2] += (ty - cur[2]) * k
			setCh(ST(), "x", "magnet", cur[1])
			setCh(ST(), "y", "magnet", cur[2])
		end)
	end
	if t.select then
		local card = el:IsA("GuiButton") and el or buttonOf(el.Parent)
		if card then
			local highlight = el
			local stroke
			if el == card then
				stroke = Instance.new("UIStroke")
				stroke.Color = P(el, "select", "Color")
				stroke.Thickness = P(el, "select", "Thickness")
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Enabled = false
				stroke.Parent = el
			else
				highlight.Visible = false
			end
			local function setSel(on)
				if stroke then stroke.Enabled = on else highlight.Visible = on end
				card:SetAttribute("FB_Selected", on)
			end
			card:SetAttribute("FB_Selected", false)
			card:SetAttribute("FB_SelectGroup", true)
			card.Activated:Connect(function()
				for _, sib in card.Parent:GetChildren() do
					if sib ~= card and sib:GetAttribute("FB_SelectGroup") then sib:SetAttribute("FB_Selected", false) end
				end
				setSel(true)
				if card.Parent then card.Parent:SetAttribute("FB_Selected", card.Name) end
			end)
			card:GetAttributeChangedSignal("FB_Selected"):Connect(function()
				if card:GetAttribute("FB_Selected") == false then
					if stroke then stroke.Enabled = false else highlight.Visible = false end
				end
			end)
		end
	end
	if t.card then
		local targets = {}
		if t.card ~= true then
			for _, d in gui:GetDescendants() do
				if d.Name == t.card and d:IsA("GuiObject") and d ~= el then table.insert(targets, d) end
			end
		else
			local b = buttonOf(el.Parent)
			if b then table.insert(targets, b) end
		end
		el.Visible = false
		local hovering, token = 0, 0
		local function update()
			token += 1
			local my = token
			if hovering > 0 then
				task.delay(P(el, "card", "Delay"), function()
					if my ~= token or hovering == 0 then return end
					setVisible(el, true)
					setCh(ST(), "a", "card", 0)
					anim(ST(), "a", "card", 1, P(el, "card", "Time"))
				end)
			else
				setVisible(el, false)
			end
		end
		for _, tgt in targets do
			local was = false
			onHover(tgt, function(hover)
				if hover ~= was then hovering += hover and 1 or -1 was = hover update() end
			end)
			tgt:SetAttribute("Owner", nil)
			onHover(tgt, function(hover) if hover then el:SetAttribute("Owner", tgt.Name) end end)
		end
		if #targets == 0 then warn("[FigmaToRoblox] " .. el.Name .. ": _card found no button to follow") end
	end

	-- shine sweeps
	local function sweep(dur, onDone)
		local parent = el.Parent
		if not parent or not parent:IsA("GuiObject") then return end
		local sc = scaleNow()
		local pw = parent.AbsoluteSize.X / sc
		local ew = el.AbsoluteSize.X / sc
		local cx = ST().pos.X.Scale * pw + ST().pos.X.Offset
		local from, to = -(cx + ew), pw - cx + ew
		setCh(ST(), "x", "sweep", from)
		el.Visible = true
		anim(ST(), "x", "sweep", to, dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, function()
			el.Visible = false
			if onDone then onDone() end
		end)
	end
	if t.glint or t.shiny or t.beam then
		if el.Parent:IsA("GuiObject") and not el.Parent:IsA("CanvasGroup") then el.Parent.ClipsDescendants = true end
	end
	if t.glint then
		el.Visible = false
		local hb = buttonOf(el.Parent) or el.Parent
		local busy = false
		onHover(hb, function(hover)
			if hover and not busy then
				busy = true
				sweep(P(el, "glint", "Time"), function() busy = false end)
			end
		end)
	end
	if t.shiny then
		el.Visible = false
		task.spawn(function()
			while el.Parent do
				local done = false
				sweep(P(el, "shiny", "Time"), function() done = true end)
				repeat task.wait() until done or not el.Parent
				task.wait(P(el, "shiny", "Pause"))
			end
		end)
	end
	if t.beam then
		local t0 = os.clock()
		table.insert(loops, function(now)
			local parent = el.Parent
			if not parent or not parent:IsA("GuiObject") then return end
			local sc = scaleNow()
			local ph = parent.AbsoluteSize.Y / sc
			local eh = el.AbsoluteSize.Y / sc
			local cy = ST().pos.Y.Scale * ph + ST().pos.Y.Offset
			local top = cy + eh / 2
			local D = ph + eh
			local raw = ((now - t0) * P(el, "beam", "Speed")) % math.max(D, 1)
			setCh(ST(), "y", "beam", raw <= top and -raw or (D - raw))
		end)
	end

	-- motion at rest
	local phase = math.random() * 10
	if t.spin then
		local r = 0
		table.insert(loops, function(_, dt)
			r = (r + P(el, "spin", "Speed") * dt) % 360
			setCh(ST(), "r", "spin", r)
		end)
	end
	if t.rays then
		local r = 0
		table.insert(loops, function(now, dt)
			r = (r + P(el, "rays", "Speed") * dt) % 360
			setCh(ST(), "r", "rays", r)
			setCh(ST(), "s", "rays", 1 + P(el, "rays", "Pulse") * math.sin(now * P(el, "rays", "Rate") * math.pi * 2))
		end)
	end
	if t.pulse then
		table.insert(loops, function(now)
			setCh(ST(), "s", "pulse", 1 + P(el, "pulse", "Amount") * math.sin(now * P(el, "pulse", "Rate") * math.pi * 2))
		end)
	end
	if t.float then
		table.insert(loops, function(now)
			local a = math.rad(P(el, "float", "Angle"))
			local d = P(el, "float", "Distance") * math.sin((now + phase) * P(el, "float", "Rate") * math.pi * 2)
			setCh(ST(), "x", "float", math.sin(a) * d)
			setCh(ST(), "y", "float", -math.cos(a) * d)
		end)
	end
	if t.jelly then
		table.insert(loops, function(now)
			local k = P(el, "jelly", "Amount") * math.sin((now + phase) * P(el, "jelly", "Rate") * math.pi * 2)
			setCh(ST(), "sx", "jelly", 1 + k)
			setCh(ST(), "sy", "jelly", 1 - k)
		end)
	end
	if t.blink then
		local t0 = os.clock() + P(el, "blink", "Delay")
		table.insert(loops, function(now)
			local on, off, fade = P(el, "blink", "On"), P(el, "blink", "Off"), P(el, "blink", "Fade")
			local e = now - t0
			if e < 0 then return end
			local c = e % (on + off + fade * 2)
			local a
			if c < on then a = 1
			elseif c < on + fade then a = 1 - (c - on) / fade
			elseif c < on + fade + off then a = 0
			else a = (c - on - fade - off) / fade end
			setCh(ST(), "a", "blink", a)
		end)
	end
	if t.shake then
		local t0 = os.clock() + phase % 1
		table.insert(loops, function(now)
			local every, dur = P(el, "shake", "Every"), P(el, "shake", "Duration")
			local c = (now - t0) % math.max(every, dur + 0.05)
			local v = 0
			if c < dur then v = P(el, "shake", "Distance") * math.sin(c * 60) * (1 - c / dur) end
			setCh(ST(), "x", "shake", v)
		end)
	end
	if t.wiggle then
		local t0 = os.clock() + phase % 1
		table.insert(loops, function(now)
			local every, dur = P(el, "wiggle", "Every"), P(el, "wiggle", "Duration")
			local c = (now - t0) % math.max(every, dur + 0.05)
			local v = 0
			if c < dur then v = P(el, "wiggle", "Angle") * math.sin(c / dur * math.pi * 4) * (1 - c / dur) end
			setCh(ST(), "r", "wiggle", v)
		end)
	end
	if t.glow then
		local parent = el.Parent
		local inLayout = parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout")
		if inLayout then
			-- siblings would be laid out as items; fall back to a pulsing outline
			local stroke = Instance.new("UIStroke")
			stroke.Color = P(el, "glow", "Color")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = el
			table.insert(loops, function(now)
				local k = 0.5 + 0.5 * math.sin(now * P(el, "glow", "Rate") * math.pi * 2)
				stroke.Thickness = P(el, "glow", "Size") / 3 * (0.5 + 0.5 * k)
				stroke.Transparency = 0.2 + 0.5 * (1 - k)
			end)
		else
			-- soft halo: stacked rounded layers behind the element that follow it every frame
			local corner = el:FindFirstChildWhichIsA("UICorner")
			local radius = corner and corner.CornerRadius.Offset or 0
			local LAYERS = 7
			local halo = {}
			for i = 1, LAYERS do
				local f = Instance.new("Frame")
				f.Name = "FB_Glow"
				f.BorderSizePixel = 0
				f.BackgroundColor3 = P(el, "glow", "Color")
				local c = Instance.new("UICorner")
				c.Parent = f
				local s = Instance.new("UIScale")
				s.Parent = f
				f.Parent = parent
				halo[i] = { f = f, c = c, s = s, k = i / LAYERS }
			end
			table.insert(loops, function(now)
				local pulse = 0.5 + 0.5 * math.sin(now * P(el, "glow", "Rate") * math.pi * 2)
				local size = P(el, "glow", "Size") * (0.7 + 0.3 * pulse)
				local color = P(el, "glow", "Color")
				local us = el:FindFirstChild("FB_AnimScale")
				for _, h in halo do
					local grow = size * h.k
					h.f.Visible = el.Visible
					h.f.AnchorPoint = el.AnchorPoint
					h.f.Position = el.Position
					h.f.Size = el.Size + UDim2.fromOffset(grow * 2, grow * 2)
					h.f.Rotation = el.Rotation
					h.f.ZIndex = el.ZIndex - 1
					h.f.BackgroundColor3 = color
					-- inner layers stronger, outer ones fade out: reads as a soft blur
					h.f.BackgroundTransparency = 1 - (0.06 + 0.32 * (1 - h.k) ^ 1.6) * (0.7 + 0.3 * pulse)
					h.c.CornerRadius = UDim.new(0, radius + grow)
					h.s.Scale = us and us.Scale or 1
				end
			end)
		end
	end
	if t.pixels then
		el.ClipsDescendants = true
		local acc = 0
		table.insert(loops, function(_, dt)
			if not el.Visible then return end
			acc += dt * P(el, "pixels", "Rate")
			while acc >= 1 do
				acc -= 1
				local size = P(el, "pixels", "Size")
				local px = Instance.new("Frame")
				px.Name = "FB_Pixel"
				px.BorderSizePixel = 0
				px.AnchorPoint = Vector2.new(0.5, 0.5)
				px.Size = UDim2.fromOffset(size, size)
				px.Position = UDim2.fromScale(math.random(), math.random())
				px.BackgroundColor3 = P(el, "pixels", "Color")
				px.BackgroundTransparency = 1
				px.ZIndex = 1000
				px.Parent = el
				local op = 1 - P(el, "pixels", "Opacity")
				TweenService:Create(px, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { BackgroundTransparency = op }):Play()
				task.delay(0.75, function() px:Destroy() end)
			end
		end)
	end
	if t.fall then
		-- a tagged image falls inside its parent; a tagged container rains its first image child
		local template, area = el, el.Parent
		if not (el:IsA("ImageLabel") or el:IsA("ImageButton")) then
			template = el:FindFirstChildWhichIsA("ImageLabel") or el:FindFirstChildWhichIsA("ImageButton")
			area = el
		end
		if template and area and area:IsA("GuiObject") then
			if area:IsA("GuiObject") and not area:IsA("CanvasGroup") then area.ClipsDescendants = true end
			if template == el then el.Visible = false end
			local drops = {}
			for i = 1, P(el, "fall", "Count") do
				local d = Instance.new("ImageLabel")
				d.Name = "FB_Fall"
				d.BackgroundTransparency = 1
				d.Image = template.Image
				pcall(function() d.ImageContent = template.ImageContent end)
				d.ScaleType = Enum.ScaleType.Fit
				d.AnchorPoint = Vector2.new(0.5, 0.5)
				d.ZIndex = template.ZIndex
				d.Parent = area
				drops[i] = { d = d, x = math.random(), y = math.random() * 1.2 - 0.1, k = 0, r = math.random(-40, 40) }
			end
			local function reset(dr, top)
				local mn, mx = P(el, "fall", "MinSize"), P(el, "fall", "MaxSize")
				dr.k = mn + (mx - mn) * math.random()
				dr.x = math.random()
				if top then dr.y = -0.15 end
			end
			for _, dr in drops do reset(dr, false) end
			table.insert(loops, function(_, dt)
				local sc = scaleNow()
				local ah = math.max(area.AbsoluteSize.Y / sc, 1)
				local tw, th = template.AbsoluteSize.X / sc, template.AbsoluteSize.Y / sc
				for _, dr in drops do
					dr.y += dt * P(el, "fall", "Speed") / ah
					if dr.y > 1.15 then reset(dr, true) end
					dr.d.Position = UDim2.fromScale(dr.x, dr.y)
					dr.d.Size = UDim2.fromOffset(tw * dr.k, th * dr.k)
					dr.d.Rotation += dr.r * dt
				end
			end)
		else
			warn("[FigmaToRoblox] " .. el.Name .. ": _fall needs an image (tag the image, or a frame with an image inside)")
		end
	end
	if t.drift then
		if (el:IsA("ImageLabel") or el:IsA("ImageButton")) and el.ScaleType == Enum.ScaleType.Tile then
			local tile = el.TileSize
			local tx, ty = math.max(tile.X.Offset, 1), math.max(tile.Y.Offset, 1)
			local layer = Instance.new("ImageLabel")
			layer.Name = "FB_Drift"
			layer.BackgroundTransparency = 1
			layer.Image = el.Image
			pcall(function() layer.ImageContent = el.ImageContent end)
			layer.ImageTransparency = el.ImageTransparency
			layer.ImageColor3 = el.ImageColor3
			layer.ScaleType = Enum.ScaleType.Tile
			layer.TileSize = tile
			layer.Size = UDim2.new(1, tx, 1, ty)
			layer.ZIndex = el.ZIndex
			layer.Parent = el
			el.ImageTransparency = 1
			el.ClipsDescendants = true
			local ox, oy = 0, 0
			table.insert(loops, function(_, dt)
				ox = (ox + P(el, "drift", "SpeedX") * dt) % tx
				oy = (oy + P(el, "drift", "SpeedY") * dt) % ty
				layer.Position = UDim2.fromOffset(ox - tx, oy - ty)
			end)
		else
			warn("[FigmaToRoblox] " .. el.Name .. ": _drift needs an image fill set to Tile in Figma")
		end
	end
	-- Roblox UI is flat: 3D turns are faked by foreshortening (width/height scale by cos(angle))
	if t.tilt then
		setCh(ST(), "sx", "tilt", math.cos(math.rad(P(el, "tilt", "Y"))))
		setCh(ST(), "sy", "tilt", math.cos(math.rad(P(el, "tilt", "X"))))
	end
	if t.tilt3d then
		local hb = buttonOf(el) or el
		local hovering = false
		onHover(hb, function(h) hovering = h end)
		local nx, ny = 0, 0
		table.insert(loops, function(_, dt)
			local tx, ty = 0, 0
			if hovering then
				local m = UserInputService:GetMouseLocation()
				local c = el.AbsolutePosition + el.AbsoluteSize / 2
				tx = math.clamp((m.X - c.X) / math.max(el.AbsoluteSize.X / 2, 1), -1, 1)
				ty = math.clamp((m.Y - c.Y) / math.max(el.AbsoluteSize.Y / 2, 1), -1, 1)
			end
			local k = math.min(1, dt * 10)
			nx += (tx - nx) * k
			ny += (ty - ny) * k
			local s = P(el, "tilt3d", "Strength")
			setCh(ST(), "sx", "tilt3d", math.cos(math.rad(s * nx)))
			setCh(ST(), "sy", "tilt3d", math.cos(math.rad(s * ny)))
			setCh(ST(), "r", "tilt3d", nx * ny * s * 0.15)
			setCh(ST(), "x", "tilt3d", nx * s * P(el, "tilt3d", "Depth"))
			setCh(ST(), "y", "tilt3d", ny * s * P(el, "tilt3d", "Depth"))
		end)
	end
	if t.pointer then
		task.defer(function()
			local group = el.Parent
			local buttons = {}
			for _, d in group:GetDescendants() do
				if d:IsA("GuiButton") and d ~= el and not (TAGS[d] and TAGS[d].nopointer) then table.insert(buttons, d) end
			end
			if #buttons == 0 then warn("[FigmaToRoblox] " .. el.Name .. ": _pointer found no buttons beside it") return end
			local sc = scaleNow()
			local mine = el.AbsolutePosition + el.AbsoluteSize / 2
			local nearest, best = buttons[1], math.huge
			for _, b in buttons do
				local d = ((b.AbsolutePosition + b.AbsoluteSize / 2) - mine).Magnitude
				if d < best then nearest, best = b, d end
			end
			local anchor = nearest.AbsolutePosition + nearest.AbsoluteSize / 2
			el.Visible = false
			local current, hideToken = nil, 0
			for _, b in buttons do
				onHover(b, function(hover)
					if hover then
						hideToken += 1
						local delta = ((b.AbsolutePosition + b.AbsoluteSize / 2) - anchor) / scaleNow()
						if not el.Visible then
							setCh(ST(), "x", "pointer", delta.X)
							setCh(ST(), "y", "pointer", delta.Y)
							setVisible(el, true)
							setCh(ST(), "a", "pointer", 0)
							anim(ST(), "a", "pointer", 1, 0.15)
						else
							anim(ST(), "x", "pointer", delta.X, P(el, "pointer", "Time"), Enum.EasingStyle.Back)
							anim(ST(), "y", "pointer", delta.Y, P(el, "pointer", "Time"), Enum.EasingStyle.Back)
						end
						current = b
					elseif current == b then
						hideToken += 1
						local my = hideToken
						task.delay(P(el, "pointer", "Hide"), function()
							if my == hideToken then setVisible(el, false) current = nil end
						end)
					end
				end)
			end
			local _ = sc
		end)
	end
	if t.hold then
		local stroke = el:FindFirstChildWhichIsA("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Thickness = 4
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = el
		end
		holdStrokes[el] = stroke
	end
	if t.type and (el:IsA("TextLabel") or el:IsA("TextButton")) then
		task.spawn(function()
			task.wait(P(el, "type", "Delay"))
			repeat
				el.MaxVisibleGraphemes = 0
				local total = utf8.len(el.ContentText) or #el.ContentText
				local shown = 0
				while shown < total and el.Parent do
					if el.Visible then shown += 1 el.MaxVisibleGraphemes = shown end
					task.wait(1 / math.max(1, P(el, "type", "Speed")))
					total = utf8.len(el.ContentText) or total
				end
				el.MaxVisibleGraphemes = -1
				if P(el, "type", "Loop") then task.wait(P(el, "type", "Pause")) end
			until not P(el, "type", "Loop") or not el.Parent
		end)
	end
	if t.sparkle then
		-- each particle lives Life seconds (±30%), grows in and out, spins and can rise
		local stars = {}
		local hb = buttonOf(el) or el
		local hovering = false
		if P(el, "sparkle", "Trigger") == "Hover" then onHover(hb, function(h) hovering = h end) end
		local function respawn(s, now)
			local mn, mx = P(el, "sparkle", "MinSize"), P(el, "sparkle", "MaxSize")
			s.size = mn + (mx - mn) * math.random()
			s.life = P(el, "sparkle", "Life") * (0.7 + math.random() * 0.6)
			s.t0 = now
			s.x, s.y = math.random(), math.random()
			s.dir = math.random() < 0.5 and -1 or 1
		end
		for i = 1, P(el, "sparkle", "Count") do
			local f = makeParticle(el, "sparkle", 1000)
			f.Parent = el
			local s = { f = f, base = f.Rotation }
			respawn(s, os.clock() - math.random() * P(el, "sparkle", "Life"))
			stars[i] = s
		end
		table.insert(loops, function(now)
			local active = P(el, "sparkle", "Trigger") ~= "Hover" or hovering
			for _, s in stars do
				local p = (now - s.t0) / s.life
				if p >= 1 then
					respawn(s, now)
					p = 0
					s.idle = not active
				end
				local k = s.idle and 0 or math.sin(p * math.pi)
				s.f.Size = UDim2.fromOffset(s.size * k, s.size * k)
				s.f.Position = UDim2.new(s.x, 0, s.y, -P(el, "sparkle", "Rise") * p)
				s.f.Rotation = s.base + s.dir * P(el, "sparkle", "Spin") * p * s.life
				particleAlpha(s.f, k)
			end
		end)
	end
	if t.gleam and (el:IsA("TextLabel") or el:IsA("TextButton")) then
		local base = el.TextColor3
		el.TextColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		local hi = P(el, "gleam", "Color")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.4, base), ColorSequenceKeypoint.new(0.5, hi),
			ColorSequenceKeypoint.new(0.6, base), ColorSequenceKeypoint.new(1, base),
		})
		g.Offset = Vector2.new(-1, 0)
		g.Parent = el
		task.spawn(function()
			while el.Parent do
				g.Offset = Vector2.new(-1, 0)
				TweenService:Create(g, TweenInfo.new(P(el, "gleam", "Time"), Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
				task.wait(P(el, "gleam", "Time") + P(el, "gleam", "Pause"))
			end
		end)
	end
	local function gradientLoop(g, tag)
		table.insert(loops, function(now, dt)
			if P(el, tag, "Mode") == "Move" then
				local o = ((now * P(el, tag, "Speed") / 180) % 2) - 1
				g.Offset = Vector2.new(o, 0)
			else
				g.Rotation = (g.Rotation + P(el, tag, "Speed") * dt) % 360
			end
		end)
	end
	-- full spectrum repeated Bands times (max 3 keeps it under Roblox's 20 keypoints)
	local function rainbow(bands)
		bands = math.clamp(math.floor(bands or 1), 1, 3)
		local cs, steps = {}, 6 * bands
		for i = 0, steps do table.insert(cs, ColorSequenceKeypoint.new(i / steps, Color3.fromHSV((i / 6) % 1, 0.75, 1))) end
		return ColorSequence.new(cs)
	end
	if t.stroke then
		local stroke = el:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			local g = stroke:FindFirstChildWhichIsA("UIGradient")
			if not g then
				g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(stroke.Color, Color3.new(1, 1, 1))
				g.Parent = stroke
			end
			gradientLoop(g, "stroke")
		else
			warn("[FigmaToRoblox] " .. el.Name .. ": _stroke needs an outline (Stroke) in Figma")
		end
	end
	if t.flow then
		-- a layer with children was imported with an FB_FlowGroup CanvasGroup: tint the whole group
		local target = el:FindFirstChild("FB_FlowGroup") or el
		local g = target:FindFirstChildWhichIsA("UIGradient")
		if not g or P(el, "flow", "Rainbow") then
			g = g or Instance.new("UIGradient")
			g.Color = rainbow(P(el, "flow", "Bands"))
			if target == el then
				if el.BackgroundTransparency < 1 then el.BackgroundColor3 = Color3.new(1, 1, 1) end
				if colorProp(el) ~= "BackgroundColor3" then el[colorProp(el)] = Color3.new(1, 1, 1) end
			end
			g.Parent = target
		end
		gradientLoop(g, "flow")
	end
	if t.bar then
		-- a fill layer that grows with a value: _bar:leaderstats.XP (Max or MaxPath in settings)
		local base = el.Size
		local up = P(el, "bar", "Direction") == "Up"
		local ap, pos = el.AnchorPoint, el.Position
		if up then
			el.AnchorPoint = Vector2.new(ap.X, 1)
			el.Position = pos + UDim2.new(0, 0, base.Y.Scale * (1 - ap.Y), base.Y.Offset * (1 - ap.Y))
		else
			el.AnchorPoint = Vector2.new(0, ap.Y)
			el.Position = pos - UDim2.new(base.X.Scale * ap.X, base.X.Offset * ap.X, 0, 0)
		end
		local shown
		task.spawn(function()
			while el.Parent do
				local v = tonumber(resolve(t.bar)) or 0
				local maxPath = P(el, "bar", "MaxPath")
				local mx = (maxPath ~= "" and tonumber(resolve(maxPath))) or P(el, "bar", "Max")
				local frac = math.clamp(v / math.max(mx, 1e-6), 0, 1)
				if frac ~= shown then
					shown = frac
					local size = up and UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale * frac, base.Y.Offset * frac)
						or UDim2.new(base.X.Scale * frac, base.X.Offset * frac, base.Y.Scale, base.Y.Offset)
					TweenService:Create(el, TweenInfo.new(P(el, "bar", "Time"), Enum.EasingStyle.Quint), { Size = size }):Play()
				end
				task.wait(0.25)
			end
		end)
	end
	if t.buy and el:IsA("GuiButton") then
		local MarketplaceService = game:GetService("MarketplaceService")
		el.Activated:Connect(function()
			local id = tonumber(t.buy)
			if not id then warn("[FigmaToRoblox] " .. el.Name .. ": _buy needs a number, e.g. _buy:12345") return end
			if P(el, "buy", "Type") == "GamePass" then MarketplaceService:PromptGamePassPurchase(player, id)
			else MarketplaceService:PromptProductPurchase(player, id) end
		end)
	end
	if t.focus then
		focusPanels[el] = true
		el:GetPropertyChangedSignal("Visible"):Connect(updateFocus)
	end
	if t.textbox and el:IsA("TextBox") == false then
		-- textbox tag on a frame: nothing to do at runtime; the importer created the TextBox child.
	end
end

---------------------------------------------------------------- boot
local all = gui:GetDescendants()
for _, d in all do
	local s = d:GetAttribute("FB_Tags")
	if s then TAGS[d] = parseTags(s) end
end
for el, t in TAGS do
	if t.panel then panels[el.Name] = el end
end
for el, t in TAGS do
	if t.tab then
		local g = ancestorWith(el, "tabgroup", false) or root
		tabGroups[g] = tabGroups[g] or {}
		table.insert(tabGroups[g], el)
	end
end
for el, t in TAGS do
	local ok, err = pcall(setup, el, t)
	if not ok then warn("[FigmaToRoblox] " .. el.Name .. ": " .. tostring(err)) end
end
for g, buttons in tabGroups do
	table.sort(buttons, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	local chosen = buttons[1]
	for _, b in buttons do
		local p = panels[TAGS[b].tab]
		if p and p.Visible then chosen = b break end
	end
	selectTab(g, chosen)
end
-- live text
for _, d in all do
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d:GetAttribute("FB_Template") then
		table.insert(liveTexts, d)
	end
end
-- always running so items added later by UI.Fill update too
task.spawn(function()
	while gui.Parent do
		for _, el in liveTexts do if el.Parent then refreshText(el) end end
		task.wait(0.25)
	end
end)
-- _prompt: the design only shows while its custom ProximityPrompt is in range
local promptOwner
for el, t in TAGS do if t.prompt then promptOwner = el end end
local adornee = (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) and gui.Adornee
local pp = adornee and adornee:FindFirstChildWhichIsA("ProximityPrompt")
if promptOwner and pp then
	gui.Enabled = false
	local holdToken = 0
	local function setFill(p)
		for _, stroke in holdStrokes do
			local g = stroke:FindFirstChild("FB_Hold") or Instance.new("UIGradient")
			g.Name = "FB_Hold"
			local e = math.clamp(p, 0.001, 0.998)
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(e, 0),
				NumberSequenceKeypoint.new(e + 0.001, 1), NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = stroke
		end
	end
	for el, stroke in holdStrokes do stroke.Color = P(el, "hold", "Color") end
	setFill(0)
	pp.PromptShown:Connect(function()
		gui.Enabled = true
		playEntrancesIn(root)
	end)
	pp.PromptHidden:Connect(function() gui.Enabled = false end)
	pp.PromptButtonHoldBegan:Connect(function()
		holdToken += 1
		local my = holdToken
		runTimed(math.max(pp.HoldDuration, 0.05), function(p) if my == holdToken then setFill(p) end end)
	end)
	pp.PromptButtonHoldEnded:Connect(function() holdToken += 1 setFill(0) end)
	pp.Triggered:Connect(function() holdToken += 1 setFill(0) end)
elseif promptOwner then
	warn("[FigmaToRoblox] _prompt: no ProximityPrompt found on the adornee part")
end

-- UI.Toast: small pill notifications that stack at the top of the screen
local toastBox
local function toast(text, seconds)
	if not gui:IsA("ScreenGui") then return end
	if not toastBox then
		toastBox = Instance.new("Frame")
		toastBox.Name = "FB_Toasts"
		toastBox.BackgroundTransparency = 1
		toastBox.AnchorPoint = Vector2.new(0.5, 0)
		toastBox.Position = UDim2.new(0.5, 0, 0, 64)
		toastBox.Size = UDim2.new(0.9, 0, 1, -64)
		toastBox.ZIndex = 10000
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = toastBox
		toastBox.Parent = gui
	end
	local pill = Instance.new("CanvasGroup")
	pill.Name = "FB_Toast"
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Size = UDim2.new()
	pill.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
	pill.BackgroundTransparency = 0.08
	pill.GroupTransparency = 1
	pill.LayoutOrder = os.clock() * 1000
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 18), UDim.new(0, 18), UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = pill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.RichText = true
	label.Text = tostring(text)
	label.Parent = pill
	local scale = Instance.new("UIScale") scale.Scale = 0.9 scale.Parent = pill
	pill.Parent = toastBox
	local fast = TweenInfo.new(0.25, Enum.EasingStyle.Quint)
	TweenService:Create(pill, fast, { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds or 2.5, function()
		TweenService:Create(pill, fast, { GroupTransparency = 1 }):Play()
		TweenService:Create(scale, fast, { Scale = 0.9 }):Play()
		task.wait(0.3)
		pill:Destroy()
	end)
end

-- UI.Open / UI.Close / UI.Toggle / UI.Toast / UI.Fill from the generated module
local command = gui:FindFirstChild("FB_Command")
if command then
	command.Event:Connect(function(action, name, extra)
		if action == "toast" then toast(name, extra) return end
		if action == "setup" then
			-- cloned items (UI.Fill) get their effects wired like the original
			if typeof(name) ~= "Instance" then return end
			local list = name:GetDescendants()
			table.insert(list, name)
			for _, d in list do
				local str = d:GetAttribute("FB_Tags")
				if str then
					TAGS[d] = parseTags(str)
					local ok, err = pcall(setup, d, TAGS[d])
					if not ok then warn("[FigmaToRoblox] " .. d.Name .. ": " .. tostring(err)) end
				end
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d:GetAttribute("FB_Template") then table.insert(liveTexts, d) end
			end
			return
		end
		local target = findTarget(nil, name)
		if not target then
			sendOther(action, name) -- maybe another imported UI has it
			return
		end
		if action == "open" then show(target)
		elseif action == "close" then hide(target)
		elseif action == "toggle" then if target.Visible then hide(target) else show(target) end end
	end)
end

-- a whole import tagged _panel (e.g. a Shop imported on its own) starts closed until something opens it
local top = root:FindFirstChildWhichIsA("GuiObject")
if top and ((TAGS[top] and TAGS[top].panel) or gui:GetAttribute("FB_StartHidden")) then setVisible(top, false) end

-- answer open/close/toggle requests from other imported UIs
local myBus = getBus()
if myBus then
	myBus.Event:Connect(function(action, name, from, id)
		if from == gui then return end
		local el = findTarget(id, name)
		if el then act(action, el) end
	end)
end

-- entrances for everything visible at start
playEntrancesIn(root)
updateFocus()
]==]
local DEFAULTS = (function()
-- Default settings per tag. The importer writes them as attributes named "<tag>_<Setting>"
-- on each tagged instance, so they can be tuned in Studio's Properties panel.
return {
	button = { Darken = 0.12, Time = 0.12 },
	grow = { Scale = 1.1, Time = 0.2, Style = "Smooth" },
	press = { Scale = 0.92, Time = 0.1, Style = "Bouncy" },
	sound = { Hover = "", Click = "", Volume = 0.5 },
	popout = { To = 0.6, Time = 0.22 },
	fadeout = { Time = 0.25 },
	dropout = { Distance = 60, Time = 0.3 },
	smooth = { HoverScale = 1.1, PressScale = 0.94, Time = 0.15, HoverSound = "", ClickSound = "" },
	up = { Lift = 6, Time = 0.15, Style = "Smooth" },
	turn = { Angle = 6, Time = 0.15 },
	squish = { Squash = 0.85, Time = 0.35 },
	ripple = { Color = Color3.new(1, 1, 1), Opacity = 0.35, Time = 0.5 },
	burst = { Count = 10, Distance = 70, Size = 8, Life = 0.55, Spin = 180, Color = Color3.fromRGB(255, 230, 120), Shape = "Circle", Icon = "" },
	magnet = { Strength = 0.25, Radius = 120 },
	select = { Color = Color3.fromRGB(255, 215, 0), Thickness = 3 },
	lean = { Angle = 12, Time = 0.15 },
	color = { HoverColor = Color3.fromRGB(255, 220, 120), Time = 0.15 },
	glint = { Time = 0.5 },
	card = { Delay = 0.15, Time = 0.15 },
	pop = { From = 0.6, Time = 0.45, Delay = 0, Style = "Bouncy" },
	fadein = { Time = 0.4, Delay = 0 },
	drop = { Height = 80, Time = 0.7, Delay = 0 },
	swing = { Angle = 14, Time = 1, Delay = 0 },
	cascade = { Step = 0.07, Time = 0.3, Distance = 12 },
	spin = { Speed = 90 },
	rays = { Speed = 20, Pulse = 0.05, Rate = 0.5 },
	pulse = { Amount = 0.06, Rate = 1.2 },
	float = { Distance = 6, Rate = 0.5, Angle = 0 },
	jelly = { Amount = 0.04, Rate = 1 },
	blink = { On = 1, Off = 0.5, Fade = 0.2, Delay = 0 },
	shake = { Distance = 4, Duration = 0.4, Every = 3 },
	wiggle = { Angle = 8, Duration = 0.5, Every = 3 },
	glow = { Color = Color3.fromRGB(255, 255, 255), Size = 14, Rate = 1 },
	reveal = { Angle = 10, From = 0.85, Time = 0.8, Delay = 0 },
	tilt3d = { Strength = 14, Depth = 0.25 },
	tilt = { X = 0, Y = 20 },
	pointer = { Time = 0.25, Hide = 0.4 },
	pixels = { Size = 8, Rate = 8, Color = Color3.new(1, 1, 1), Opacity = 0.35 },
	fall = { Count = 8, Speed = 60, MinSize = 0.5, MaxSize = 1 },
	drift = { SpeedX = 20, SpeedY = 0 },
	prompt = { Distance = 10, Hold = 0 },
	hold = { Color = Color3.new(1, 1, 1) },
	type = { Speed = 30, Delay = 0, Loop = false, Pause = 1.5 },
	sparkle = { Count = 6, MinSize = 8, MaxSize = 16, Life = 1.2, Spin = 90, Rise = 0, Color = Color3.new(1, 1, 1), Shape = "Star", Icon = "", Trigger = "Always" },
	shiny = { Time = 0.8, Pause = 1.5 },
	beam = { Speed = 60 },
	gleam = { Time = 0.8, Pause = 1.5, Color = Color3.new(1, 1, 1) },
	stroke = { Speed = 90, Mode = "Rotate" },
	flow = { Speed = 60, Mode = "Rotate", Bands = 2, Rainbow = false },
	bar = { Max = 100, MaxPath = "", Direction = "Right", Time = 0.3 },
	buy = { Type = "Product" },
	focus = { Blur = 12 },
	billboard = { Width = 6 },
	surface = { Width = 6 },
}

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
	if not ok then error("Cannot reach the FigmaToRoblox server (" .. tostring(res) .. "). Is it running?", 0) end
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
		"-- Generated by FigmaToRoblox. Re-importing rewrites this file, so keep your code in your own scripts.",
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
					Name = "FigmaToRoblox " .. string.sub(im.id, 1, 8),
					Description = "Uploaded by FigmaToRoblox",
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
local toolbar = plugin:CreateToolbar("FigmaToRoblox")
local toggleBtn = toolbar:CreateButton("FigmaToRoblox", "Import a Figma design by code", "rbxasset://textures/ui/GuiImagePlaceholder.png")
toggleBtn.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui("FigBridge",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 320, 400, 280, 340))
widget.Title = "FigmaToRoblox"
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
text(head, "FigmaToRoblox", 22, C.label, Enum.FontWeight.Bold, 1)
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
		local recording = ChangeHistoryService:TryBeginRecording("FigmaToRoblox import")
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
				"-- Your code for this UI. FigmaToRoblox keeps this script when you re-import.",
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
		for _, w in warnings do warn("[FigmaToRoblox] " .. w) end
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
