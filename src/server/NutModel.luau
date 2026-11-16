-- Builds a nut Model out of Parts from a `look` table (see Config.Nuts). Pivot is at the bottom so it sits on the ground.
-- look = { shape = "acorn" | "walnut", scale, body, cap, belt?, crown?, sparkle? }
local NutModel = {}

local GOLD = Color3.fromRGB(255, 200, 40)
local STEEL = Color3.fromRGB(150, 155, 175)

function NutModel.build(look)
	local s = look.scale
	local model = Instance.new("Model")

	-- kind: "blob" (ellipsoid), "block" or "cyl" (axis along local X). Sizes and offsets are in unscaled studs.
	local function piece(kind: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Size = size * s
		part.CFrame = cframe.Rotation + cframe.Position * s
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
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
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- stands a "cyl" up

	local light = look.body:Lerp(Color3.new(1, 1, 1), 0.25)
	local darkCap = look.cap:Lerp(Color3.new(0, 0, 0), 0.25)
	local body, center

	if look.shape == "walnut" then
		center = 2.2
		body = piece("blob", Vector3.new(4.8, 4.3, 4.4), at(0, center, 0), look.body)
		piece("blob", Vector3.new(5.05, 4.55, 0.8), at(0, center, 0), look.cap) -- seam between the two halves
		-- lumps make the shell look thick and wrinkled
		for _, lump in { { -1.3, 3.5, 1.1 }, { 1.2, 3.6, -1.1 }, { -1.2, 3.3, -1.2 }, { 1.4, 3.4, 1.2 }, { -1.7, 1.4, 1.2 }, { 1.6, 1.3, -1.2 } } do
			piece("blob", Vector3.new(2.3, 1.8, 2.1), at(lump[1], lump[2], lump[3]), light)
		end
		piece("blob", Vector3.new(1.2, 1, 1), at(2.5, center, 0), darkCap) -- tip
		if look.belt then
			-- iron strap: reads as "this one is tough"
			piece("cyl", Vector3.new(1, 5.15, 5.15), at(0, center, 0) * upright, STEEL, Enum.Material.Metal)
			piece("block", Vector3.new(1.3, 1.3, 0.5), at(0, center, -2.55) * CFrame.Angles(0, 0, math.rad(45)), GOLD)
			for _, angle in { 60, 120, 180, 240, 300 } do
				local spin = CFrame.Angles(0, math.rad(angle), 0)
				piece("blob", Vector3.new(0.5, 0.5, 0.5), at(0, center, 0) * spin * at(0, 0, -2.6), GOLD)
			end
		end
	else
		center = 2.4
		body = piece("blob", Vector3.new(4, 4.2, 4), at(0, center, 0), look.body)
		piece("blob", Vector3.new(1.5, 1.5, 1.5), at(0, 0.75, 0), look.body:Lerp(Color3.new(0, 0, 0), 0.12)) -- pointed bottom
		piece("blob", Vector3.new(5.1, 1.1, 5.1), at(0, 3.25, 0), darkCap) -- cap rim
		piece("blob", Vector3.new(4.7, 2.7, 4.7), at(0, 3.9, 0), look.cap)
		-- scale bumps: the checkered cap from the concept art
		for ring, count in { 8, 5 } do
			for i = 1, count do
				local spin = CFrame.Angles(0, math.rad(i * 360 / count + ring * 20), 0)
				piece("blob", Vector3.new(1, 0.6, 1), at(0, 4.1 + ring * 0.5, 0) * spin * at(0, 0, 2.15 - ring * 0.75), look.cap:Lerp(Color3.new(1, 1, 1), 0.18))
			end
		end
		if look.crown then
			piece("cyl", Vector3.new(0.8, 2.8, 2.8), at(0, 5.5, 0) * upright, Color3.fromRGB(255, 120, 20))
			for i = 1, 5 do
				local spin = CFrame.Angles(0, math.rad(i * 72), 0)
				piece("block", Vector3.new(0.6, 1.3, 0.6), at(0, 6.3, 0) * spin * at(0, 0, 1.1), GOLD)
				piece("blob", Vector3.new(0.5, 0.5, 0.5), at(0, 5.5, 0) * spin * at(0, 0, 1.45), Color3.fromRGB(235, 50, 70), Enum.Material.Neon)
			end
		else
			piece("cyl", Vector3.new(1.5, 0.6, 0.6), at(0.15, 5.6, 0) * upright * CFrame.Angles(0, 0, math.rad(-12)), darkCap) -- stem
			piece("blob", Vector3.new(1.9, 0.3, 1), at(1.05, 6.1, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(110, 200, 70)) -- leaf
		end
	end

	-- cartoon glint on the shell
	piece("blob", Vector3.new(0.9, 1.4, 0.4), at(-1.1, center + 0.7, -1.72) * CFrame.Angles(0, math.rad(30), math.rad(25)), Color3.new(1, 1, 1)).Transparency = 0.25

	body.Name = "Body"
	body.CanCollide = true
	body.CastShadow = true
	body.PivotOffset = CFrame.new(0, -center * s, 0)
	model.PrimaryPart = body

	if look.sparkle then
		for _, part in model:GetChildren() do
			if part.Material == Enum.Material.SmoothPlastic then
				part.Reflectance = 0.2
			end
		end
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(2, 4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.9 * s, 0)
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
		sparkles.Parent = body
		local glow = Instance.new("PointLight")
		glow.Color = look.body
		glow.Range = 10 * s
		glow.Brightness = 1.5
		glow.Parent = body
	end

	return model
end

return NutModel
