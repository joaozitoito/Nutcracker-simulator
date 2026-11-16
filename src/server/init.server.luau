-- Server bootstrap. Order matters: map gives the nut spawn points.
require(script.SelfCheck)()
local spawnPoints = require(script.MapBuilder).build()
require(script.PlayerData).start()
require(script.NutService).start(spawnPoints)
require(script.ShopService).start()
require(script.PetService).start()
require(script.ProgressionService).start()

-- Dev tool, Studio only: set the Workspace attribute "DevCoins" from the server command bar to give everyone coins.
-- Clients cannot write server attributes, and this never runs in a published game.
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("DevCoins"):Connect(function()
		local amount = workspace:GetAttribute("DevCoins")
		if type(amount) == "number" and amount ~= 0 then
			for _, player in game:GetService("Players"):GetPlayers() do
				require(script.PlayerData).addCoins(player, amount)
			end
			workspace:SetAttribute("DevCoins", 0)
		end
	end)
	-- "DevPet" = pet type id gives everyone that pet through PlayerData.addPet (discovery and milestones included)
	workspace:GetAttributeChangedSignal("DevPet"):Connect(function()
		local petType = workspace:GetAttribute("DevPet")
		if type(petType) == "string" and petType ~= "" then
			local Notify = require(game:GetService("ReplicatedStorage").Shared.Remotes).Notify
			for _, player in game:GetService("Players"):GetPlayers() do
				local _, _, milestones = require(script.PlayerData).addPet(player, petType)
				for _, milestone in milestones or {} do
					Notify:FireClient(player, "Collection", milestone.species, milestone.coins, milestone.diamonds)
				end
			end
			workspace:SetAttribute("DevPet", "")
		end
	end)
	-- same for diamonds: "DevDiamonds"
	workspace:GetAttributeChangedSignal("DevDiamonds"):Connect(function()
		local amount = workspace:GetAttribute("DevDiamonds")
		if type(amount) == "number" and amount > 0 then
			for _, player in game:GetService("Players"):GetPlayers() do
				require(script.PlayerData).addDiamonds(player, amount, "dev")
			end
			workspace:SetAttribute("DevDiamonds", 0)
		end
	end)
end
