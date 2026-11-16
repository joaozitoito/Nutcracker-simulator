-- Pet followers: purely visual, built and moved on each client from replicated state. No physics, one update loop.
--   who has which pets  <- Player attribute "Inventory" (written by the server)
--   where they stand    <- behind their owner, or around the owner's assigned nut (Player attribute "TargetId")
--   when they lunge     <- Effects.onHit: a nut lost Health, i.e. the server confirmed a hit
-- Nothing here deals damage or grants anything.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PetConfig = require(Shared.PetConfig)
local PetModel = require(Shared.PetModel)
local Effects = require(script.Parent.Effects)

local Pets = {}

local WORLD_SCALE = 0.7 -- followers are smaller than the UI models
local FOLLOW_SPEED = 8 -- higher = snappier
local LUNGE_TIME = 0.3
local CULL_DISTANCE = 250 -- owners further than this from the camera are not animated

local owners = {} -- [Player] = { key = "TypeA,TypeB", pets = { { model, position, lungeAt } } }
local nutsById = {} -- [NutId] = Model
local folder

-- Slot i of n behind the owner, in the owner's space (+Z is behind, the character faces -Z).
local function formation(i: number, n: number): Vector3
	if n == 1 then
		return Vector3.new(0, 0, 5)
	end
	local row = math.floor((i - 1) / 3)
	local inRow = math.min(3, n - row * 3)
	local column = (i - 1) % 3
	local x = (column - (inRow - 1) / 2) * 4
	return Vector3.new(x, 0, 5 + row * 4 + (inRow == 3 and column == 1 and 1.6 or 0))
end

local function flat(v: Vector3): Vector3?
	local f = v * Vector3.new(1, 0, 1)
	return f.Magnitude > 0.05 and f.Unit or nil
end

local function rebuild(player: Player)
	local inventory = PetConfig.readInventory(player)
	local typeOf = {}
	for _, pet in inventory.pets do
		typeOf[pet.uid] = pet.type
	end
	local types = {}
	for _, uid in inventory.equipped do
		if PetConfig.Pets[typeOf[uid]] then
			table.insert(types, typeOf[uid])
		end
	end

	local key = table.concat(types, ",")
	local owner = owners[player]
	if owner and owner.key == key then
		return
	end
	if owner then
		for _, pet in owner.pets do
			pet.model:Destroy()
		end
	end
	local pets = {}
	for _, petType in types do
		local model = PetModel.build(PetConfig.Pets[petType].look, WORLD_SCALE)
		model.Name = petType
		model.Parent = folder
		table.insert(pets, { model = model })
	end
	owners[player] = { key = key, pets = pets }
end

local function update(dt: number)
	local now = os.clock()
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	local blend = 1 - math.exp(-FOLLOW_SPEED * dt)

	for player, owner in owners do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local count = #owner.pets
		if count == 0 or not root or not humanoid or (root.Position - cameraPosition).Magnitude > CULL_DISTANCE then
			continue -- no character (respawning): pets wait where they are and catch up when it is back
		end

		local rootPosition = root.Position
		local ground = rootPosition.Y - humanoid.HipHeight - root.Size.Y / 2
		local forward = flat(root.CFrame.LookVector) or -Vector3.zAxis
		local nut = nutsById[player:GetAttribute("TargetId")]

		for i, pet in owner.pets do
			local goal, face
			if nut then
				-- fan out around the nut on the owner's side, facing it
				local nutPosition = nut:GetPivot().Position
				local away = flat(rootPosition - nutPosition) or Vector3.zAxis
				local direction = CFrame.Angles(0, math.rad((i - (count + 1) / 2) * 44), 0) * away
				goal = nutPosition + direction * (2.4 * Config.Nuts[nut.Name].look.scale + 2.8)
				face = -direction
			else
				goal = (CFrame.lookAt(rootPosition, rootPosition + forward) * CFrame.new(formation(i, count))).Position
				goal = Vector3.new(goal.X, ground, goal.Z)
				face = forward
			end

			local position = pet.position
			if not position or (position - goal).Magnitude > 60 then
				position = goal -- first frame, or teleported / respawned far away: snap
			else
				position = position:Lerp(goal, blend)
			end
			pet.position = position

			local moving = (goal - position).Magnitude > 0.6
			local lift = moving and math.abs(math.sin(now * 11 + i * 1.7)) * 0.7 or (math.sin(now * 3 + i * 1.7) + 1) * 0.1
			local lunge = Vector3.zero
			if pet.lungeAt then
				local t = (now - pet.lungeAt) / LUNGE_TIME
				if t >= 1 then
					pet.lungeAt = nil
				elseif t > 0 then
					local k = math.sin(t * math.pi)
					lunge = face * k * 2
					lift += k * 0.9
				end
			end

			local look = moving and flat(goal - position) or face
			local at = position + lunge + Vector3.new(0, lift, 0)
			pet.model:PivotTo(CFrame.lookAt(at, at + look))
		end
	end
end

function Pets.start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace

	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal("Inventory"):Connect(function()
			rebuild(player)
		end)
		rebuild(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local owner = owners[player]
		owners[player] = nil
		if owner then
			for _, pet in owner.pets do
				pet.model:Destroy()
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	local nuts = workspace:WaitForChild("Nuts")
	local function index(model: Instance)
		local id = model:GetAttribute("NutId")
		if id then
			nutsById[id] = model
		end
	end
	nuts.ChildAdded:Connect(index)
	nuts.ChildRemoved:Connect(function(model)
		for id, indexed in nutsById do
			if indexed == model then
				nutsById[id] = nil
			end
		end
	end)
	for _, model in nuts:GetChildren() do
		index(model)
	end

	-- a nut took damage: every pet whose owner is assigned to that nut lunges, slightly staggered
	Effects.onHit(function(model)
		local id = model:GetAttribute("NutId")
		local now = os.clock()
		for player, owner in owners do
			if player:GetAttribute("TargetId") == id then
				for i, pet in owner.pets do
					pet.lungeAt = now + (i - 1) * 0.05
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return Pets
