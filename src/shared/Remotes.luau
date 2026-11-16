-- Single place where remotes are declared. Server creates them, client waits for them.
-- BuyStrength: client -> server, no arguments, returns { ok, reason? }
-- OpenEgg: client -> server, (eggId: string), returns { ok, reason?, pet? = { uid, type } }
-- EquipPet: client -> server, (uid: number, equip: boolean), returns { ok, reason? }
-- BuyUpgrade: client -> server, (upgradeId: string), returns { ok, reason? }
-- Rebirth: client -> server, no arguments, returns { ok, reason?, diamonds?, rebirths? }
-- Notify: server -> client, ("Reward", amount, position) | ("Denied", message) | ("Diamonds", amount, label)
local RunService = game:GetService("RunService")

local defs = {
	BuyStrength = "RemoteFunction",
	OpenEgg = "RemoteFunction",
	EquipPet = "RemoteFunction",
	BuyUpgrade = "RemoteFunction",
	Rebirth = "RemoteFunction",
	Notify = "RemoteEvent",
}
local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Net" -- not "Remotes": that is this ModuleScript's own name
	for name, class in defs do
		local remote = Instance.new(class)
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = script.Parent
else
	local folder = script.Parent:WaitForChild("Net")
	for name in defs do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
