-- World feedback: nut pop-in, squash on hit, damage numbers, shell burst on break, reward popups, target highlight, sounds.
-- Everything is driven by replicated state (Nuts folder + attributes), so it also shows other players' hits.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Effects = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(40, 30, 60)

-- shortcut: placeholder sounds from the Roblox install, swap for real SFX assets when audio direction exists
local SOUNDS = {
	hit = { "rbxasset://sounds/action_jump_land.mp3", 1.7, 0.4 },
	crack = { "rbxasset://sounds/impact_explosion_03.mp3", 2, 0.25 },
	ui = { "rbxasset://sounds/volume_slider.ogg", 1, 0.6 },
}
local sounds = {}

function Effects.play(name: string)
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
	SoundService:PlayLocalSound(sound)
end

local function floatText(position: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = OUTLINE
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = anchor
	anchor.Parent = workspace

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.5), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.5), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.9)
end

function Effects.reward(amount: number, position: Vector3)
	floatText(position + Vector3.new(0, 6, 0), `+{Format(amount)} Coins`, Color3.fromRGB(255, 215, 60), 34)
	Effects.play("ui")
end

-- scale animation through one NumberValue per nut, so overlapping hits don't fight
local scales = {} -- [Model] = NumberValue

local function pop(model: Model, from: number, duration: number)
	local value = scales[model]
	if not value then
		return
	end
	value.Value = from
	TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
end

local function burst(model: Model)
	local def = Config.Nuts[model.Name]
	local origin = model:GetPivot().Position + Vector3.new(0, 2, 0)
	for _ = 1, 10 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.one * (0.6 + math.random()) * def.look.scale
		shard.Color = math.random() < 0.5 and def.look.body or def.look.cap
		shard.Material = Enum.Material.SmoothPlastic
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		shard.Parent = workspace
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(25, 45), math.random(-18, 18))
		Debris:AddItem(shard, 0.8)
	end
	Effects.play("crack")
end

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
		if dealt > 0 then
			pop(model, 0.86, 0.2)
			local top = model:GetPivot().Position + Vector3.new(math.random(-2, 2), 6 * Config.Nuts[model.Name].look.scale, 0)
			floatText(top, `-{Format(dealt)}`, Color3.new(1, 1, 1), 26)
			if model:GetAttribute("NutId") == player:GetAttribute("TargetId") then
				Effects.play("hit")
			end
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
	highlight.FillTransparency = 0.75
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace
	local function retarget()
		highlight.Adornee = Effects.targetModel()
	end
	player:GetAttributeChangedSignal("TargetId"):Connect(retarget)
	nuts.ChildAdded:Connect(retarget)
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
