-- Eggs and equipping. The client asks ("open this egg", "equip this uid"); price, odds, result and limits are decided here.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PetConfig = require(Shared.PetConfig)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local PetService = {}
local rng = Random.new()

function PetService.start()
	-- No yields anywhere below, so two requests arriving together are handled one after the other:
	-- the second one sees the coins already spent / the slot already taken.
	Remotes.OpenEgg.OnServerInvoke = function(player, eggId)
		local egg = type(eggId) == "string" and PetConfig.Eggs[eggId]
		if not egg or not egg.available then
			return { ok = false, reason = "invalid" }
		end
		if PlayerData.petCount(player) >= PetConfig.InventoryCapacity then
			return { ok = false, reason = "full" }
		end
		if not PlayerData.spend(player, egg.price) then
			return { ok = false, reason = "coins" }
		end
		-- the pet is in the inventory before the client is told anything: the animation is only a presentation
		local luck = Progression.luck(PlayerData.upgrades(player))
		local pet, isNew, milestones = PlayerData.addPet(player, PetConfig.rollPet(eggId, rng:NextNumber(), luck))
		for _, milestone in milestones or {} do
			Remotes.Notify:FireClient(player, "Collection", milestone.species, milestone.coins, milestone.diamonds)
		end
		local diamonds = PlayerData.grantOnce(player, "FirstPet")
		if diamonds > 0 then
			Remotes.Notify:FireClient(player, "Diamonds", diamonds, Progression.OneTimeRewards.FirstPet.label)
		end
		return { ok = true, pet = pet, isNew = isNew }
	end

	Remotes.EquipPet.OnServerInvoke = function(player, uid, equip)
		if type(uid) ~= "number" or uid ~= uid or type(equip) ~= "boolean" then
			return { ok = false, reason = "invalid" }
		end
		local ok, reason = PlayerData.setEquipped(player, uid, equip)
		return { ok = ok, reason = reason }
	end
end

return PetService
