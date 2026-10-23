--!strict
-- The face window: a small framed view at the top middle of the screen that shows the player's own locomotive from
-- the front, because the play camera looks from behind and the face is out of sight. It grows while the locomotive
-- is flat. A ViewportFrame only draws its own children, so the window holds copies of the locomotive's moving parts
-- and copies their size, place and transparency from the real ones (which LocomotiveAnimator moves) in update();
-- call it after the animator every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local FaceCam = {}
FaceCam.__index = FaceCam

local WHITE = Color3.new(1, 1, 1)

type Copy = { source: BasePart, copy: BasePart, sourceMesh: SpecialMesh?, copyMesh: SpecialMesh? }

type Fields = {
	gui: ScreenGui,
	frame: Frame,
	viewport: ViewportFrame, -- the locomotive
	world: WorldModel, -- inside the viewport: holds the avatar copy
	faceView: ViewportFrame, -- the head alone, drawn over the locomotive (see show)
	camera: Camera, -- shared by both views
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

local function newView(name: string, parent: Instance): ViewportFrame
	local c = Config.FaceCam
	local view = Instance.new("ViewportFrame")
	view.Name = name
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(0.9, 0.9)
	view.Ambient = c.Ambient
	view.LightColor = c.Light
	view.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = view
	return view
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
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, c.Margin)
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

	local viewport = newView("View", frame)
	viewport.BackgroundColor3 = c.Sky
	viewport.ZIndex = 1
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local faceView = newView("FaceView", frame)
	faceView.BackgroundTransparency = 1
	faceView.ZIndex = 2 -- over the locomotive's view, whose sky would otherwise hide the head

	local camera = Instance.new("Camera")
	camera.FieldOfView = c.FieldOfView
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	faceView.CurrentCamera = camera

	gui.Parent = playerGui
	local fields: Fields = {
		gui = gui,
		frame = frame,
		viewport = viewport,
		world = world,
		faceView = faceView,
		camera = camera,
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

local function hideFace(part: BasePart)
	part.Transparency = 1
	for _, decal in part:GetDescendants() do
		if decal:IsA("Decal") then
			decal.Transparency = 1
		end
	end
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
	local c = Config.FaceCam
	local light = base.CFrame:VectorToWorldSpace(c.LightDirection)
	self.viewport.LightDirection = light
	self.faceView.LightDirection = light
	self.faceView.ImageColor3 = WHITE

	-- The avatar is copied as one whole model (Humanoid and clothes included): copies of single body parts lose the
	-- shirt and pants (seen in Studio), so the sleeves and the cab would show bare skin.
	local avatar: Model? = nil
	for _, child in locomotive:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			avatar = child
		end
	end
	local avatarCopy = if avatar then avatar:Clone() else nil
	if avatar and avatarCopy then
		stripToLooks(avatarCopy)
		for _, part in avatar:GetChildren() do
			local copy = avatarCopy:FindFirstChild(part.Name)
			if part:IsA("BasePart") and copy and copy:IsA("BasePart") and part:GetAttribute(Names.RestCFrame) ~= nil then
				if part.Name == Names.AvatarHead then
					hideFace(copy) -- drawn by the face view instead
				else
					pair(self, part, copy)
				end
			end
		end
		avatarCopy.Parent = self.world
		table.insert(self.shown, avatarCopy)
	end

	for _, item in locomotive:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute(Names.RestCFrame) ~= nil then
			local inAvatar = avatar ~= nil and item:IsDescendantOf(avatar)
			local isHead = inAvatar and item.Name == Names.AvatarHead
			if isHead or not inAvatar then
				local copy = item:Clone()
				stripToLooks(copy)
				for _, child in copy:GetChildren() do
					if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")) then
						child:Destroy()
					end
				end
				if isHead then
					self.face = item
					-- A head whose face is in its texture (most new avatars) gets its skin colour from the avatar, which a
					-- lone copy in a ViewportFrame loses: the skin draws white. Tinting the head's own view by the skin
					-- colour brings it back and keeps the dark eyes and mouth dark; but it also tints the whites of the
					-- eyes and any coloured lips, and a texture that already has the skin painted in comes out darker.
					-- The head is the frontmost part from this angle, so its view on top looks the same.
					if item:IsA("MeshPart") and item.TextureID ~= "" then
						self.faceView.ImageColor3 = item.Color
					end
					copy.Parent = self.faceView
				else
					copy.Parent = self.viewport
				end
				table.insert(self.shown, copy)
				pair(self, item, copy)
			end
		end
	end
	self.gui.Enabled = true
end

function FaceCam.hide(self: FaceCam)
	clearCopies(self)
	self.gui.Enabled = false
end

-- Bigger while the locomotive is flat; back with a little bounce.
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
