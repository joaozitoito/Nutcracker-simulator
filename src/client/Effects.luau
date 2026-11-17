-- World feedback: nut pop-in, squash on hit, damage numbers, hammer impacts, break burst, reward popups, highlight, sounds.
-- Everything is driven by replicated state (Nuts folder + attributes), so it also shows other players' hits.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Hammers = require(Shared.Hammers)
local Ui = require(script.Parent.Ui)

local Effects = {}

local player = Players.LocalPlayer

-- shortcut: placeholder sounds from the Roblox install, swap for real SFX assets when audio direction exists
local SOUNDS = {
	hit = { "rbxasset://sounds/action_jump_land.mp3", 1.7, 0.4 },
	crack = { "rbxasset://sounds/impact_explosion_03.mp3", 2, 0.25 },
	ui = { "rbxasset://sounds/volume_slider.ogg", 1, 0.6 },
	buy = { "rbxasset://sounds/volume_slider.ogg", 1.5, 0.8 },
	deny = { "rbxasset://sounds/volume_slider.ogg", 0.6, 0.7 },
}
local sounds = {}
-- "hit" pitch per hammer tier: same placeholder sound, deeper for heavier hammers
local HIT_PITCH = { 1.8, 1.6, 1.4, 1.2, 1.0 }

function Effects.play(name: string, speed: number?)
	local sound = sounds[name]
	if not sound then
		local def = SOUNDS[name]
		sound = Instance.new("Sound")
		sound.SoundId = def[1]
		sound.PlaybackSpeed = def[2]
		sound.Volume = def[3]
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound.PlaybackSpeed = speed or SOUNDS[name][2]
	SoundService:PlayLocalSound(sound)
end

local function fxPart(size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	for key, value in props or {} do
		(part :: any)[key] = value
	end
	return part
end

-- Text that pops in above a world position, drifts up and fades. `coin` adds a coin icon after the text.
local function floatText(position: Vector3, text: string, color: Color3, size: number, coin: boolean?)
	local anchor = fxPart(Vector3.one, CFrame.new(position), Color3.new(), { Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 70)
	gui.AlwaysOnTop = true
	local label = Ui.text({ Text = text, TextSize = size, TextColor3 = color, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = Ui.make("UIScale", { Scale = 0.3, Parent = label })
	local icon
	if coin then
		label.TextXAlignment = Enum.TextXAlignment.Right
		icon = Ui.coin(36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 6 + #text * size * 0.2, 0.5, 0), Parent = gui })
		label.Size = UDim2.new(0.5, #text * size * 0.2, 1, 0)
	end
	gui.Parent = anchor
	anchor.Parent = workspace

	Ui.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	Ui.tween(anchor, 0.9, { Position = position + Vector3.new(0, 5, 0) })
	local fade = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.6)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(label.UIStroke, fade, { Transparency = 1 }):Play()
	if icon then
		task.delay(0.75, icon.Destroy, icon)
	end
	Debris:AddItem(anchor, 1)
end

function Effects.reward(amount: number, position: Vector3)
	floatText(position + Vector3.new(0, 7, 0), `+{Format(amount)}`, Ui.Color.gold, 40, true)
	Effects.play("ui")
end

---------------------------------------------------------------- nut animation
-- scale animation through one NumberValue per nut, so overlapping hits don't fight
local scales = {} -- [Model] = NumberValue

local function pop(model: Model, from: number, duration: number)
	local value = scales[model]
	if value then
		value.Value = from
		Ui.tween(value, duration, { Value = 1 }, Enum.EasingStyle.Back)
	end
end

local function burst(model: Model)
	local look = Config.Nuts[model.Name].look
	local base = model:GetPivot().Position
	local origin = base + Vector3.new(0, 2.5 * look.scale, 0)

	-- shell shards
	for _ = 1, 10 do
		local shard = fxPart(
			Vector3.one * (0.6 + math.random()) * look.scale,
			CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			math.random() < 0.5 and look.body or look.cap,
			{ Anchored = false }
		)
		shard.Parent = workspace
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(28, 48), math.random(-20, 20))
		shard.AssemblyAngularVelocity = Vector3.new(math.random(-9, 9), math.random(-9, 9), math.random(-9, 9))
		Debris:AddItem(shard, 0.9)
	end

	-- white flash that swells and fades
	local flash = fxPart(Vector3.one * 3 * look.scale, CFrame.new(origin), Color3.new(1, 1, 1), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	flash.Parent = workspace
	Ui.tween(flash, 0.25, { Size = Vector3.one * 9 * look.scale, Transparency = 1 })
	Debris:AddItem(flash, 0.3)

	-- shockwave ring on the ground
	local ring = fxPart(
		Vector3.new(0.3, 4, 4) * look.scale,
		CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		look.body:Lerp(Color3.new(1, 1, 1), 0.5),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.3 }
	)
	ring.Parent = workspace
	Ui.tween(ring, 0.45, { Size = Vector3.new(0.3, 18, 18) * look.scale, Transparency = 1 })
	Debris:AddItem(ring, 0.5)

	Effects.play("crack")
end

---------------------------------------------------------------- hammer impact
-- The hammers themselves (one per player, carried / swinging) live in PlayerHammers.luau, which calls this when a
-- hammer lands a server-confirmed hit. Every client runs it for every player's hits, so everyone sees every impact.
-- Impact of one confirmed hit in the style of hammer tier `tier` (Hammers.Tiers[n].fx), `s` = nut scale.
-- At most ~11 short-lived parts per hit, all removed by Debris within a second.
function Effects.impact(at: Vector3, s: number, tier: number)
	local fx = Hammers.Tiers[math.clamp(tier, 1, #Hammers.Tiers)].fx
	local up = Vector3.yAxis

	-- shock ring flat on the impact point
	local ring = fxPart(Vector3.new(0.2, 1, 1) * s, CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), fx.ring, {
		Shape = Enum.PartType.Cylinder,
		Material = fx.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Transparency = 0.25,
	})
	ring.Parent = workspace
	Ui.tween(ring, 0.3, { Size = Vector3.new(0.2, fx.ringSize, fx.ringSize) * s, Transparency = 1 })
	Debris:AddItem(ring, 0.35)
	if fx.light then
		local light = Instance.new("PointLight")
		light.Color = fx.light
		light.Range = 12 * s
		light.Brightness = 4
		light.Parent = ring
		Ui.tween(light, 0.3, { Brightness = 0 })
	end
	if fx.flash then
		local flash = fxPart(Vector3.one * s, CFrame.new(at), fx.colors[1], { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.2 })
		flash.Parent = workspace
		Ui.tween(flash, 0.25, { Size = Vector3.one * 5 * s, Transparency = 1 })
		Debris:AddItem(flash, 0.3)
	end

	for i = 1, fx.pieces do
		local color = fx.colors[(i - 1) % #fx.colors + 1]
		local size = fx.size * s * (0.7 + math.random() * 0.6)
		local angle = (i / fx.pieces + math.random() * 0.15) * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local shape = fx.shape == "leaf" and Vector3.new(size * 1.6, size * 0.15, size) or Vector3.one * size
		local piece = fxPart(shape, CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), color, {
			Shape = (fx.shape == "blob" or fx.shape == "star") and Enum.PartType.Ball or Enum.PartType.Block,
			Material = fx.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
		if fx.motion == "fall" then
			piece.Anchored = false
			piece.Parent = workspace
			piece.AssemblyLinearVelocity = (out * math.random(8, 16) + up * math.random(14, 24)) * math.sqrt(s)
			piece.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			Debris:AddItem(piece, 0.7)
		elseif fx.motion == "drift" then
			piece.Parent = workspace
			local goal = at + (out * 3 + up * 0.5) * s
			Ui.tween(piece, 0.8, { Position = goal - up * 1.5 * s, Orientation = piece.Orientation + Vector3.new(0, 180, 90), Transparency = 1 }, Enum.EasingStyle.Sine)
			Debris:AddItem(piece, 0.85)
		else -- "burst"
			piece.Parent = workspace
			Ui.tween(piece, 0.35, { Position = at + (out * math.random(30, 50) / 10 + up * math.random(0, 20) / 10) * s, Size = Vector3.one * 0.05 })
			Debris:AddItem(piece, 0.4)
		end
	end
end

-- Other modules (pet followers) react to server-confirmed hits through this; callback(model) runs once per Health drop.
local hitListeners = {}
function Effects.onHit(callback: (Model) -> ())
	table.insert(hitListeners, callback)
end

---------------------------------------------------------------- tracking
local function track(model: Instance, animate: boolean)
	if not model:IsA("Model") then
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = 1
	value.Changed:Connect(function(scale)
		if model.Parent then
			model:ScaleTo(math.max(scale, 0.05))
		end
	end)
	scales[model] = value
	if animate then
		pop(model, 0.2, 0.4)
	end

	local last = model:GetAttribute("Health")
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		local dealt = last - health
		last = health
		if dealt <= 0 then
			return
		end
		pop(model, 0.84, 0.22)
		for _, callback in hitListeners do
			task.spawn(callback, model)
		end
		local s = Config.Nuts[model.Name].look.scale
		local mine = model:GetAttribute("NutId") == player:GetAttribute("TargetId")
		floatText(
			model:GetPivot().Position + Vector3.new(math.random(-20, 20) / 10 * s, 6.5 * s, math.random(-20, 20) / 10 * s),
			`-{Format(dealt)}`,
			mine and Color3.new(1, 1, 1) or Color3.fromRGB(200, 200, 215),
			mine and 32 or 22
		)
		if mine then
			local tier = math.clamp(player:GetAttribute("HammerTier") or 1, 1, #Hammers.Tiers)
			Effects.play("hit", HIT_PITCH[tier])
		end
	end)
end

function Effects.start()
	local nuts = workspace:WaitForChild("Nuts")
	for _, model in nuts:GetChildren() do
		track(model, false)
	end
	nuts.ChildAdded:Connect(function(model)
		-- attributes are set before parenting on the server, but wait a frame so the whole model has replicated
		task.defer(track, model, true)
	end)
	nuts.ChildRemoved:Connect(function(model)
		if scales[model] then
			scales[model]:Destroy()
			scales[model] = nil
			burst(model)
		end
	end)

	-- outline on the assigned nut
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace
	local function retarget()
		local model = Effects.targetModel()
		highlight.Adornee = model
		if model then
			-- selection flash: fill starts bright and settles
			highlight.FillTransparency = 0.2
			Ui.tween(highlight, 0.35, { FillTransparency = 0.8 })
			pop(model, 1.12, 0.3)
		end
	end
	player:GetAttributeChangedSignal("TargetId"):Connect(retarget)
	retarget()
end

-- The nut Model the server says we are assigned to, if any.
function Effects.targetModel(): Model?
	local id = player:GetAttribute("TargetId")
	local nuts = workspace:FindFirstChild("Nuts")
	if not id or id == 0 or not nuts then
		return nil
	end
	for _, model in nuts:GetChildren() do
		if model:GetAttribute("NutId") == id then
			return model
		end
	end
	return nil
end

return Effects
