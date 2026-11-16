-- Builds the first area ("Acorn Meadow") from Parts at server start and returns where nuts should spawn.
-- Layout (top view, +Z is south): spawn plaza -> title arch -> field with 3 colour bands -> locked gate to the next area.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local NutModel = require(script.Parent.NutModel)

local MapBuilder = {}

local FONT = Enum.Font.FredokaOne
local C = {
	path = Color3.fromRGB(214, 222, 240),
	sea = Color3.fromRGB(70, 170, 255),
	wood = Color3.fromRGB(160, 105, 62),
	darkWood = Color3.fromRGB(110, 70, 45),
	stone = Color3.fromRGB(186, 190, 208),
	hedge = Color3.fromRGB(70, 170, 70),
	white = Color3.fromRGB(255, 255, 255),
	red = Color3.fromRGB(235, 70, 70),
	outline = Color3.fromRGB(40, 30, 60),
}
local LEAVES = {
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(230, 80, 50),
	Color3.fromRGB(120, 200, 80),
}

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

-- vertical cylinder standing on (x, y, z)
local function pillar(x: number, y: number, z: number, height: number, diameter: number, color: Color3)
	return block(
		Vector3.new(height, diameter, diameter),
		at(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		{ Shape = Enum.PartType.Cylinder }
	)
end

local function blob(size: Vector3, cframe: CFrame, color: Color3)
	local part = block(size, cframe, color, { CanCollide = false, CastShadow = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- board with text on its front; `facing` is the direction the text looks at
local function sign(text: string, position: Vector3, facing: Vector3, size: Vector2, color: Color3)
	local board = block(Vector3.new(size.X, size.Y, 0.6), CFrame.lookAt(position, position + facing), color)
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

local function tree(x: number, z: number, scale: number, leaf: Color3)
	pillar(x, 0, z, 7 * scale, 2.2 * scale, C.darkWood)
	blob(Vector3.new(11, 9, 11) * scale, at(x, 10 * scale, z), leaf)
	blob(Vector3.new(8, 7, 8) * scale, at(x + 2.5 * scale, 14 * scale, z - 1.5 * scale), leaf:Lerp(C.white, 0.15))
	blob(Vector3.new(7, 6, 7) * scale, at(x - 3 * scale, 13 * scale, z + 2 * scale), leaf:Lerp(C.outline, 0.1))
end

local function mushroom(x: number, z: number, scale: number)
	pillar(x, 0, z, 3 * scale, 1.6 * scale, Color3.fromRGB(245, 235, 215))
	blob(Vector3.new(6, 3.4, 6) * scale, at(x, 3.6 * scale, z), C.red)
	blob(Vector3.new(1.4, 0.8, 1.4) * scale, at(x + 1.2 * scale, 5 * scale, z + 0.8 * scale), C.white)
	blob(Vector3.new(1.1, 0.7, 1.1) * scale, at(x - 1.4 * scale, 4.8 * scale, z - 0.6 * scale), C.white)
end

local function buildGround()
	block(Vector3.new(200, 4, 250), at(0, -2, -15), C.path)
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
		block(
			alongX and Vector3.new(3.5, 0.1, 0.8) or Vector3.new(0.8, 0.1, 3.5),
			at(x, 0.35, z),
			C.white,
			{ CanCollide = false, CastShadow = false }
		)
	end

	for index, zone in ZONES do
		block(Vector3.new(FIELD_X * 2, 0.6, zone.z1 - zone.z0), at(0, 0, (zone.z0 + zone.z1) / 2), zone.color)
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
		dash(x, ZONES[1].z1 - 1.5, true) -- south edge
	end
end

local function buildPlaza()
	-- stump platform with growth rings
	pillar(0, 0, 70, 1, 30, C.wood)
	pillar(0, 0.02, 70, 1, 24, Color3.fromRGB(222, 180, 120))
	pillar(0, 0.04, 70, 1, 14, Color3.fromRGB(205, 160, 100))

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = at(0, 1.5, 70) -- default orientation faces -Z, i.e. the field
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Parent = map

	-- title arch between plaza and field
	pillar(-22, 0, 47, 16, 2.4, C.darkWood)
	pillar(22, 0, 47, 16, 2.4, C.darkWood)
	sign("🌰 NUTCRACKER SIMULATOR 🌰", Vector3.new(0, 16, 47), Vector3.zAxis, Vector2.new(46, 6), C.wood)

	-- giant acorn statue, west of the plaza
	pillar(-30, 0, 60, 2, 12, C.stone)
	local statue = NutModel.build({
		shape = "acorn",
		scale = 2.6,
		body = Color3.fromRGB(255, 205, 50),
		cap = Color3.fromRGB(255, 160, 20),
	})
	statue.Name = "Statue"
	statue:PivotTo(at(-30, 2, 60))
	statue.Parent = map
end

local function buildShop()
	local x, z = 30, 58
	local counter = block(Vector3.new(14, 3.4, 3), at(x, 1.7, z), C.wood)
	counter.Name = "ShopCounter"
	block(Vector3.new(14.6, 0.5, 3.6), at(x, 3.6, z), C.darkWood)
	block(Vector3.new(14, 10, 1), at(x, 5, z - 5), C.wood)
	for _, dx in { -6.5, 6.5 } do
		pillar(x + dx, 0, z + 1, 10, 0.9, C.darkWood)
		pillar(x + dx, 0, z - 4.5, 10, 0.9, C.darkWood)
	end
	-- striped awning
	for i = 0, 7 do
		block(
			Vector3.new(2, 0.6, 9),
			at(x - 7 + i * 2, 10.5, z - 1.5) * CFrame.Angles(math.rad(-10), 0, 0),
			i % 2 == 0 and C.red or C.white
		)
	end
	sign("💪 STRENGTH SHOP", Vector3.new(x, 14, z - 1), Vector3.zAxis, Vector2.new(15, 3.6), Color3.fromRGB(255, 140, 40))

	-- nutcracker mallet leaning on the counter
	local lean = at(x + 4, 5.5, z) * CFrame.Angles(0, 0, math.rad(25))
	block(Vector3.new(0.7, 5, 0.7), lean, C.darkWood, { CanCollide = false })
	block(Vector3.new(3.4, 2, 2), lean * CFrame.new(0, 3, 0), C.stone, { CanCollide = false })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt" -- the client opens the shop UI when this fires
	prompt.ObjectText = "Strength Shop"
	prompt.ActionText = "Open"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function buildGate()
	for _, x in { -14, 14 } do
		block(Vector3.new(7, 24, 7), at(x, 12, GATE_Z), C.stone)
		block(Vector3.new(9, 2, 9), at(x, 25, GATE_Z), C.darkWood)
		blob(Vector3.new(5, 5, 5), at(x, 28.5, GATE_Z), Color3.fromRGB(255, 205, 50))
	end
	block(Vector3.new(21, 5, 5), at(0, 21.5, GATE_Z), C.stone)
	block(Vector3.new(10.4, 19, 1.6), at(-5.3, 9.5, GATE_Z), C.wood)
	block(Vector3.new(10.4, 19, 1.6), at(5.3, 9.5, GATE_Z), C.wood)
	block(Vector3.new(21, 1.2, 2), at(0, 6, GATE_Z), C.darkWood)
	block(Vector3.new(21, 1.2, 2), at(0, 14, GATE_Z), C.darkWood)
	sign("🔒 NEXT AREA\nComing soon", Vector3.new(0, 10, GATE_Z + 1.4), Vector3.zAxis, Vector2.new(15, 6), C.outline)

	-- hedges close the rest of the north side
	for _, x in { -59, 59 } do
		block(Vector3.new(83, 9, 6), at(x, 4.5, GATE_Z), C.hedge)
		block(Vector3.new(83, 2, 7), at(x, 9.5, GATE_Z), C.hedge:Lerp(C.white, 0.2))
	end

	-- the world beyond: tall trees and a huge golden nut peeking over the wall
	for x = -85, 85, 24 do
		tree(x + rng:NextNumber(-5, 5), -105 + rng:NextNumber(-8, 8), 2.2, LEAVES[rng:NextInteger(1, #LEAVES)])
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
					tree(
						side * (x + rng:NextNumber(-4, 4)),
						z + rng:NextNumber(-4, 4),
						rng:NextNumber(0.9, 1.4),
						LEAVES[rng:NextInteger(1, #LEAVES)]
					)
				end
			end
		end
	end
	for x = -48, 48, 16 do
		tree(x + rng:NextNumber(-3, 3), 100 + rng:NextNumber(-3, 3), 1.3, LEAVES[rng:NextInteger(1, #LEAVES)])
	end

	-- bushes, rocks and mushrooms hugging the field edges
	for _, side in { -1, 1 } do
		for z = -64, 36, 9 do
			local x = side * (FIELD_X + rng:NextNumber(4, 9))
			local pick = rng:NextInteger(1, 3)
			for _, zone in ZONES do
				if side == -1 and math.abs(z - (zone.z1 - 6)) < 7 then
					pick = 0 -- leave room for the zone signs
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
			end
		end
	end
	mushroom(-52, -74, 2.4)
	mushroom(52, -73, 2)
end

local function buildLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(150, 150, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 175, 195)
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.25
	color.Contrast = 0.05
	color.Parent = Lighting
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
