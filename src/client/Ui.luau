-- UI kit: every HUD piece is built from these so cards, buttons, bars, tags and popups look and move the same.
-- Eggs / pets / inventory screens should be built from this module too (Ui.card, Ui.button, Ui.tag with Config.Rarities).
local TweenService = game:GetService("TweenService")
local Assets = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Assets"))

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Color = {
	ink = Color3.fromRGB(43, 29, 61), -- outlines and dark text
	night = Color3.fromRGB(66, 48, 96), -- dark pills
	panel = Color3.fromRGB(255, 249, 236),
	sand = Color3.fromRGB(240, 226, 200),
	white = Color3.new(1, 1, 1),
	gold = Color3.fromRGB(255, 200, 40),
	green = Color3.fromRGB(96, 214, 56),
	red = Color3.fromRGB(255, 82, 96),
	orange = Color3.fromRGB(255, 150, 40),
	purple = Color3.fromRGB(160, 110, 255),
	grey = Color3.fromRGB(165, 160, 180),
}

function Ui.shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Ui.make(class: string, props: { [string]: any }?, children: { Instance }?)
	local object = Instance.new(class)
	for key, value in props or {} do
		object[key] = value
	end
	for _, child in children or {} do
		child.Parent = object
	end
	return object
end
local make = Ui.make

function Ui.tween(object: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goals
	)
	tween:Play()
	return tween
end

function Ui.corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round()
	return make("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Ui.stroke(thickness: number, color: Color3?)
	return make("UIStroke", {
		Thickness = thickness,
		Color = color or Ui.Color.ink,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function apply(object: Instance, props: { [string]: any }?)
	for key, value in props or {} do
		(object :: any)[key] = value
	end
	return object
end

-- white text with a chunky dark outline
function Ui.text(props: { [string]: any })
	return apply(
		make("TextLabel", {
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextColor3 = Ui.Color.white,
			TextSize = 26,
		}, { Ui.stroke(3) }),
		props
	)
end

-- plain dark text for light panels
function Ui.label(props: { [string]: any })
	return apply(
		make("TextLabel", {
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextColor3 = Ui.Color.ink,
			TextSize = 20,
		}),
		props
	)
end

-- soft highlight on the top half of a face: gives buttons and bars volume without a gradient
local function shine(radius: number)
	return make("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = Ui.Color.white,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
	}, { Ui.corner(radius) })
end

-- Raised card. Returns (frame, face): `frame` is the outlined body with a darker lip, content goes in `face`.
function Ui.card(style: { color: Color3?, radius: number?, depth: number? }, props: { [string]: any }?)
	local color = style.color or Ui.Color.panel
	local radius = style.radius or 18
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -(style.depth or 6)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, { Ui.corner(radius) })
	local frame = make("Frame", { BackgroundColor3 = Ui.shade(color, 0.3), BorderSizePixel = 0 }, {
		Ui.corner(radius),
		Ui.stroke(3),
		face,
	})
	return apply(frame, props), face
end

function Ui.setCardColor(frame: Instance, color: Color3)
	(frame :: any).BackgroundColor3 = Ui.shade(color, 0.3);
	(frame :: any).Face.BackgroundColor3 = color
end

-- Chunky button: grows on hover, face sinks into the lip while pressed. Returns (button, label, face).
function Ui.button(style: { text: string, color: Color3, textSize: number?, depth: number?, radius: number? }, props: { [string]: any }?)
	local depth = style.depth or 6
	local radius = style.radius or 16
	local label = Ui.text({ Text = style.text, TextSize = style.textSize or 26, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -depth),
		BackgroundColor3 = style.color,
		BorderSizePixel = 0,
	}, { Ui.corner(radius), shine(radius), label })
	local scale = make("UIScale")
	local button = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Ui.shade(style.color, 0.3),
		BorderSizePixel = 0,
	}, {
		Ui.corner(radius),
		make("UIStroke", { Thickness = 3, Color = Ui.Color.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		face,
		scale,
	})

	local function press(down: boolean)
		Ui.tween(face, 0.06, { Position = UDim2.fromOffset(0, down and depth - 2 or 0) })
	end
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1 })
		press(false)
	end)
	button.MouseButton1Down:Connect(function()
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)

	return apply(button, props), label, face
end

-- Progress bar with a white "ghost" that trails behind the fill when the value drops.
-- Returns (frame, set) where set(fraction, text) animates to the new value.
function Ui.bar(style: { color: Color3, textSize: number? }, props: { [string]: any }?)
	local ghost = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.Color.white, BorderSizePixel = 0 }, { round() })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = style.color, BorderSizePixel = 0, ZIndex = 2 }, {
		round(),
		shine(8),
	})
	local label = Ui.text({ Text = "", TextSize = style.textSize or 18, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local frame = make("Frame", { BackgroundColor3 = Ui.Color.ink, BorderSizePixel = 0 }, { round(), Ui.stroke(3), ghost, fill, label })

	local function set(fraction: number, text: string?, color: Color3?)
		local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.Visible = fraction > 0.01 -- a rounded frame of width 0 still draws a dot
		Ui.tween(fill, 0.15, { Size = size })
		TweenService:Create(ghost, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.2), { Size = size }):Play()
		if text then
			label.Text = text
		end
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return apply(frame, props), set
end

-- small rounded label: rarity, "+3", "NEW"...
function Ui.tag(text: string, color: Color3, props: { [string]: any }?)
	local tag = make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(86, 24) }, {
		round(),
		Ui.stroke(3),
		make("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Font = Ui.Font,
			Text = text,
			TextSize = 14,
			TextColor3 = Ui.Color.white,
			Size = UDim2.fromScale(1, 1),
		}, { Ui.stroke(2) }),
	})
	return apply(tag, props)
end

-- round coloured badge holding an emoji or a short text
function Ui.iconTile(text: string, color: Color3, size: number, props: { [string]: any }?)
	local tile = make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size) }, {
		round(),
		Ui.stroke(3),
		make("TextLabel", {
			BackgroundTransparency = 1,
			Font = Ui.Font,
			Text = text,
			TextSize = math.floor(size * 0.56),
			TextColor3 = Ui.Color.white,
			Size = UDim2.fromScale(1, 1),
		}),
	})
	return apply(tile, props)
end

-- Diamond icon (the permanent currency): a faceted gem drawn with frames, no image asset needed.
function Ui.diamond(size: number, props: { [string]: any }?)
	local function facet(w: number, h: number, x: number, y: number, color: Color3, z: number)
		return make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(w, h),
			Position = UDim2.fromScale(x, y),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, { Ui.corner(math.max(2, size * 0.08)) })
	end
	local gem = make("Frame", { Name = "Diamond", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) })
	local body = facet(0.66, 0.66, 0.5, 0.5, Color3.fromRGB(70, 200, 255), 1)
	Ui.stroke(math.max(2, size * 0.06), Color3.fromRGB(20, 70, 140)).Parent = body
	body.Parent = gem
	facet(0.36, 0.36, 0.5, 0.42, Color3.fromRGB(170, 235, 255), 2).Parent = gem
	facet(0.14, 0.14, 0.4, 0.34, Ui.Color.white, 3).Parent = gem
	return apply(gem, props)
end

-- 2D nut drawn from the same `look` table the 3D model uses, so the icon always matches the nut type.
function Ui.nutIcon(look, size: number, props: { [string]: any }?)
	local function piece(w: number, h: number, x: number, y: number, color: Color3, z: number)
		return make("Frame", {
			Size = UDim2.fromScale(w, h),
			Position = UDim2.fromScale(x, y),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, { round(), Ui.stroke(2) })
	end
	local icon = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) })
	if look.shape == "walnut" then
		piece(0.92, 0.8, 0.04, 0.12, look.body, 1).Parent = icon
		piece(0.1, 0.8, 0.45, 0.12, look.cap, 2).Parent = icon
		if look.belt then
			piece(0.96, 0.18, 0.02, 0.43, Color3.fromRGB(150, 155, 175), 3).Parent = icon
			piece(0.2, 0.24, 0.4, 0.4, Ui.Color.gold, 4).Parent = icon
		end
	else
		piece(0.1, 0.18, 0.45, 0, look.cap, 1).Parent = icon
		piece(0.7, 0.68, 0.15, 0.3, look.body, 2).Parent = icon
		piece(0.88, 0.36, 0.06, 0.14, look.cap, 3).Parent = icon
		if look.crown then
			Ui.text({ Text = "♛", TextSize = math.floor(size * 0.42), TextColor3 = Ui.Color.gold, Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, -0.2), ZIndex = 4, Parent = icon })
		end
	end
	return apply(icon, props)
end

---------------------------------------------------------------- image-based pieces (art from Shared.Assets)
-- Points an ImageLabel / ImageButton at the painted area of an asset, ignoring its transparent margins.
local function useImage(object: ImageLabel | ImageButton, image)
	local k = Assets.textureScale(image)
	local r = image.rect
	object.Image = image.id
	object.BackgroundTransparency = 1
	object.ImageRectOffset = Vector2.new(r[1] * k, r[2] * k)
	object.ImageRectSize = Vector2.new((r[3] - r[1]) * k, (r[4] - r[2]) * k)
	return object.ImageRectSize
end

-- Button drawn with a 9-slice image and native text on top. Same feel as Ui.button: grows on hover, sinks on press.
-- Returns (button, label). Change the text with label.Text; resize freely, the corners keep their shape.
-- shortcut: corner size follows Size.Y.Offset, so size these buttons in offsets (like the rest of the HUD).
function Ui.imageButton(style: { text: string, image: any?, textSize: number? }, props: { [string]: any }?)
	local image = style.image or Assets.Images.ButtonGreen
	local label = Ui.text({ Name = "Label", Text = style.text, TextSize = style.textSize or 26, Size = UDim2.fromScale(1, 0.9), ZIndex = 2 })
	local scale = make("UIScale")
	local button = make("ImageButton", { AutoButtonColor = false, ScaleType = Enum.ScaleType.Slice }, { label, scale })
	local rectSize = useImage(button, image)
	local s = image.slice
	button.SliceCenter = Rect.new(rectSize.X * s[1], rectSize.Y * s[2], rectSize.X * s[3], rectSize.Y * s[4])

	local function fitCorners()
		local height = button.Size.Y.Offset
		if height > 0 then
			button.SliceScale = height / rectSize.Y -- corners drawn at the size they have when the art is `height` tall
		end
	end
	button:GetPropertyChangedSignal("Size"):Connect(fitCorners)

	local function press(down: boolean)
		local base = button:GetAttribute("Tint") or Ui.Color.white
		Ui.tween(label, 0.06, { Position = UDim2.fromOffset(0, down and 3 or 0) })
		Ui.tween(button, 0.06, { ImageColor3 = down and Ui.shade(base, 0.15) or base })
	end
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1 })
		press(false)
	end)
	button.MouseButton1Down:Connect(function()
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)

	apply(button, props)
	fitCorners()
	return button, label
end

-- Tints an image button (grey = cannot afford, red = confirm...). nil goes back to the art's own colours.
function Ui.tintImageButton(button: ImageButton, color: Color3?)
	button:SetAttribute("Tint", color)
	button.ImageColor3 = color or Ui.Color.white
end

-- Coin icon (the acorn coin art), `size` pixels tall, keeping the art's proportions. Used everywhere a coin is shown.
function Ui.coin(size: number, props: { [string]: any }?)
	local image = Assets.Images.CoinAcorn
	local coin = make("ImageLabel", { Name = "Coin", ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(size * Assets.aspect(image), size) })
	useImage(coin, image)
	return apply(coin, props)
end

-- Modal panel with a coloured title band and a close button. Returns (frame, face, close). Content starts at y = 70.
function Ui.panel(style: { title: string, color: Color3 }, props: { [string]: any }?)
	local frame, face = Ui.card({ color = Ui.Color.panel, radius = 24, depth = 8 }, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 350),
		Visible = false,
		ZIndex = 11,
	})
	make("Frame", { Name = "Header", Size = UDim2.new(1, -12, 0, 58), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = style.color, BorderSizePixel = 0, Parent = face }, {
		Ui.corner(18),
		Ui.text({ Name = "Title", Text = style.title, TextSize = 30, Size = UDim2.fromScale(1, 1) }),
	})
	local close = Ui.button({ text = "X", color = Ui.Color.red, textSize = 24, depth = 4, radius = 14 }, {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(50, 50),
		ZIndex = 3,
		Parent = frame,
	})
	return apply(frame, props), face, close
end

-- 3D model shown inside the UI (pet and egg icons). Takes ownership of the model; models are built facing -Z.
function Ui.viewport(model: Model, props: { [string]: any }?)
	local frame = make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(0.4, -1, 1),
	})
	local cframe, size = model:GetBoundingBox()
	local camera = make("Camera", { FieldOfView = 30, Parent = frame })
	local distance = math.max(size.X, size.Y, size.Z) * 0.5 / math.tan(math.rad(15)) * 1.12
	local from = (CFrame.Angles(0, math.rad(-25), 0) * Vector3.new(0, 0.18, -1)).Unit * distance
	camera.CFrame = CFrame.lookAt(cframe.Position + from, cframe.Position)
	frame.CurrentCamera = camera
	model.Parent = frame
	return apply(frame, props)
end

-- Open / close a panel with a pop. The panel needs no setup: the UIScale is created on first use.
function Ui.pop(frame: GuiObject, open: boolean)
	local scale = frame:FindFirstChild("Pop") or make("UIScale", { Name = "Pop", Parent = frame })
	if open then
		scale.Scale = 0.7
		frame.Visible = true
		Ui.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	elseif frame.Visible then
		local tween = Ui.tween(scale, 0.1, { Scale = 0.75 })
		tween.Completed:Once(function()
			if scale.Scale < 0.9 then -- not reopened meanwhile
				frame.Visible = false
			end
		end)
	end
end

-- one-shot attention bump
function Ui.bump(object: GuiObject, amount: number?)
	local scale = object:FindFirstChild("Pop") or make("UIScale", { Name = "Pop", Parent = object }) -- one UIScale per object
	scale.Scale = amount or 1.25
	Ui.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Ui
