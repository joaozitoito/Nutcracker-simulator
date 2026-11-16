-- Builds the first area ("Acorn Meadow") from Parts at server start and returns where nuts should spawn.
-- Layout (top view, +Z is south): spawn plaza -> title arch -> field with 3 colour bands -> locked gate to the next area.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local NutModel = require(script.Parent.NutModel)

local MapBuilder = {}

local FONT = Enum.Font.FredokaOne
local C = {
	path = Color3.fromRGB(214, 222, 240),
	pathDark = Color3.fromRGB(176, 186, 214),
	cream = Color3.fromRGB(250, 236, 200),
	sea = Color3.fromRGB(70, 170, 255),
	wood = Color3.fromRGB(176, 116, 66),
	darkWood = Color3.fromRGB(112, 70, 44),
	stone = Color3.fromRGB(186, 190, 208),
	steel = Color3.fromRGB(150, 155, 175),
	hedge = Color3.fromRGB(70, 170, 70),
	white = Color3.fromRGB(255, 255, 255),
	red = Color3.fromRGB(235, 70, 70),
	gold = Color3.fromRGB(255, 200, 40),
	flame = Color3.fromRGB(255, 150, 30),
	outline = Color3.fromRGB(43, 29, 61),
}
local LEAVES = {
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(230, 80, 50),
	Color3.fromRGB(120, 200, 80),
}
local FLOWERS = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 70), Color3.fromRGB(150, 130, 255) }

-- Field: x in [-45, 45], z in [-70, 40]. Bands go from the spawn side (south) to the gate (north).
local FIELD_X = 45
local ZONES = {
	{ name = "ACORN MEADOW", color = Color3.fromRGB(126, 217, 87), z0 = 5, z1 = 40 },
	{ name = "WALNUT GROVE", color = Color3.fromRGB(255, 176, 59), z0 = -32, z1 = 5 },
	{ name = "GOLDEN GROVE", color = Color3.fromRGB(171, 130, 255), z0 = -70, z1 = -32 },
}
local GATE_Z = -80

local map
local rng = Random.new(7) -- fixed seed: same map every server

local function block(size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		part[key] = value
	end
	part.Parent = map
	return part
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local DECOR = { CanCollide = false, CastShadow = false }

-- vertical cylinder standing on (x, y, z)
local function pillar(x: number, y: number, z: number, height: number, diameter: number, color: Color3, props: { [string]: any }?)
	local part = block(Vector3.new(height, diameter, diameter), at(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function blob(size: Vector3, cframe: CFrame, color: Color3)
	local part = block(size, cframe, color, DECOR)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.2
	light.Parent = part
end

-- board with text on its front, framed by a darker back plate; `facing` is the direction the text looks at
local function sign(text: string, position: Vector3, facing: Vector3, size: Vector2, color: Color3)
	local cframe = CFrame.lookAt(position, position + facing)
	block(Vector3.new(size.X + 1, size.Y + 1, 0.5), cframe * CFrame.new(0, 0, 0.3), color:Lerp(C.outline, 0.45))
	local board = block(Vector3.new(size.X, size.Y, 0.6), cframe, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = C.white
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = C.outline
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = board
	return board
end

local function roundTree(x: number, z: number, scale: number, leaf: Color3)
	pillar(x, 0, z, 7 * scale, 2.2 * scale, C.darkWood)
	blob(Vector3.new(11, 9, 11) * scale, at(x, 10 * scale, z), leaf)
	blob(Vector3.new(8, 7, 8) * scale, at(x + 2.5 * scale, 14 * scale, z - 1.5 * scale), leaf:Lerp(C.white, 0.15))
	blob(Vector3.new(7, 6, 7) * scale, at(x - 3 * scale, 13 * scale, z + 2 * scale), leaf:Lerp(C.outline, 0.1))
end

local function pineTree(x: number, z: number, scale: number)
	local green = Color3.fromRGB(60, 160, 90)
	pillar(x, 0, z, 5 * scale, 1.8 * scale, C.darkWood)
	blob(Vector3.new(11, 7, 11) * scale, at(x, 7 * scale, z), green)
	blob(Vector3.new(8.5, 6, 8.5) * scale, at(x, 11 * scale, z), green:Lerp(C.white, 0.1))
	blob(Vector3.new(5.5, 5.5, 5.5) * scale, at(x, 14.5 * scale, z), green:Lerp(C.white, 0.22))
end

local function tree(x: number, z: number, scale: number)
	if rng:NextNumber() < 0.25 then
		pineTree(x, z, scale)
	else
		roundTree(x, z, scale, LEAVES[rng:NextInteger(1, #LEAVES)])
	end
end

local function mushroom(x: number, z: number, scale: number)
	pillar(x, 0, z, 3 * scale, 1.6 * scale, Color3.fromRGB(245, 235, 215))
	blob(Vector3.new(6, 3.4, 6) * scale, at(x, 3.6 * scale, z), C.red)
	blob(Vector3.new(1.4, 0.8, 1.4) * scale, at(x + 1.2 * scale, 5 * scale, z + 0.8 * scale), C.white)
	blob(Vector3.new(1.1, 0.7, 1.1) * scale, at(x - 1.4 * scale, 4.8 * scale, z - 0.6 * scale), C.white)
end

local function flowers(x: number, z: number)
	local color = FLOWERS[rng:NextInteger(1, #FLOWERS)]
	for _ = 1, 3 do
		local fx, fz = x + rng:NextNumber(-1.6, 1.6), z + rng:NextNumber(-1.6, 1.6)
		blob(Vector3.new(1.3, 0.7, 1.3), at(fx, 0.45, fz), color)
		blob(Vector3.new(0.5, 0.6, 0.5), at(fx, 0.75, fz), C.gold)
	end
end

local function lantern(x: number, y: number, z: number)
	block(Vector3.new(0.3, 1.2, 0.3), at(x, y + 1.2, z), C.outline, DECOR)
	local lamp = block(Vector3.new(1.3, 1.6, 1.3), at(x, y, z), C.flame, { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	block(Vector3.new(1.6, 0.3, 1.6), at(x, y + 0.9, z), C.outline, DECOR)
	block(Vector3.new(1.6, 0.3, 1.6), at(x, y - 0.9, z), C.outline, DECOR)
	glow(lamp, C.flame, 16)
end

-- nutcracker mallet prop
local function mallet(cframe: CFrame, scale: number)
	block(Vector3.new(0.8, 6, 0.8) * scale, cframe, C.darkWood, DECOR)
	local head = cframe * CFrame.new(0, 3.4 * scale, 0)
	block(Vector3.new(4.4, 2.6, 2.6) * scale, head, C.wood, DECOR)
	block(Vector3.new(0.6, 2.9, 2.9) * scale, head * CFrame.new(-1.5 * scale, 0, 0), C.steel, DECOR)
	block(Vector3.new(0.6, 2.9, 2.9) * scale, head * CFrame.new(1.5 * scale, 0, 0), C.steel, DECOR)
end

local function buildGround()
	block(Vector3.new(200, 4, 250), at(0, -2, -15), C.path)
	block(Vector3.new(204, 3, 254), at(0, -3.4, -15), C.pathDark) -- island lip
	block(Vector3.new(1200, 1, 1200), at(0, -8, 0), C.sea, { CastShadow = false })

	-- invisible walls so nobody walks into the sea
	for _, wall in
		{
			{ Vector3.new(200, 60, 2), at(0, 30, -141) },
			{ Vector3.new(200, 60, 2), at(0, 30, 111) },
			{ Vector3.new(2, 60, 250), at(-101, 30, -15) },
			{ Vector3.new(2, 60, 250), at(101, 30, -15) },
		}
	do
		block(wall[1], wall[2], C.white, { Transparency = 1, CastShadow = false })
	end

	local function dash(x: number, z: number, alongX: boolean)
		block(alongX and Vector3.new(3.5, 0.1, 0.8) or Vector3.new(0.8, 0.1, 3.5), at(x, 0.35, z), C.white, DECOR)
	end

	-- darker rim around the whole field gives the colour bands an edge
	local south, north = ZONES[1].z1, ZONES[#ZONES].z0
	block(Vector3.new(FIELD_X * 2 + 2.4, 0.4, south - north + 2.4), at(0, 0.05, (south + north) / 2), C.pathDark)

	for index, zone in ZONES do
		block(Vector3.new(FIELD_X * 2, 0.6, zone.z1 - zone.z0), at(0, 0, (zone.z0 + zone.z1) / 2), zone.color)
		-- a few lighter patches so the band is not one flat rectangle
		for _ = 1, 7 do
			local size = rng:NextNumber(6, 12)
			block(
				Vector3.new(size, 0.05, size * rng:NextNumber(0.6, 1)),
				at(rng:NextNumber(-FIELD_X + 8, FIELD_X - 8), 0.31, rng:NextNumber(zone.z0 + 7, zone.z1 - 7)),
				zone.color:Lerp(C.white, 0.14),
				DECOR
			)
		end
		for x = -FIELD_X + 3, FIELD_X - 3, 6 do
			dash(x, zone.z0 + (index == #ZONES and 1.5 or 0), true) -- north edge / divider
		end
		for z = zone.z0 + 3, zone.z1 - 3, 6 do
			dash(-FIELD_X + 1.5, z, false)
			dash(FIELD_X - 1.5, z, false)
		end

		local def
		for _, name in Config.NutOrder do
			if Config.Nuts[name].zone == index then
				def = Config.Nuts[name]
			end
		end
		local text = zone.name
		if def and def.resistance > 1 then
			text ..= `\n💪 {def.resistance}+`
		end
		-- zone sign on two posts, west side, facing the spawn
		local z = zone.z1 - 6
		pillar(-58, 0, z, 6, 0.8, C.darkWood)
		pillar(-50, 0, z, 6, 0.8, C.darkWood)
		sign(text, Vector3.new(-54, 7.5, z), Vector3.new(0.35, 0, 1), Vector2.new(13, 5), zone.color:Lerp(C.outline, 0.35))
	end
	for x = -FIELD_X + 3, FIELD_X - 3, 6 do
		dash(x, south - 1.5, true) -- south edge
	end

	-- cream path from the plaza to the field
	block(Vector3.new(18, 0.2, 17), at(0, 0.05, 48), C.pathDark, DECOR)
	block(Vector3.new(15, 0.2, 17), at(0, 0.1, 48), C.cream, DECOR)
end

local function buildPlaza()
	-- stump platform with growth rings
	pillar(0, 0, 70, 1, 30, C.darkWood)
	pillar(0, 0.02, 70, 1, 27, C.wood)
	pillar(0, 0.04, 70, 1, 21, Color3.fromRGB(222, 180, 120))
	pillar(0, 0.06, 70, 1, 13, Color3.fromRGB(205, 160, 100))
	pillar(0, 0.08, 70, 1, 5, Color3.fromRGB(222, 180, 120))

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = at(0, 1.5, 70) -- default orientation faces -Z, i.e. the field
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Parent = map

	-- title arch between plaza and field, with bunting and lanterns
	for _, x in { -22, 22 } do
		pillar(x, 0, 47, 17, 2.6, C.darkWood)
		pillar(x, 0, 47, 1.2, 4.4, C.stone)
		blob(Vector3.new(3.6, 3.6, 3.6), at(x, 18.4, 47), C.gold)
		lantern(x * 0.82, 10.5, 47.2)
	end
	sign("🌰 NUTCRACKER SIMULATOR 🌰", Vector3.new(0, 16, 47), Vector3.zAxis, Vector2.new(42, 6), C.wood)
	for i = 0, 12 do
		block(
			Vector3.new(2, 2, 0.2),
			at(-16.5 + i * 2.75, 12.3, 47) * CFrame.Angles(0, 0, math.rad(45)),
			({ C.red, C.gold, C.white, FLOWERS[4] })[i % 4 + 1],
			DECOR
		)
	end

	-- giant acorn statue, west of the plaza
	pillar(-30, 0, 60, 1, 15, C.pathDark)
	pillar(-30, 1, 60, 1.4, 12, C.stone)
	local statue = NutModel.build({
		shape = "acorn",
		scale = 2.6,
		body = Color3.fromRGB(255, 205, 50),
		cap = Color3.fromRGB(255, 160, 20),
		crown = true,
	})
	statue.Name = "Statue"
	statue:PivotTo(at(-30, 2.4, 60))
	statue.Parent = map

	-- benches made of logs around the plaza
	for _, spot in { { -14, 84, 30 }, { 14, 84, -30 }, { 0, 90, 0 } } do
		local cframe = at(spot[1], 1.2, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0)
		block(Vector3.new(8, 1.4, 2.4), cframe, C.wood)
		block(Vector3.new(1, 1.2, 2), cframe * CFrame.new(-3, -0.6, 0), C.darkWood)
		block(Vector3.new(1, 1.2, 2), cframe * CFrame.new(3, -0.6, 0), C.darkWood)
	end
end

local function buildShop()
	local x, z = 30, 58
	local planks = { Material = Enum.Material.WoodPlanks }
	pillar(x, 0, z - 1.5, 0.4, 24, C.cream, DECOR) -- floor disc marks the shop spot
	local counter = block(Vector3.new(14, 3.4, 3), at(x, 1.7, z), C.wood, planks)
	counter.Name = "ShopCounter"
	block(Vector3.new(14.8, 0.6, 3.8), at(x, 3.7, z), C.darkWood)
	block(Vector3.new(14, 10, 1), at(x, 5, z - 5), C.wood, planks)
	for _, dx in { -6.6, 6.6 } do
		pillar(x + dx, 0, z + 1, 10.4, 1, C.darkWood)
		pillar(x + dx, 0, z - 4.5, 10.4, 1, C.darkWood)
		lantern(x + dx, 8, z + 2.2)
	end
	-- striped awning with a scalloped front edge
	for i = 0, 7 do
		local color = i % 2 == 0 and C.red or C.white
		block(Vector3.new(2, 0.6, 9.5), at(x - 7 + i * 2, 10.6, z - 1.3) * CFrame.Angles(math.rad(-10), 0, 0), color)
		blob(Vector3.new(2, 1.6, 0.8), at(x - 7 + i * 2, 9.5, z + 3.3), color)
	end
	sign("💪 STRENGTH SHOP", Vector3.new(x, 14.4, z - 1), Vector3.zAxis, Vector2.new(15, 3.6), Color3.fromRGB(255, 140, 40))

	mallet(at(x + 3.5, 6.6, z) * CFrame.Angles(0, 0, math.rad(28)), 1)

	-- stock on the counter and barrels beside it
	for i, dx in { -4.5, -2.6, -0.8 } do
		local nut = NutModel.build(Config.Nuts[i == 2 and "Walnut" or "Acorn"].look)
		nut:ScaleTo(0.32)
		nut:PivotTo(at(x + dx, 4, z))
		nut.Parent = map
	end
	for _, spot in { { -9.5, 2 }, { 9.5, 2 }, { 11.5, -0.5 } } do
		pillar(x + spot[1], 0, z + spot[2], 3.4, 3, C.wood, planks)
		pillar(x + spot[1], 0.9, z + spot[2], 0.5, 3.2, C.steel)
		pillar(x + spot[1], 2.4, z + spot[2], 0.5, 3.2, C.steel)
		blob(Vector3.new(2.6, 1.6, 2.6), at(x + spot[1], 3.5, z + spot[2]), Color3.fromRGB(222, 150, 80))
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt" -- the client opens the shop UI when this fires
	prompt.ObjectText = "Strength Shop"
	prompt.ActionText = "Open"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function buildGate()
	local planks = { Material = Enum.Material.WoodPlanks }
	for _, x in { -14, 14 } do
		block(Vector3.new(7, 24, 7), at(x, 12, GATE_Z), C.stone)
		block(Vector3.new(8.4, 3, 8.4), at(x, 1.5, GATE_Z), C.stone:Lerp(C.outline, 0.2))
		block(Vector3.new(9, 2, 9), at(x, 25, GATE_Z), C.darkWood)
		blob(Vector3.new(5, 5, 5), at(x, 28.5, GATE_Z), C.gold)
		-- torch in front of each pillar
		pillar(x * 1.45, 0, GATE_Z + 7, 7, 0.9, C.darkWood)
		local flame = blob(Vector3.new(2, 2.8, 2), at(x * 1.45, 8.2, GATE_Z + 7), C.flame)
		flame.Material = Enum.Material.Neon
		glow(flame, C.flame, 20)
	end
	block(Vector3.new(21, 5, 5), at(0, 21.5, GATE_Z), C.stone)
	block(Vector3.new(10.4, 19, 1.6), at(-5.3, 9.5, GATE_Z), C.wood, planks)
	block(Vector3.new(10.4, 19, 1.6), at(5.3, 9.5, GATE_Z), C.wood, planks)
	for _, y in { 4, 16.5 } do
		block(Vector3.new(21, 1.4, 2.2), at(0, y, GATE_Z), C.steel, { Material = Enum.Material.Metal })
	end
	sign("NEXT AREA\nComing soon", Vector3.new(0, 23, GATE_Z + 2.9), Vector3.zAxis, Vector2.new(15, 5), C.outline)

	-- big golden padlock on the doors
	local lock = at(0, 9, GATE_Z + 1.4)
	block(Vector3.new(5, 4.4, 1.4), lock, C.gold)
	block(Vector3.new(1, 1.6, 1.5), lock * CFrame.new(0, -0.2, 0), C.outline)
	for _, dx in { -1.4, 1.4 } do
		block(Vector3.new(0.9, 2.6, 0.9), lock * CFrame.new(dx, 3.2, 0), C.steel)
	end
	block(Vector3.new(3.7, 0.9, 0.9), lock * CFrame.new(0, 4.6, 0), C.steel)

	-- hedges close the rest of the north side
	for _, x in { -59, 59 } do
		block(Vector3.new(83, 9, 6), at(x, 4.5, GATE_Z), C.hedge)
		block(Vector3.new(83, 2, 7), at(x, 9.5, GATE_Z), C.hedge:Lerp(C.white, 0.2))
		for dx = -36, 36, 12 do
			blob(Vector3.new(9, 5, 8), at(x + dx, 10.5, GATE_Z), C.hedge:Lerp(C.white, 0.12))
		end
	end

	-- the world beyond: tall trees and a huge golden nut peeking over the wall
	for x = -85, 85, 24 do
		roundTree(x + rng:NextNumber(-5, 5), -105 + rng:NextNumber(-8, 8), 2.2, LEAVES[rng:NextInteger(1, #LEAVES)])
	end
	local teaser = NutModel.build(Config.Nuts.GoldenNut.look)
	teaser.Name = "Teaser"
	teaser:ScaleTo(3.2)
	teaser:PivotTo(at(40, 0, -122))
	teaser.Parent = map
end

local function buildDecor()
	for _, side in { -1, 1 } do
		for z = -66, 100, 17 do
			for _, x in { 64, 84 } do
				local skip = side == 1 and x == 64 and z > 40 and z < 70 -- keep the shop visible
				if not skip then
					tree(side * (x + rng:NextNumber(-4, 4)), z + rng:NextNumber(-4, 4), rng:NextNumber(0.9, 1.4))
				end
			end
		end
	end
	for x = -48, 48, 16 do
		tree(x + rng:NextNumber(-3, 3), 100 + rng:NextNumber(-3, 3), 1.3)
	end

	-- bushes, rocks, mushrooms and flowers hugging the field edges
	for _, side in { -1, 1 } do
		for z = -64, 36, 9 do
			local x = side * (FIELD_X + rng:NextNumber(4, 9))
			local pick = rng:NextInteger(1, 4)
			for _, zone in ZONES do
				if side == -1 and math.abs(z - (zone.z1 - 6)) < 7 then
					pick = 4 -- only flowers fit under the zone signs
				end
			end
			if pick == 1 then
				local s = rng:NextNumber(0.8, 1.4)
				blob(Vector3.new(6, 4, 5) * s, at(x, 1.6 * s, z), C.hedge:Lerp(LEAVES[4], rng:NextNumber()))
			elseif pick == 2 then
				local s = rng:NextNumber(0.7, 1.3)
				blob(Vector3.new(4.5, 3, 4) * s, at(x, 1.1 * s, z), C.stone:Lerp(C.outline, 0.15))
			elseif pick == 3 then
				mushroom(x, z, rng:NextNumber(0.7, 1.2))
			else
				flowers(x, z)
			end
			flowers(side * (FIELD_X + rng:NextNumber(10, 15)), z + rng:NextNumber(-3, 3))
		end
	end
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		flowers(math.cos(angle) * rng:NextNumber(18, 24), 70 + math.sin(angle) * rng:NextNumber(18, 24))
	end
	mushroom(-52, -74, 2.4)
	mushroom(52, -73, 2)

	-- clouds and far islands: the area is one piece of a bigger world
	for _ = 1, 9 do
		local x, y, z = rng:NextNumber(-260, 260), rng:NextNumber(85, 130), rng:NextNumber(-300, 220)
		local s = rng:NextNumber(1, 2)
		blob(Vector3.new(34, 11, 20) * s, at(x, y, z), C.white)
		blob(Vector3.new(20, 12, 16) * s, at(x + 10 * s, y + 4 * s, z + 2), C.white)
		blob(Vector3.new(18, 9, 14) * s, at(x - 12 * s, y + 2 * s, z - 3), C.white)
	end
	for _, island in { { -210, -60, 60 }, { 220, 20, 70 }, { -160, 180, 50 }, { 150, -250, 80 } } do
		local x, z, size = island[1], island[2], island[3]
		pillar(x, -7, z, 6, size, C.pathDark, DECOR)
		pillar(x, -1.4, z, 0.8, size * 0.94, ZONES[1].color:Lerp(LEAVES[rng:NextInteger(1, 3)], 0.4), DECOR)
		for _ = 1, 3 do
			roundTree(x + rng:NextNumber(-size / 4, size / 4), z + rng:NextNumber(-size / 4, size / 4), 2, LEAVES[rng:NextInteger(1, #LEAVES)])
		end
	end
end

local function effect(class: string)
	local object = Lighting:FindFirstChildOfClass(class) or Instance.new(class)
	object.Parent = Lighting
	return object
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.8
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = Color3.fromRGB(150, 150, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 175, 195)
	Lighting.ShadowSoftness = 0.35
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6

	local color = effect("ColorCorrectionEffect")
	color.Saturation = 0.22
	color.Contrast = 0.06
	color.TintColor = Color3.fromRGB(255, 250, 240)

	local atmosphere = effect("Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(210, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 185, 235)
	atmosphere.Glare = 0
	atmosphere.Haze = 1

	local bloom = effect("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.2

	effect("SunRaysEffect").Intensity = 0.06

	local blur = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if blur then
		blur.Enabled = false
	end
end

-- Nut spawn points: a jittered grid inside each zone, one zone per nut type.
local function spawnPoints()
	local points = {}
	for _, name in Config.NutOrder do
		local def = Config.Nuts[name]
		local zone = ZONES[def.zone]
		local margin = 7
		local width, depth = FIELD_X * 2 - margin * 2, zone.z1 - zone.z0 - margin * 2
		local cols = math.ceil(math.sqrt(def.count * width / depth))
		local rows = math.ceil(def.count / cols)
		local cells = {}
		for col = 1, cols do
			for row = 1, rows do
				table.insert(cells, { col, row })
			end
		end
		rng:Shuffle(cells)
		for i = 1, def.count do
			local col, row = cells[i][1], cells[i][2]
			local x = -FIELD_X + margin + (col - 0.5 + rng:NextNumber(-0.25, 0.25)) * width / cols
			local z = zone.z0 + margin + (row - 0.5 + rng:NextNumber(-0.25, 0.25)) * depth / rows
			table.insert(points, { type = name, position = Vector3.new(x, 0.3, z) })
		end
	end
	return points
end

function MapBuilder.build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	map = Instance.new("Folder")
	map.Name = "Map"

	buildGround()
	buildPlaza()
	buildShop()
	buildGate()
	buildDecor()
	buildLighting()

	map.Parent = workspace
	return spawnPoints()
end

return MapBuilder
