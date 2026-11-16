-- External image assets (uploaded to Roblox). This is the only place asset ids live: components read from here.
--
-- Measurements are in the pixels of the ORIGINAL generated file, because that is what we can measure before upload.
-- Roblox shrinks uploaded images so the longest side is at most 1024; `Assets.textureScale` converts to texture pixels.
--   source = original file size
--   rect   = { x0, y0, x1, y1 } of the painted area (the files have wide transparent margins)
--   slice  = 9-slice centre as fractions of `rect` { left, top, right, bottom }; only for stretchable pieces
local Assets = {}

Assets.Images = {
	-- ForgeGUI, blank green button with highlight band and darker lip. Text is added by the game, never baked in.
	ButtonGreen = {
		id = "rbxassetid://134086932952272",
		source = Vector2.new(1672, 941),
		rect = { 127, 254, 1544, 688 },
		slice = { 0.12, 0.4, 0.88, 0.6 },
	},
	-- ForgeGUI, golden acorn coin.
	CoinAcorn = {
		id = "rbxassetid://87878445232429",
		source = Vector2.new(1402, 1122),
		rect = { 336, 71, 1067, 993 },
	},
}

-- original pixels -> pixels of the texture Roblox actually serves
function Assets.textureScale(image): number
	return math.min(1, 1024 / math.max(image.source.X, image.source.Y))
end

-- width / height of the painted area
function Assets.aspect(image): number
	local r = image.rect
	return (r[3] - r[1]) / (r[4] - r[2])
end

return Assets
