-- Hammers of EVERY player, drawn on each client from replicated state (same idea as Pets.luau for pets).
-- Nothing here is authoritative: no damage, no rewards, no requests. Inputs, all written by the server:
--   Player attribute "HammerTier"  -> which model (Shared.HammerModel)
--   Player attribute "TargetId"    -> carried on the back (0) or beside that nut (any other id)
--   Effects.onHit(nut)             -> a nut lost Health, i.e. a hit the server confirmed: swing + impact
--
-- Per player there is one rig { model, tier, mode, nut, grip, scale, swing, swinging, connections }.
-- Rigs are made on PlayerAdded (and for players already in the game) and torn down on PlayerRemoving.
-- Tier / target / respawn changes are handled by events; the only per-frame work is keeping carried hammers on the
-- moving characters' backs (anchored parts, no physics), skipped for characters far from the camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local HammerModel = require(Shared.HammerModel)
local Hammers = require(Shared.Hammers)
local Effects = require(script.Parent.Effects)

local PlayerHammers = {}

local CARRY_SCALE = 0.55
local HEAD_HEIGHT = 5.2 -- head centre in HammerModel space
local REST, STRIKE = math.rad(15), math.rad(78)
local CULL_DISTANCE = 200 -- hammers / impacts further than this from the camera are not drawn

local rigs = {} -- [Player] = rig
local folder

local function nutById(id: number?): Model?
	local nuts = workspace:FindFirstChild("Nuts")
	if not nuts or not id or id == 0 then
		return nil
	end
	for _, nut in nuts:GetChildren() do
		if nut:GetAttribute("NutId") == id then
			return nut
		end
	end
	return nil
end

local function alive(owner: Player): (Model?, BasePart?)
	local character = owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if not torso or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return character, torso
end

-- grip low on the left of the back, head over the right shoulder
local function carryCFrame(owner: Player): CFrame?
	local _, torso = alive(owner)
	return torso and torso.CFrame * CFrame.new(-0.7, -1.1, 0.75) * CFrame.Angles(0, 0, math.rad(-38)) or nil
end

local function build(rig)
	local old = rig.model
	rig.tier = math.clamp(rig.owner:GetAttribute("HammerTier") or 1, 1, #Hammers.Tiers)
	rig.model = HammerModel.build(rig.tier)
	rig.model.Name = rig.owner.Name
	if old then
		old:Destroy() -- one model per player, whatever happens to the tier
	end
end

-- Puts the hammer where the owner's state says it belongs. Called on every state change, never per frame.
local function place(rig)
	local nut = nutById(rig.owner:GetAttribute("TargetId"))
	local character = alive(rig.owner)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not nut or not root then
		rig.mode, rig.nut, rig.grip = "carry", nil, nil
		rig.model:ScaleTo(CARRY_SCALE)
		return -- the frame step parents and moves it while carried
	end
	rig.mode, rig.nut = "nut", nut
	local s = Config.Nuts[nut.Name].look.scale
	rig.scale = s
	-- beside the nut, on the owner's right as they face it, swinging down onto it
	local nutPosition = nut:GetPivot().Position
	local toOwner = (root.Position - nutPosition) * Vector3.new(1, 0, 1)
	toOwner = toOwner.Magnitude > 0.05 and toOwner.Unit or Vector3.zAxis
	local side = (-toOwner):Cross(Vector3.yAxis)
	local top = nutPosition + Vector3.new(0, 5.4 * s, 0)
	-- local X = side, so rotating about local Z swings the head (local +Y) down towards the nut
	rig.grip = CFrame.fromMatrix(top + side * 4.6 * s - Vector3.new(0, 1.1 * s, 0), side, Vector3.yAxis)
	rig.model:ScaleTo(s)
	rig.swing.Value = REST
	rig.model:PivotTo(rig.grip * CFrame.Angles(0, 0, REST))
	rig.model.Parent = folder
end

local function nearCamera(position: Vector3): boolean
	return (position - workspace.CurrentCamera.CFrame.Position).Magnitude <= CULL_DISTANCE
end

-- One confirmed hit by this rig's owner on `nut`: slam down, impact in the owner's tier style, come back up.
-- A swing already in progress absorbs extra hits, so a fast attack speed never stacks animations or effects.
local function strike(rig, nut: Model)
	if rig.mode ~= "nut" or rig.nut ~= nut or rig.swinging or not rig.model.Parent then
		return
	end
	rig.swinging = true
	local down = game:GetService("TweenService"):Create(rig.swing, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = STRIKE })
	down.Completed:Once(function()
		if rig.grip and rig.mode == "nut" then
			local at = (rig.grip * CFrame.Angles(0, 0, STRIKE) * CFrame.new(0, HEAD_HEIGHT * rig.scale, 0)).Position
			if nearCamera(at) then
				Effects.impact(at, rig.scale, rig.tier)
			end
		end
		local up = game:GetService("TweenService"):Create(rig.swing, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Value = REST })
		up.Completed:Once(function()
			rig.swinging = false
		end)
		up:Play()
	end)
	down:Play()
end

local function add(owner: Player)
	if rigs[owner] then
		return
	end
	local rig = { owner = owner, swing = Instance.new("NumberValue"), connections = {}, mode = "carry", scale = 1 }
	rigs[owner] = rig
	build(rig)
	place(rig)
	local function on(signal, callback)
		table.insert(rig.connections, signal:Connect(callback))
	end
	on(owner:GetAttributeChangedSignal("HammerTier"), function()
		build(rig)
		place(rig)
	end)
	on(owner:GetAttributeChangedSignal("TargetId"), function()
		place(rig)
	end)
	on(owner.CharacterAdded, function()
		place(rig) -- new character after respawn: back to carrying (the server also clears the target)
	end)
	on(rig.swing.Changed, function(angle)
		if rig.mode == "nut" and rig.grip and rig.model.Parent then
			rig.model:PivotTo(rig.grip * CFrame.Angles(0, 0, angle))
		end
	end)
end

local function remove(owner: Player)
	local rig = rigs[owner]
	if not rig then
		return
	end
	rigs[owner] = nil
	for _, connection in rig.connections do
		connection:Disconnect()
	end
	rig.model:Destroy()
	rig.swing:Destroy()
end

local function step()
	for owner, rig in rigs do
		if rig.mode == "carry" then
			local cframe = carryCFrame(owner)
			if cframe and nearCamera(cframe.Position) then
				rig.model:PivotTo(cframe)
				if rig.model.Parent ~= folder then
					rig.model.Parent = folder
				end
			elseif rig.model.Parent then
				rig.model.Parent = nil -- dead, respawning, not loaded yet, or far away
			end
		elseif not rig.nut or not rig.nut.Parent then
			place(rig) -- the nut vanished before the target change arrived: never leave the hammer hanging there
		end
	end
end

function PlayerHammers.start()
	folder = Instance.new("Folder")
	folder.Name = "Hammers"
	folder.Parent = workspace

	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(remove)
	for _, owner in Players:GetPlayers() do
		add(owner)
	end

	Effects.onHit(function(nut)
		local id = nut:GetAttribute("NutId")
		for owner, rig in rigs do
			if owner:GetAttribute("TargetId") == id then
				strike(rig, nut)
			end
		end
	end)

	RunService.RenderStepped:Connect(step)
end

-- Number of hammer rigs and of hammer models currently in the world (used by tests / debugging).
function PlayerHammers.count(): (number, number)
	local total = 0
	for _ in rigs do
		total += 1
	end
	return total, folder and #folder:GetChildren() or 0
end

return PlayerHammers
