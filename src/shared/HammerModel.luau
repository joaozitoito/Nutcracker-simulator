-- Procedural models for the five hammer tiers (Hammers.Tiers). Used in the world and in UI viewports.
-- Model space: grip at the origin, handle along +Y, head centred around y = 5.2 with its long axis along X.
-- The PrimaryPart is an invisible root at the origin, so PivotTo / ScaleTo work around the grip.
local HammerModel = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 200, 40)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder (axis X) upright (axis Y)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local BUILDERS = {}

-- p(kind, size, cframe, color, material?) adds a part; kind = "block" | "blob" (ellipsoid) | "cyl" (axis X) | "ball"
function BUILDERS.Starter(p)
	local wood, dark = Color3.fromRGB(214, 160, 100), Color3.fromRGB(150, 100, 60)
	p("cyl", Vector3.new(4.4, 0.5, 0.5), at(0, 2.3, 0) * UP, wood)
	p("cyl", Vector3.new(1.3, 0.62, 0.62), at(0, 0.8, 0) * UP, Color3.fromRGB(200, 70, 60)) -- cloth grip
	p("ball", Vector3.new(0.7, 0.7, 0.7), at(0, 0.05, 0), dark)
	p("cyl", Vector3.new(3, 1.8, 1.8), at(0, 5.1, 0), wood) -- head
	for _, x in { -1.38, 1.38 } do
		p("cyl", Vector3.new(0.26, 1.95, 1.95), at(x, 5.1, 0), dark)
	end
end

function BUILDERS.AcornCrusher(p)
	local handle, wrap = Color3.fromRGB(120, 75, 45), Color3.fromRGB(70, 45, 30)
	local body, cap = Color3.fromRGB(230, 160, 85), Color3.fromRGB(125, 76, 42)
	p("cyl", Vector3.new(4.6, 0.6, 0.6), at(0, 2.4, 0) * UP, handle)
	for _, y in { 0.6, 1.2, 1.8 } do
		p("cyl", Vector3.new(0.22, 0.72, 0.72), at(0, y, 0) * UP, wrap)
	end
	p("ball", Vector3.new(0.8, 0.8, 0.8), at(0, 0.05, 0), wrap)
	-- head: a giant acorn lying on its side, cap on one end, pointed tip on the striking end
	p("blob", Vector3.new(2.9, 2.4, 2.4), at(0.55, 5.3, 0), body)
	p("blob", Vector3.new(0.9, 0.9, 0.9), at(1.95, 5.3, 0), body:Lerp(Color3.new(0, 0, 0), 0.15))
	p("blob", Vector3.new(1.5, 2.75, 2.75), at(-0.8, 5.3, 0), cap)
	for i = 1, 6 do
		local spin = CFrame.Angles(math.rad(i * 60), 0, 0)
		p("blob", Vector3.new(0.5, 0.55, 0.55), at(-0.9, 5.3, 0) * spin * at(0, 1.2, 0), cap:Lerp(WHITE, 0.18))
	end
	p("cyl", Vector3.new(0.8, 0.4, 0.4), at(-1.7, 5.3, 0), cap:Lerp(Color3.new(0, 0, 0), 0.3)) -- stem
	p("block", Vector3.new(0.5, 0.5, 2.5), at(0, 4.15, 0), Color3.fromRGB(150, 155, 175), Enum.Material.Metal) -- collar
end

function BUILDERS.ForestMaul(p)
	local bark, cut, ring = Color3.fromRGB(105, 70, 45), Color3.fromRGB(225, 185, 130), Color3.fromRGB(170, 120, 75)
	local moss, leaf = Color3.fromRGB(90, 170, 70), Color3.fromRGB(120, 205, 90)
	p("cyl", Vector3.new(4.8, 0.7, 0.7), at(0, 2.4, 0) * UP, bark)
	p("blob", Vector3.new(0.6, 0.7, 0.6), at(0.32, 3, 0), bark:Lerp(WHITE, 0.1)) -- knot
	for _, y in { 0.9, 1.6 } do
		p("cyl", Vector3.new(0.18, 0.82, 0.82), at(0, y, 0) * UP, moss) -- vine wrap
	end
	p("blob", Vector3.new(0.9, 0.2, 0.5), at(0.6, 1.7, 0) * CFrame.Angles(0, 0, math.rad(25)), leaf)
	-- head: a cut log with growth rings, moss and a sprout on top
	p("cyl", Vector3.new(3.8, 2.6, 2.6), at(0, 5.2, 0), bark)
	for _, x in { -1.92, 1.92 } do
		p("cyl", Vector3.new(0.12, 2.3, 2.3), at(x, 5.2, 0), cut)
		p("cyl", Vector3.new(0.14, 1.3, 1.3), at(x, 5.2, 0), ring)
		p("cyl", Vector3.new(0.16, 0.5, 0.5), at(x, 5.2, 0), cut)
	end
	p("blob", Vector3.new(2.8, 0.7, 2), at(0, 6.4, 0), moss)
	p("blob", Vector3.new(1.3, 0.22, 0.6), at(-0.4, 6.95, 0) * CFrame.Angles(0, 0, math.rad(30)), leaf)
	p("blob", Vector3.new(1.3, 0.22, 0.6), at(0.4, 6.95, 0) * CFrame.Angles(0, 0, math.rad(-30)), leaf)
	p("blob", Vector3.new(0.7, 0.45, 0.7), at(1, 6.35, -0.9), Color3.fromRGB(230, 60, 70)) -- tiny mushroom
end

function BUILDERS.RoyalBreaker(p)
	local velvet, ruby = Color3.fromRGB(120, 40, 140), Color3.fromRGB(235, 40, 70)
	p("cyl", Vector3.new(5, 0.62, 0.62), at(0, 2.5, 0) * UP, Color3.fromRGB(140, 30, 50))
	for _, y in { 0.7, 2.4, 4.1 } do
		p("cyl", Vector3.new(0.28, 0.78, 0.78), at(0, y, 0) * UP, GOLD)
	end
	p("ball", Vector3.new(0.85, 0.85, 0.85), at(0, 0.05, 0), GOLD)
	p("ball", Vector3.new(0.42, 0.42, 0.42), at(0, -0.35, 0), ruby, Enum.Material.Neon)
	-- head: velvet block with heavy gold caps, a gold band, gems and a crown
	p("block", Vector3.new(3.6, 2.2, 2.2), at(0, 5.2, 0), velvet)
	for _, x in { -1.95, 1.95 } do
		p("cyl", Vector3.new(0.55, 2.7, 2.7), at(x, 5.2, 0), GOLD)
	end
	p("block", Vector3.new(0.45, 2.35, 2.35), at(0, 5.2, 0), GOLD)
	for _, z in { -1.2, 1.2 } do
		p("ball", Vector3.new(0.7, 0.7, 0.7), at(0, 5.2, z), ruby, Enum.Material.Neon)
	end
	p("cyl", Vector3.new(0.45, 1.5, 1.5), at(0, 6.5, 0) * UP, GOLD)
	for i = 1, 4 do
		local spin = CFrame.Angles(0, math.rad(i * 90 + 45), 0)
		p("block", Vector3.new(0.3, 0.6, 0.3), at(0, 6.9, 0) * spin * at(0, 0, 0.55), GOLD)
	end
end

function BUILDERS.CosmicPulverizer(p)
	local void, purple, cyan = Color3.fromRGB(35, 22, 70), Color3.fromRGB(170, 100, 255), Color3.fromRGB(90, 220, 255)
	p("cyl", Vector3.new(5.2, 0.62, 0.62), at(0, 2.6, 0) * UP, void)
	for _, y in { 0.8, 2, 3.2, 4.4 } do
		p("cyl", Vector3.new(0.14, 0.7, 0.7), at(0, y, 0) * UP, cyan, Enum.Material.Neon)
	end
	p("ball", Vector3.new(0.9, 0.9, 0.9), at(0, 0.05, 0), purple, Enum.Material.Neon)
	-- head: a glowing core between two dark caps with neon rims, an orbit ring and loose stars
	for _, x in { -1.75, 1.75 } do
		p("cyl", Vector3.new(1.1, 3.1, 3.1), at(x, 5.6, 0), void)
		p("cyl", Vector3.new(0.2, 3.35, 3.35), at(x * 1.3, 5.6, 0), cyan, Enum.Material.Neon)
	end
	local core = p("ball", Vector3.new(2.5, 2.5, 2.5), at(0, 5.6, 0), purple, Enum.Material.Neon)
	local orbit = p("cyl", Vector3.new(0.12, 4.3, 4.3), at(0, 5.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(25)), cyan, Enum.Material.Neon)
	orbit.Transparency = 0.25
	for _, star in { { 0.6, 7.4, 0.5 }, { -0.9, 3.9, -0.8 }, { 1.1, 6.6, -1.6 }, { -0.4, 7.1, 1.4 } } do
		p("ball", Vector3.new(0.32, 0.32, 0.32), at(star[1], star[2], star[3]), WHITE, Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = core
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new(cyan, purple)
	sparkles.Parent = core
end

-- Builds tier `index` (1..5). Returns a Model; every part is anchored and non-colliding.
function HammerModel.build(index: number)
	local Hammers = require(script.Parent.Hammers)
	local tier = Hammers.Tiers[math.clamp(index, 1, #Hammers.Tiers)]
	local model = Instance.new("Model")
	model.Name = tier.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local function p(kind: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if kind == "blob" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		elseif kind == "cyl" then
			part.Shape = Enum.PartType.Cylinder
		elseif kind == "ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Parent = model
		return part
	end
	BUILDERS[tier.id](p)
	return model
end

return HammerModel
