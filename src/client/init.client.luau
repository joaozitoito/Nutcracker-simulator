-- Client bootstrap. The client never decides anything: it shows server state and plays feedback.
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Ui = require(script.Ui)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Pets = require(script.Pets)
local PetsUi = require(script.PetsUi)

Effects.start()
Hud.start()
Pets.start()
PetsUi.start() -- after Hud: it adds its buttons and panels to the HUD

Remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Reward" then
		Effects.reward(a, b)
		Hud.reward(a, b)
	elseif kind == "Denied" then
		Effects.play("deny")
		Hud.toast(a, Ui.Color.red)
	end
end)
