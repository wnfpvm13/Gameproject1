--!strict
-- The face window: a small framed view on the right side of the screen that shows the player's own locomotive from
-- the front, because the play camera looks from behind and the face is out of sight. It grows while the locomotive
-- is flat, shows short words over itself for run events (flash) and the run's score under itself. A ViewportFrame
-- only draws its own children, so the window holds copies of the locomotive's moving parts and copies their size,
-- place and transparency from the real ones (which LocomotiveAnimator moves) in update(); call it after the animator
-- every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local FaceCam = {}
FaceCam.__index = FaceCam

local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(40, 24, 14)

type Copy = { source: BasePart, copy: BasePart, sourceMesh: SpecialMesh?, copyMesh: SpecialMesh? }

type Fields = {
	gui: ScreenGui,
	frame: Frame,
	viewport: ViewportFrame,
	world: WorldModel, -- inside the viewport: holds the avatar copy
	camera: Camera,
	word: TextLabel, -- flash()
	wordStroke: UIStroke,
	wordScale: UIScale,
	flashes: number, -- counts flashes, so an older one's fade-out leaves a newer word alone
	score: TextLabel,
	copies: { Copy },
	shown: { Instance }, -- the top-level copies, destroyed when the window shows another locomotive
	base: BasePart?,
	face: BasePart?,
	big: boolean,
	tween: Tween?,
}
export type FaceCam = typeof(setmetatable({} :: Fields, FaceCam))

local function sizeFor(height: number): UDim2
	return UDim2.fromScale(height, height) -- the frame's SizeConstraint makes both shares of the screen height
end

local function outlined(label: TextLabel, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = OUTLINE
	stroke.Parent = label
	return stroke
end

function FaceCam.new(playerGui: Instance): FaceCam
	local c = Config.FaceCam
	local colors = Config.Locomotive.Colors
	local gui = Instance.new("ScreenGui")
	gui.Name = "WesternTrainFaceCam"
	gui.ResetOnSpawn = false -- this script runs once per player, not once per character
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -c.Margin, c.Top, 0)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	frame.Size = sizeFor(c.Height)
	frame.BackgroundColor3 = colors.Wood
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.Brass
	stroke.Thickness = c.BorderThickness
	stroke.Parent = frame

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "View"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(0.9, 0.9)
	viewport.BackgroundColor3 = c.Sky
	viewport.Ambient = c.Ambient
	viewport.LightColor = c.Light
	viewport.Parent = frame
	local viewCorner = Instance.new("UICorner")
	viewCorner.CornerRadius = UDim.new(0.1, 0)
	viewCorner.Parent = viewport
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = c.FieldOfView
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.78)
	word.Size = UDim2.fromScale(1, 0.34) -- within the window: it sits by the screen's right edge
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.GothamBlack
	word.TextScaled = true
	word.TextColor3 = WHITE
	word.TextTransparency = 1
	word.ZIndex = 2
	word.Parent = frame
	local wordStroke = outlined(word, 3)
	wordStroke.Transparency = 1
	local wordScale = Instance.new("UIScale")
	wordScale.Parent = word

	local score = Instance.new("TextLabel")
	score.Name = "Score"
	-- Lined up with the window's right edge and growing to the left, so a longer score never runs off the screen.
	score.AnchorPoint = Vector2.new(1, 0)
	score.Position = UDim2.new(1, 0, 1, 6)
	score.Size = UDim2.fromScale(1.9, 0.16)
	score.TextXAlignment = Enum.TextXAlignment.Right
	score.BackgroundTransparency = 1
	score.Font = Enum.Font.GothamBold
	score.TextScaled = true
	score.TextColor3 = WHITE
	score.Text = ""
	score.Parent = frame
	outlined(score, 2)

	gui.Parent = playerGui
	local fields: Fields = {
		gui = gui,
		frame = frame,
		viewport = viewport,
		world = world,
		camera = camera,
		word = word,
		wordStroke = wordStroke,
		wordScale = wordScale,
		flashes = 0,
		score = score,
		copies = {},
		shown = {},
		base = nil,
		face = nil,
		big = false,
		tween = nil,
	}
	return setmetatable(fields, FaceCam)
end

local function clearCopies(self: FaceCam)
	for _, item in self.shown do
		item:Destroy()
	end
	table.clear(self.shown)
	table.clear(self.copies)
	self.base = nil
	self.face = nil
end

-- Only what draws: no scripts (a LocalScript would run inside PlayerGui), sounds or effects riding along.
local function stripToLooks(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("ParticleEmitter") then
			item:Destroy()
		end
	end
end

local function pair(self: FaceCam, source: BasePart, copy: BasePart)
	table.insert(self.copies, {
		source = source,
		copy = copy,
		sourceMesh = source:FindFirstChildOfClass("SpecialMesh"),
		copyMesh = copy:FindFirstChildOfClass("SpecialMesh"),
	})
end

-- Shows this locomotive (the player's own); replaces the one shown before.
function FaceCam.show(self: FaceCam, locomotive: Model)
	clearCopies(self)
	local base = locomotive:FindFirstChild(Names.BasePart)
	if not (base and base:IsA("BasePart")) then
		self.gui.Enabled = false
		return
	end
	self.base = base
	self.viewport.LightDirection = base.CFrame:VectorToWorldSpace(Config.FaceCam.LightDirection)

	-- The avatar is copied as one whole model (Humanoid, BodyColors and clothes included). Copies of single body parts
	-- lose the shirt and pants, and a head whose face is in its texture loses its skin colour and draws white (both
	-- seen in Studio); the whole copy keeps both.
	local avatar = PartUtil.avatarOf(locomotive)
	local avatarCopy = if avatar then avatar:Clone() else nil
	if avatar and avatarCopy then
		stripToLooks(avatarCopy)
		for _, part in avatar:GetChildren() do
			local copy = avatarCopy:FindFirstChild(part.Name)
			if part:IsA("BasePart") and copy and copy:IsA("BasePart") and part:GetAttribute(Names.RestCFrame) ~= nil then
				pair(self, part, copy)
				if part.Name == Names.AvatarHead then
					self.face = part
				end
			end
		end
		avatarCopy.Parent = self.world
		table.insert(self.shown, avatarCopy)
	end

	-- The train parts, one copy each.
	for _, item in locomotive:GetDescendants() do
		local inAvatar = avatar ~= nil and item:IsDescendantOf(avatar)
		local seen = item:GetAttribute(Names.CarPart) ~= true and item:GetAttribute(Names.Walkable) ~= true -- the locomotive only
		if item:IsA("BasePart") and not inAvatar and seen and item:GetAttribute(Names.RestCFrame) ~= nil then
			local copy = item:Clone()
			stripToLooks(copy)
			for _, child in copy:GetChildren() do
				if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")) then
					child:Destroy()
				end
			end
			copy.Parent = self.viewport
			table.insert(self.shown, copy)
			pair(self, item, copy)
		end
	end
	self.gui.Enabled = true
end

function FaceCam.hide(self: FaceCam)
	clearCopies(self)
	self.gui.Enabled = false
end

-- Bigger while the locomotive is flat (or crashed); back with a little bounce.
function FaceCam.setBig(self: FaceCam, big: boolean)
	if big == self.big then
		return
	end
	self.big = big
	local c = Config.FaceCam
	if self.tween then
		self.tween:Cancel()
	end
	local info = if big
		then TweenInfo.new(c.GrowSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		else TweenInfo.new(c.ShrinkSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(self.frame, info, { Size = sizeFor(if big then c.BigHeight else c.Height) })
	self.tween = tween
	tween:Play()
end

-- A short word popping up over the window (a crash, a pass), fading after Config.FaceCam.FlashSeconds.
function FaceCam.flash(self: FaceCam, text: string, color: Color3)
	self.flashes += 1
	local mine = self.flashes
	local word = self.word
	word.Text = text
	word.TextColor3 = color
	word.TextTransparency = 0
	self.wordStroke.Transparency = 0
	self.wordScale.Scale = 0.4
	TweenService:Create(self.wordScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(Config.FaceCam.FlashSeconds, function()
		if self.flashes == mine then
			local fade = TweenInfo.new(0.3)
			TweenService:Create(word, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(self.wordStroke, fade, { Transparency = 1 }):Play()
		end
	end)
end

-- mail: the bags taken, or nil for a train without a cowboy (no mail then).
function FaceCam.setScore(self: FaceCam, passed: number, crashes: number, mail: number?)
	self.score.Text = if mail
		then string.format("통과 %d · 쾅 %d · 우편 %d", passed, crashes, mail)
		else string.format("통과 %d · 쾅 %d", passed, crashes)
end

function FaceCam.update(self: FaceCam)
	local base = self.base
	if not base then
		return
	end
	for _, pairing in self.copies do
		local source, copy = pairing.source, pairing.copy
		if copy.Size ~= source.Size then
			copy.Size = source.Size
			local sourceMesh, copyMesh = pairing.sourceMesh, pairing.copyMesh
			if sourceMesh and copyMesh then
				copyMesh.Scale = sourceMesh.Scale
			end
		end
		if copy.CFrame ~= source.CFrame then
			copy.CFrame = source.CFrame
		end
		if copy.Transparency ~= source.Transparency then
			copy.Transparency = source.Transparency
		end
	end
	-- Keep the face in the middle while it squashes and springs back.
	local face = self.face
	local focus = if face then face.Position else base.Position
	local direction = base.CFrame:VectorToWorldSpace(Config.FaceCam.ViewDirection.Unit)
	self.camera.CFrame = CFrame.lookAt(focus + direction * Config.FaceCam.Distance, focus)
end

return FaceCam
