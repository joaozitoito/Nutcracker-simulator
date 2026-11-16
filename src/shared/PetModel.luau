-- Procedural squirrel pets and eggs built from Parts. Same builder for the 3D followers and the UI viewports.
-- Models face -Z, pivot at the bottom centre, about 4.6 studs tall at scale 1. Every part is anchored and non-colliding.
local PetModel = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(30, 22, 40)
local GOLD = Color3.fromRGB(255, 200, 40)
local STEEL = Color3.fromRGB(165, 170, 190)
local RED = Color3.fromRGB(230, 60, 70)

-- returns (model, piece) where piece(kind, size, cframe, color, material?) adds a part in unscaled model space
local function builder(scale: number)
	local model = Instance.new("Model")
	local function piece(kind: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Size = size * scale
		part.CFrame = cframe.Rotation + cframe.Position * scale
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
		end
		part.Parent = model
		return part
	end
	return model, piece
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a "cyl" upright

local function finish(model: Model, root: BasePart, rootHeight: number)
	root.Name = "Root"
	root.PivotOffset = CFrame.new(0, -rootHeight, 0)
	model.PrimaryPart = root
	return model
end

-- Outfits: each adds pieces on top of the base squirrel. `p` is the piece function, `look` the pet look table.
local OUTFITS = {}

function OUTFITS.plain() end

function OUTFITS.scarf(p, look)
	p("blob", Vector3.new(2.5, 0.6, 2.3), at(0, 2.45, 0), look.accent)
	p("block", Vector3.new(0.5, 1.1, 0.25), at(0.6, 1.9, -1.05) * CFrame.Angles(0, 0, math.rad(-12)), look.accent)
end

function OUTFITS.duck(p)
	local yellow, orange = Color3.fromRGB(255, 220, 50), Color3.fromRGB(255, 140, 30)
	p("blob", Vector3.new(2.9, 2.5, 2.5), at(0, 3.45, 0.42), yellow) -- hood, open at the face
	p("blob", Vector3.new(1.2, 0.4, 1), at(0, 4.15, -0.95), orange) -- beak on the hood
	p("blob", Vector3.new(0.3, 0.3, 0.2), at(-0.5, 4.45, -0.7), BLACK)
	p("blob", Vector3.new(0.3, 0.3, 0.2), at(0.5, 4.45, -0.7), BLACK)
	p("blob", Vector3.new(3.7, 1, 3.5), at(0, 1.25, 0), yellow) -- swim ring
	p("blob", Vector3.new(1, 0.9, 0.9), at(0, 1.6, -1.75), yellow) -- little duck on the ring
	p("blob", Vector3.new(0.6, 0.25, 0.5), at(0, 1.55, -2.2), orange)
end

function OUTFITS.scout(p, look)
	local brown = Color3.fromRGB(120, 72, 40)
	p("blob", Vector3.new(2.9, 1.5, 2.7), at(0, 4.05, 0.05), brown) -- acorn cap helmet
	p("blob", Vector3.new(3.1, 0.6, 2.9), at(0, 3.75, 0.05), brown:Lerp(BLACK, 0.25))
	p("cyl", Vector3.new(0.7, 0.35, 0.35), at(0, 4.95, 0.05) * UP, brown:Lerp(BLACK, 0.25))
	p("blob", Vector3.new(2.5, 0.55, 2.3), at(0, 2.45, 0), look.accent) -- neckerchief
	p("block", Vector3.new(0.8, 0.8, 0.2), at(0, 2.05, -1.02) * CFrame.Angles(0, 0, math.rad(45)), look.accent)
	p("block", Vector3.new(1.5, 1.6, 0.8), at(0, 1.7, 1.05), Color3.fromRGB(150, 110, 70)) -- backpack
end

function OUTFITS.rapper(p)
	p("blob", Vector3.new(2.45, 1.8, 2.2), at(0, 1.65, 0.05), BLACK) -- jacket
	p("block", Vector3.new(0.25, 1.4, 0.2), at(-1.0, 1.7, -0.75), WHITE)
	p("block", Vector3.new(0.25, 1.4, 0.2), at(1.0, 1.7, -0.75), WHITE)
	-- pixel shades
	p("block", Vector3.new(2.3, 0.5, 0.2), at(0, 3.52, -1.08), BLACK)
	p("block", Vector3.new(0.8, 0.3, 0.2), at(-0.6, 3.2, -1.08), BLACK)
	p("block", Vector3.new(0.8, 0.3, 0.2), at(0.6, 3.2, -1.08), BLACK)
	p("block", Vector3.new(0.25, 0.2, 0.22), at(-0.75, 3.55, -1.1), WHITE)
	p("block", Vector3.new(0.25, 0.2, 0.22), at(0.45, 3.55, -1.1), WHITE)
	-- chain with acorn pendant
	p("blob", Vector3.new(2.3, 0.35, 2.2), at(0, 2.4, -0.1) * CFrame.Angles(math.rad(-18), 0, 0), GOLD)
	p("blob", Vector3.new(0.6, 0.7, 0.4), at(0, 1.85, -1.2), GOLD)
end

function OUTFITS.knight(p)
	p("blob", Vector3.new(2.5, 1.7, 2.25), at(0, 1.65, 0.05), STEEL) -- breastplate
	p("blob", Vector3.new(0.6, 0.7, 0.3), at(0, 1.7, -1.1), GOLD)
	p("blob", Vector3.new(2.75, 1.7, 2.5), at(0, 3.95, 0.1), STEEL) -- helmet dome
	p("block", Vector3.new(2.5, 0.35, 0.3), at(0, 3.85, -1.0), STEEL:Lerp(BLACK, 0.3)) -- visor edge
	p("blob", Vector3.new(0.5, 1.3, 1.5), at(0, 5.05, 0.25), RED) -- plume
	-- shield with golden acorn
	p("block", Vector3.new(1.5, 1.8, 0.3), at(-1.55, 1.6, -0.75) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(90, 100, 150))
	p("blob", Vector3.new(0.8, 0.9, 0.3), at(-1.6, 1.6, -0.95) * CFrame.Angles(0, math.rad(20), 0), GOLD)
end

function OUTFITS.wizard(p)
	local purple = Color3.fromRGB(130, 70, 220)
	p("blob", Vector3.new(2.55, 1.9, 2.3), at(0, 1.6, 0.05), purple) -- robe
	p("blob", Vector3.new(2.65, 0.4, 2.4), at(0, 2.4, 0.05), GOLD)
	p("blob", Vector3.new(0.6, 0.6, 0.3), at(0, 2.3, -1.1), GOLD)
	p("blob", Vector3.new(3.6, 0.5, 3.6), at(0, 4.1, 0.05), purple) -- hat brim
	p("blob", Vector3.new(2.1, 1.5, 2.1), at(0, 4.6, 0.1), purple)
	p("blob", Vector3.new(1.4, 1.3, 1.4), at(0.1, 5.4, 0.3), purple)
	p("blob", Vector3.new(0.8, 1, 0.8), at(0.3, 6.1, 0.6), purple)
	p("blob", Vector3.new(0.7, 0.7, 0.25), at(0, 4.75, -0.95), GOLD) -- star
	p("block", Vector3.new(0.25, 3.8, 0.25), at(1.6, 1.9, -0.6), Color3.fromRGB(110, 70, 45)) -- staff
	p("blob", Vector3.new(0.8, 1.1, 0.8), at(1.6, 4.1, -0.6), Color3.fromRGB(220, 110, 255), Enum.Material.Neon)
end

function OUTFITS.pirate(p)
	p("blob", Vector3.new(2.5, 1.8, 2.25), at(0, 1.65, 0.05), Color3.fromRGB(170, 40, 50)) -- coat
	p("blob", Vector3.new(2.6, 0.4, 2.35), at(0, 1.2, 0.05), Color3.fromRGB(60, 40, 30)) -- belt
	p("block", Vector3.new(0.6, 0.5, 0.2), at(0, 1.2, -1.15), GOLD)
	p("blob", Vector3.new(3.6, 1, 2), at(0, 4.3, 0.05), BLACK) -- bicorne hat
	p("blob", Vector3.new(2.2, 1.5, 1.6), at(0, 4.7, 0.05), BLACK)
	p("blob", Vector3.new(0.6, 0.6, 0.2), at(0, 4.6, -0.8), WHITE) -- skull badge
	p("block", Vector3.new(0.6, 0.6, 0.15), at(0.5, 3.5, -1.08), BLACK) -- eyepatch
	p("block", Vector3.new(2.5, 0.15, 0.15), at(0, 3.75, -1.0) * CFrame.Angles(0, 0, math.rad(-8)), BLACK)
	p("block", Vector3.new(0.2, 1.6, 0.2), at(-1.5, 2.2, -0.7) * CFrame.Angles(math.rad(-30), 0, 0), STEEL) -- cutlass
	p("block", Vector3.new(0.6, 0.2, 0.3), at(-1.5, 1.6, -0.35), GOLD)
end

local function crown(p, y: number)
	p("cyl", Vector3.new(0.6, 2, 2), at(0, y, 0.05) * UP, Color3.fromRGB(255, 150, 20))
	for i = 1, 5 do
		local spin = CFrame.Angles(0, math.rad(i * 72), 0)
		p("block", Vector3.new(0.45, 0.9, 0.45), at(0, y + 0.6, 0.05) * spin * at(0, 0, 0.8), GOLD)
		p("blob", Vector3.new(0.4, 0.4, 0.4), at(0, y, 0.05) * spin * at(0, 0, 1.05), RED, Enum.Material.Neon)
	end
end

function OUTFITS.king(p)
	crown(p, 4.45)
	p("block", Vector3.new(2.6, 2.6, 0.25), at(0, 1.6, 0.95) * CFrame.Angles(math.rad(8), 0, 0), RED) -- cape
	p("blob", Vector3.new(2.8, 0.7, 2.6), at(0, 2.45, 0.05), WHITE) -- fur collar
	for _, x in { -0.8, 0, 0.8 } do
		p("blob", Vector3.new(0.3, 0.3, 0.2), at(x, 2.45, -1.2), BLACK)
	end
	p("block", Vector3.new(0.25, 3, 0.25), at(1.6, 1.6, -0.6), GOLD) -- sceptre
	p("blob", Vector3.new(0.8, 0.8, 0.8), at(1.6, 3.3, -0.6), RED, Enum.Material.Neon)
end

function OUTFITS.cosmic(p)
	-- halo and stars; the base squirrel is made to glow in build()
	p("cyl", Vector3.new(0.2, 2.6, 2.6), at(0, 5, 0.05) * UP, GOLD, Enum.Material.Neon)
	for _, star in { { -1.3, 4.6, -0.2 }, { 1.4, 2.2, 0.4 }, { -1.5, 1.2, 0.9 }, { 0.9, 4.9, 1.2 }, { 0.2, 3.4, 2.3 }, { -0.9, 0.8, -1 } } do
		p("blob", Vector3.new(0.45, 0.45, 0.45), at(star[1], star[2], star[3]), WHITE, Enum.Material.Neon)
	end
end

-- look = { fur, belly, outfit, accent?, scale? }; `scale` multiplies look.scale (world followers pass < 1)
function PetModel.build(look, scale: number?)
	local model, p = builder((look.scale or 1) * (scale or 1))
	local fur, belly = look.fur, look.belly
	local dark = fur:Lerp(BLACK, 0.25)
	local material = look.outfit == "cosmic" and Enum.Material.Neon or nil

	local body = p("blob", Vector3.new(2.3, 2.5, 2.1), at(0, 1.5, 0), fur, material)
	p("blob", Vector3.new(1.6, 1.8, 0.7), at(0, 1.4, -0.82), belly)
	p("blob", Vector3.new(2.5, 2.2, 2.2), at(0, 3.25, 0), fur, material) -- head
	p("blob", Vector3.new(1.5, 1, 0.8), at(0, 2.9, -0.85), belly) -- muzzle
	p("blob", Vector3.new(0.34, 0.26, 0.26), at(0, 3.12, -1.22), Color3.fromRGB(120, 60, 50))
	p("block", Vector3.new(0.5, 0.4, 0.12), at(0, 2.58, -1.14), WHITE) -- buck teeth
	for _, side in { -1, 1 } do
		p("blob", Vector3.new(0.46, 0.6, 0.22), at(0.52 * side, 3.5, -0.98), BLACK) -- eyes
		p("blob", Vector3.new(0.16, 0.2, 0.1), at(0.6 * side, 3.62, -1.08), WHITE)
		p("blob", Vector3.new(0.7, 0.9, 0.35), at(0.8 * side, 4.3, 0.05), fur, material) -- ears
		p("blob", Vector3.new(0.4, 0.55, 0.3), at(0.8 * side, 4.28, -0.08), belly)
		p("blob", Vector3.new(0.65, 1.1, 0.65), at(1.2 * side, 1.75, -0.3), fur, material) -- arms
		p("blob", Vector3.new(0.85, 0.5, 1.2), at(0.62 * side, 0.25, -0.3), dark) -- feet
	end
	-- big spiral tail
	p("blob", Vector3.new(1.6, 2.8, 1.4), at(0, 2.3, 1.55) * CFrame.Angles(math.rad(-10), 0, 0), fur, material)
	p("blob", Vector3.new(1.5, 1.5, 1.4), at(0, 3.9, 1.5), fur:Lerp(WHITE, 0.12), material)
	p("blob", Vector3.new(1, 1, 0.9), at(0, 4.4, 0.85), fur:Lerp(WHITE, 0.25), material)

	local outfit = OUTFITS[look.outfit] or OUTFITS.plain
	outfit(p, look)

	return finish(model, body, 1.5 * (look.scale or 1) * (scale or 1))
end

-- look = { shell, spots, deco = "acorn" | "leaves" | "crown" }
function PetModel.buildEgg(look, scale: number?)
	local s = scale or 1
	local model, p = builder(s)
	local shell = p("blob", Vector3.new(3, 3.9, 3), at(0, 1.95, 0), look.shell)
	for _, spot in { { 0, 2.4, -1.42, 0 }, { 1.2, 1.3, -0.75, 55 }, { -1.25, 1.7, -0.6, -60 }, { 0.9, 2.9, 0.9, 135 }, { -0.8, 1.1, 1.1, -140 } } do
		p("blob", Vector3.new(0.9, 0.9, 0.3), at(spot[1], spot[2], spot[3]) * CFrame.Angles(0, math.rad(-spot[4]), 0), look.spots)
	end

	if look.deco == "acorn" then
		local brown = Color3.fromRGB(125, 76, 42)
		p("blob", Vector3.new(3.3, 1.6, 3.3), at(0, 3.45, 0), brown)
		p("blob", Vector3.new(3.5, 0.6, 3.5), at(0, 3.05, 0), brown:Lerp(BLACK, 0.25))
		p("cyl", Vector3.new(0.9, 0.4, 0.4), at(0.1, 4.5, 0) * UP, brown:Lerp(BLACK, 0.25))
	elseif look.deco == "leaves" then
		local green = Color3.fromRGB(70, 175, 80)
		for i = 1, 5 do
			local spin = CFrame.Angles(0, math.rad(i * 72), 0)
			p("blob", Vector3.new(1.3, 0.35, 2), spin * at(0, 3.55, -0.8) * CFrame.Angles(math.rad(-25), 0, 0), green:Lerp(WHITE, i % 2 * 0.15))
		end
		p("blob", Vector3.new(3.15, 0.4, 3.15), at(0, 1.2, 0), green) -- vine
		p("blob", Vector3.new(0.7, 0.7, 0.7), at(0, 3.95, 0), Color3.fromRGB(255, 120, 170)) -- flower bud
	elseif look.deco == "crown" then
		p("cyl", Vector3.new(0.6, 2, 2), at(0, 3.75, 0) * UP, Color3.fromRGB(255, 150, 20))
		for i = 1, 5 do
			local spin = CFrame.Angles(0, math.rad(i * 72), 0)
			p("block", Vector3.new(0.45, 0.9, 0.45), at(0, 4.35, 0) * spin * at(0, 0, 0.8), GOLD)
			p("blob", Vector3.new(0.4, 0.4, 0.4), at(0, 3.75, 0) * spin * at(0, 0, 1.05), RED, Enum.Material.Neon)
		end
		p("blob", Vector3.new(3.15, 0.45, 3.15), at(0, 1.6, 0), GOLD) -- gold band
	end

	return finish(model, shell, 1.95 * s)
end

return PetModel
