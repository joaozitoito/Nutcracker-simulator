-- Builds a nut Model out of Parts from a `look` table (see Config.Nuts). Pivot is at the bottom so it sits on the ground.
local NutModel = {}

local function blob(size: Vector3, offset: Vector3, color: Color3, parent)
	local part = Instance.new("Part")
	part.Size = size
	part.Position = offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function NutModel.build(look)
	local s = look.scale
	local model = Instance.new("Model")
	local body

	if look.shape == "walnut" then
		body = blob(Vector3.new(4.8, 4.2, 4.2) * s, Vector3.new(0, 2.1, 0) * s, look.body, model)
		blob(Vector3.new(5, 4.4, 0.8) * s, Vector3.new(0, 2.1, 0) * s, look.cap, model) -- seam
		blob(Vector3.new(4.9, 0.8, 4.3) * s, Vector3.new(0, 2.1, 0) * s, look.cap, model) -- cross seam
		blob(Vector3.new(1.2, 1, 1) * s, Vector3.new(2.5, 2.1, 0) * s, look.cap, model) -- tip
	else
		body = blob(Vector3.new(4, 4.2, 4) * s, Vector3.new(0, 2.1, 0) * s, look.body, model)
		blob(Vector3.new(4.7, 2.6, 4.7) * s, Vector3.new(0, 3.5, 0) * s, look.cap, model) -- cap
		blob(Vector3.new(0.7, 1.6, 0.7) * s, Vector3.new(0.2, 5, 0) * s, look.cap, model) -- stem
	end

	body.Name = "Body"
	body.CanCollide = true
	body.CastShadow = true
	body.PivotOffset = CFrame.new(0, -2.1 * s, 0)
	model.PrimaryPart = body

	if look.sparkle then
		for _, part in model:GetChildren() do
			part.Reflectance = 0.25
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
		local light = Instance.new("PointLight")
		light.Color = look.body
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = body
	end

	return model
end

return NutModel
