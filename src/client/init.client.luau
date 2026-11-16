-- Client bootstrap. The client never decides anything: it shows server state and plays feedback.
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Effects = require(script.Effects)
local Hud = require(script.Hud)

Effects.start()
Hud.start()

Remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Reward" then
		Effects.reward(a, b)
	elseif kind == "Denied" then
		Hud.toast(a, Color3.fromRGB(255, 90, 90))
	end
end)
