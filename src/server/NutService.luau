-- Nuts: spawn, assign (click), automatic damage, break, reward, respawn. Everything here is server-side truth.
-- Clients only see the nut Models and their Health / MaxHealth / NutId attributes, and their own TargetId attribute.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local NutModel = require(script.Parent.NutModel)

local NutService = {}

local nuts = {} -- [id] = { id, def, point, position, health, model, damage = { [Player] = dealt } }
local targets = {} -- [Player] = nut id
local nextId = 0
local folder

local function rootPosition(player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return root.Position
	end
	return nil
end

local function setTarget(player, id: number?)
	targets[player] = id
	player:SetAttribute("TargetId", id or 0)
end

-- Attack units of a player: each entry is the damage of one unit, and every unit hits the target once per tick.
-- Today the player is the only unit. Equipped pets become extra entries here; assign/check/break stay untouched.
local function attackUnits(player): { number }
	return { PlayerData.strength(player) }
end

-- The one validation path for every attack: nut alive, player alive, close enough, strong enough.
local function check(player, id, range: number)
	local nut = nuts[id]
	if not nut then
		return nil, "gone"
	end
	local position = rootPosition(player)
	if not position then
		return nil, "dead"
	end
	if (position - nut.position).Magnitude > range then
		return nil, "far"
	end
	if PlayerData.strength(player) < nut.def.resistance then
		return nil, "weak"
	end
	return nut
end

local spawnNut

local function breakNut(nut)
	nuts[nut.id] = nil -- first, so nothing can hit or reward it twice

	local total = 0
	for _, dealt in nut.damage do
		total += dealt
	end
	for player, dealt in nut.damage do
		if player.Parent then
			-- shared nuts pay each player by their share of the damage
			local share = math.max(1, math.floor(nut.def.reward * dealt / total + 0.5))
			PlayerData.addCoins(player, share)
			Remotes.Notify:FireClient(player, "Reward", share, nut.position)
		end
	end

	nut.model:Destroy()
	task.delay(nut.def.respawn, spawnNut, nut.point)

	-- everyone on this nut is left without a target and has to pick the next one
	for player, id in targets do
		if id == nut.id then
			setTarget(player, nil)
		end
	end
end

-- returns true if the nut broke
local function hit(player, nut, damage: number): boolean
	local dealt = math.min(damage, nut.health)
	nut.health -= dealt
	nut.damage[player] = (nut.damage[player] or 0) + dealt
	if nut.health <= 0 then
		breakNut(nut)
		return true
	end
	nut.model:SetAttribute("Health", nut.health)
	return false
end

-- Click on a nut only ever (re)assigns. Damage comes from the tick loop, so clicking faster gains nothing.
local function onClick(player, id: number)
	if targets[player] == id then
		return
	end
	local nut, reason = check(player, id, Config.AssignRange)
	if nut then
		setTarget(player, id)
	elseif reason == "weak" then
		Remotes.Notify:FireClient(player, "Denied", `Too tough! Needs {nuts[id].def.resistance} Strength`)
	elseif reason == "far" then
		Remotes.Notify:FireClient(player, "Denied", "Get closer!")
	end
end

function spawnNut(point)
	nextId += 1
	local id = nextId
	local def = Config.Nuts[point.type]

	local model = NutModel.build(def.look)
	model.Name = point.type
	model:PivotTo(CFrame.new(point.position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	model:SetAttribute("NutId", id)
	model:SetAttribute("MaxHealth", def.health)
	model:SetAttribute("Health", def.health)

	-- ClickDetector covers mouse, touch and gamepad; its event already arrives on the server with the player.
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 64 -- real range is enforced in check() so we can tell the player "Get closer!"
	click.MouseClick:Connect(function(player)
		onClick(player, id)
	end)
	click.Parent = model

	nuts[id] = {
		id = id,
		def = def,
		point = point,
		position = point.position,
		health = def.health,
		model = model,
		damage = {},
	}
	model.Parent = folder
end

function NutService.start(spawnPoints)
	folder = Instance.new("Folder")
	folder.Name = "Nuts"
	folder.Parent = workspace

	for _, point in spawnPoints do
		spawnNut(point)
	end

	Players.PlayerRemoving:Connect(function(player)
		targets[player] = nil
	end)

	-- One global tick: a player gets at most one round of hits per tick no matter how often they click or retarget.
	task.spawn(function()
		while true do
			task.wait(Config.TickInterval)
			for player, id in targets do
				local ok, err = pcall(function()
					local nut = check(player, id, Config.LeashRange)
					if not nut then
						setTarget(player, nil) -- walked away, died, or the nut is gone
						return
					end
					for _, damage in attackUnits(player) do
						if hit(player, nut, damage) then
							break
						end
					end
				end)
				if not ok then
					warn("[NutService] tick failed:", err)
					setTarget(player, nil)
				end
			end
		end
	end)
end

return NutService
