--!strict
-- The comic burst where a hit lands, on this client: a bright centre with thin long and short rays rooted in it (a
-- comic hit spark) that pops out and fades in Config.Feedback.BurstSeconds (drawn with frames, no uploaded image). A
-- light hit's is white, a launch's gold, a crowd's launch (the guard against being ganged up on) red, so a launch and
-- why it happened read at a glance; a heavier weapon's is bigger. The rays on the side the hit pushed toward are
-- longer, so the blow's direction shows. Every burst is turned a little differently and its rays vary in length, so a
-- flurry of hits does not stamp the same picture again and again. It sits on the victim toward whoever struck it, at
-- chest height (on the victim for a blast), faces the camera and is drawn over the bodies (it lives a fifth of a
-- second; past MAX_DISTANCE it is not drawn). Built once as a template and cloned, with one fade for the whole burst.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local UiStyle = require(shared:WaitForChild("UiStyle"))

local ImpactBurst = {}

local RAYS = 9 -- long rays (as many short ones between them)
local MAX_DISTANCE = 120
local PUSH_STRETCH = 0.6 -- rays toward the push grow up to this much longer
-- Each kind of burst: its width (studs), centre and ray colours.
local STYLES: { [string]: { size: number, centre: Color3, ray: Color3 } } = {
	light = { size = 2.4, centre = Color3.fromRGB(255, 255, 255), ray = Color3.fromRGB(255, 244, 214) },
	launch = { size = 3.8, centre = Color3.fromRGB(255, 255, 240), ray = Config.Feedback.Gold },
	crowd = { size = 3.8, centre = Color3.fromRGB(255, 236, 220), ray = Color3.fromRGB(255, 104, 72) },
}
-- How much bigger each weapon's burst is.
local WEAPON_SIZE: { [string]: number } = { Fist = 0.85, Bat = 1, GoldBar = 1.1, Hammer = 1.25, Dynamite = 1.3 }

local function frame(parent: Instance, name: string, outlined: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	if outlined then
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = UiStyle.Outline
		edge.Thickness = 1.5
		edge.Parent = f
	end
	f.Parent = parent
	return f
end

-- The template: an anchor part holding a billboard with a fading group, a scale, the rays and the centre.
local template: Part
do
	template = Instance.new("Part")
	template.Name = "TrainBrawlBurst"
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Transparency = 1
	template.Size = Vector3.one
	local gui = Instance.new("BillboardGui")
	gui.Name = "Gui"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_DISTANCE
	gui.Parent = template
	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = group
	for i = 1, RAYS * 2 do
		frame(group, "Ray" .. i, i % 2 == 1) -- outlines on the long rays only
	end
	local centre = frame(group, "Centre", true)
	centre.Size = UDim2.fromScale(0.34, 0.34)
	centre.Position = UDim2.fromScale(0.5, 0.5)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = centre
end

-- Where a hit's burst shows on `victim`: toward whoever struck it (`from`; straight on the victim when nil), at chest
-- height.
function ImpactBurst.at(victim: Model, from: Vector3?): Vector3
	local at = victim:GetPivot().Position
	local toward = if from then Vector3.new(from.X - at.X, 0, from.Z - at.Z) else Vector3.zero
	local side = if toward.Magnitude > 1e-3 then toward.Unit * 1.1 else Vector3.zero
	return at + side + Vector3.new(0, 0.7, 0)
end

-- A burst of `kind` ("light", "launch" or "crowd") at `at`, from a hit of `weapon` that pushed along `push` (nil: no
-- direction).
function ImpactBurst.play(at: Vector3, kind: string, weapon: string, push: Vector3?)
	local style = STYLES[kind] or STYLES.light
	local burst = template:Clone()
	burst.CFrame = CFrame.new(at)
	local gui = burst:FindFirstChild("Gui") :: BillboardGui
	local group = gui:FindFirstChild("Group") :: CanvasGroup
	local scale = group:FindFirstChildOfClass("UIScale") :: UIScale
	local size = style.size * (WEAPON_SIZE[weapon] or 1)
	gui.Size = UDim2.fromScale(size, size) -- in studs
	-- The push as seen on screen (0 = straight up, clockwise), when there is one.
	local pushAngle: number? = nil
	if push and push.Magnitude > 1e-3 then
		local camera = Workspace.CurrentCamera.CFrame
		local x, y = push:Dot(camera.RightVector), push:Dot(camera.UpVector)
		if math.abs(x) + math.abs(y) > 1e-3 then
			pushAngle = math.deg(math.atan2(x, y))
		end
	end
	local turn = math.random() * 360 / RAYS -- a different turn each time
	for i = 1, RAYS * 2 do
		local ray = group:FindFirstChild("Ray" .. i) :: Frame
		local long = i % 2 == 1
		local angle = turn + (i - 1) * 180 / RAYS + (math.random() - 0.5) * 8 -- not quite even
		local length = if long then 0.3 + math.random() * 0.12 else 0.15 + math.random() * 0.07
		if pushAngle then
			local off = math.abs((angle - pushAngle + 180) % 360 - 180) -- how far from the push, 0..180 degrees
			length *= 1 + PUSH_STRETCH * math.max(0, 1 - off / 60)
		end
		local r = math.rad(angle)
		local reach = 0.12 + length / 2 -- the inner end inside the centre
		ray.Size = UDim2.fromScale(if long then 0.07 else 0.05, length)
		ray.Position = UDim2.fromScale(0.5 + math.sin(r) * reach, 0.5 - math.cos(r) * reach)
		ray.Rotation = angle
		ray.BackgroundColor3 = style.ray
	end
	local centre = group:FindFirstChild("Centre") :: Frame
	centre.BackgroundColor3 = style.centre
	scale.Scale = 0.5
	burst.Parent = Workspace
	local seconds = Config.Feedback.BurstSeconds
	TweenService:Create(scale, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	TweenService:Create(group, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds * 0.4), { GroupTransparency = 1 }):Play()
	Debris:AddItem(burst, seconds + 0.05)
end

return ImpactBurst
