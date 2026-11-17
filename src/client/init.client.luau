-- Client bootstrap. The client never decides anything: it shows server state and plays feedback.
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Ui = require(script.Ui)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Pets = require(script.Pets)
local PetsUi = require(script.PetsUi)
local ProgressionUi = require(script.ProgressionUi)
local IndexUi = require(script.IndexUi)
local HammerUi = require(script.HammerUi)

Effects.start()
Hud.start()
Pets.start()
PetsUi.start() -- after Hud: it adds its buttons and panels to the HUD
ProgressionUi.start()
IndexUi.start()
HammerUi.start()

-- dev showcase of the image-based Ui pieces; separate ScreenGui, hidden until asked for, never in a published game
if game:GetService("RunService"):IsStudio() then
	require(script.ForgeDemo).start()
end

Remotes.Notify.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Reward" then
		Effects.reward(a, b)
		Hud.reward(a, b)
	elseif kind == "Diamonds" then
		Effects.play("buy")
		Hud.toast(`+{a} Diamonds  •  {b}`, Color3.fromRGB(60, 190, 230))
	elseif kind == "Collection" then
		IndexUi.reward(a, b, c)
	elseif kind == "Denied" then
		Effects.play("deny")
		Hud.toast(a, Ui.Color.red)
	end
end)
