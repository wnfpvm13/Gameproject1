--!strict
-- A back car coming off, on this client (persona fix 6; the server's Uncoupling moves the real car). When a car is
-- marked to let go (Names.CarLeavingAt on its model in the arena), a red-and-cream striped band pulses across its roof
-- at the coupling with the car ahead (where to jump), its coupler clangs and a banner tells everyone ("맨 뒤 칸이
-- 떨어져 나간다! 앞 칸으로!"); when it lets go, steam hisses. Its dressing (CarDecor's model for it) and the planks'
-- straps on it follow the real car and planks as they move (how far each has moved from where the layout put it), and
-- go back with them at the next round. away() says which cars are leaving or gone, for EdgeWarning.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local UncoupleShow = {}
UncoupleShow.__index = UncoupleShow

-- Yellow and black like a hazard sign: not the red and cream of a roof edge's band (EdgeWarning), which a tester took for
-- the same thing (2026-10-31).
local YELLOW = Color3.fromRGB(255, 198, 24)
local BLACK = Color3.fromRGB(34, 28, 24)
local STRIPES = 9 -- (a ColorSequence holds at most 20 keys: two per stripe)
local BAND = 2 -- the warning band's width along the track, studs
local BANNER_SECONDS = 3

-- A car this client follows: its train and number, the server's model, the dressing's model and where it was built,
-- the planks on it (the server part and the straps' model, each with where it was built), the warning band (while
-- warned) and what was heard.
type Follow = {
	train: number,
	car: number,
	model: Model,
	roofHome: Vector3, -- where the car's roof was built (the layout's place: ArenaBuilder's "Roof" part)
	firstPart: BasePart?, -- that roof, as the server moves it
	dressing: Model?,
	dressingHome: CFrame?,
	planks: { { part: BasePart, home: Vector3, straps: Model?, strapsHome: CFrame? } },
	band: Part?,
	warned: boolean,
	letGoHeard: boolean,
}
type Fields = { arena: Instance, decor: Instance, layout: ArenaLayout.Layout, follows: { Follow }, banner: TextLabel, bannerUntil: number }
export type Show = typeof(setmetatable({} :: Fields, UncoupleShow))

local function stripedBand(size: Vector3, cframe: CFrame): Part
	local part = PartUtil.decor("LeavingBand", size, cframe, YELLOW, Enum.Material.SmoothPlastic)
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	gui.LightInfluence = 1
	gui.Adornee = part
	gui.Parent = part
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = gui
	local keys = {}
	for i = 0, STRIPES - 1 do
		local color = if i % 2 == 0 then YELLOW else BLACK
		table.insert(keys, ColorSequenceKeypoint.new(if i == 0 then 0 else i / STRIPES + 1e-3, color))
		table.insert(keys, ColorSequenceKeypoint.new(if i == STRIPES - 1 then 1 else (i + 1) / STRIPES, color))
	end
	local stripes = Instance.new("UIGradient")
	stripes.Color = ColorSequence.new(keys)
	stripes.Parent = fill
	return part
end

-- arena: the server's arena folder (the cars' models); decor: CarDecor's folder; layout: where everything is.
function UncoupleShow.new(playerGui: Instance, arena: Instance, decor: Instance, layout: ArenaLayout.Layout): Show
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlUncouple"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local banner = UiStyle.label(gui, "Banner", UDim2.fromOffset(560, 34), 28, UiStyle.Red)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 96)
	banner.Text = Words.CarLeaving
	banner.Visible = false
	local fields: Fields = { arena = arena, decor = decor, layout = layout, follows = {}, banner = banner, bannerUntil = 0 }
	return setmetatable(fields, UncoupleShow)
end

-- The car this client follows for a marked model (made the first time it is seen marked).
local function follow(self: Show, train: number, car: number, model: Model): Follow
	for _, f in self.follows do
		if f.model == model then
			return f
		end
	end
	-- (Only cars behind the locomotive come off; each has a flat "Roof" part, ArenaBuilder.)
	local roof = model:FindFirstChild("Roof")
	local first: BasePart? = if roof and roof:IsA("BasePart") then roof else nil
	local place = self.layout.trains[train].cars[car]
	local dressing: Model? = nil
	local trainDecor = self.decor:FindFirstChild(Names.TrainModel .. train)
	local found = trainDecor and trainDecor:FindFirstChild(Names.CarModel .. car)
	if found and found:IsA("Model") then
		dressing = found
	end
	local planks = {}
	for _, number in ArenaLayout.planksOn(self.layout, train, car) do
		local plank = self.layout.planks[number]
		local home = Vector3.new(plank.x, plank.top + Config.Arena.PlankThickness / 2, plank.z)
		local part: BasePart? = nil
		for _, child in self.arena:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute(Names.PlankNumber) == number then
				part = child
			end
		end
		local straps = self.decor:FindFirstChild(Names.PlankPart .. number)
		if part then
			table.insert(planks, {
				part = part,
				home = home,
				straps = if straps and straps:IsA("Model") then straps else nil,
				strapsHome = if straps and straps:IsA("Model") then straps:GetPivot() else nil,
			})
		end
	end
	local f: Follow = {
		train = train,
		car = car,
		model = model,
		roofHome = Vector3.new(self.layout.trains[train].x, place.roof - 0.15, place.middle),
		firstPart = first,
		dressing = dressing,
		dressingHome = if dressing then dressing:GetPivot() else nil,
		planks = planks,
		band = nil,
		warned = false,
		letGoHeard = false,
	}
	table.insert(self.follows, f)
	return f
end

-- Whether car `car` of train `train` is coming off or gone (as the server marked it).
function UncoupleShow.away(self: Show, train: number, car: number): boolean
	local trainModel = self.arena:FindFirstChild(Names.TrainModel .. train)
	local model = trainModel and trainModel:FindFirstChild(Names.CarModel .. car)
	return model ~= nil and (model:GetAttribute(Names.CarLeavingAt) ~= nil or model:GetAttribute(Names.CarGone) == true)
end

-- Every frame.
function UncoupleShow.update(self: Show)
	local now = Workspace:GetServerTimeNow()
	for i, train in self.layout.trains do
		local trainModel = self.arena:FindFirstChild(Names.TrainModel .. i)
		for k, place in train.cars do
			local model = trainModel and trainModel:FindFirstChild(Names.CarModel .. k)
			local letGo = if model then PartUtil.number(model, Names.CarLeavingAt) else nil
			if model and model:IsA("Model") and letGo then
				local f = follow(self, i, k, model)
				if not f.warned then
					f.warned = true
					self.bannerUntil = os.clock() + BANNER_SECONDS
					self.banner.Visible = true
					UiStyle.pop(self.banner, 1.3)
					if f.firstPart then
						SoundBank.play("WheelHit", f.firstPart, 0.7)
					end
					-- Across its roof at the coupling with the car ahead (its front end).
					local band = stripedBand(Vector3.new(Config.Arena.RoofWidth, 0.05, BAND), CFrame.new(train.x, place.roof + 0.05, place.front + BAND / 2))
					band.Parent = self.decor
					f.band = band
				end
				local band = f.band
				if band then
					local fill = band:FindFirstChildWhichIsA("SurfaceGui", true)
					local frame = fill and fill:FindFirstChild("Fill")
					if frame and frame:IsA("Frame") then
						frame.BackgroundTransparency = 0.15 + 0.35 * (math.sin(os.clock() * 10) + 1) / 2
					end
				end
				if now >= letGo and not f.letGoHeard then
					f.letGoHeard = true
					if f.firstPart then
						SoundBank.play("Steam", f.firstPart, 0.8)
					end
				end
			end
		end
	end
	-- The dressing, the warning band and the planks' straps follow the real car and planks.
	for index = #self.follows, 1, -1 do
		local f = self.follows[index]
		local marked = f.model.Parent ~= nil and (f.model:GetAttribute(Names.CarLeavingAt) ~= nil or f.model:GetAttribute(Names.CarGone) == true)
		local shift = if f.firstPart and marked then f.firstPart.Position - f.roofHome else Vector3.zero
		local dressing, home = f.dressing, f.dressingHome
		if dressing and home then
			dressing:PivotTo(home + shift)
		end
		if f.band then
			local place = self.layout.trains[f.train].cars[f.car]
			f.band.CFrame = CFrame.new(self.layout.trains[f.train].x, place.roof + 0.05, place.front + BAND / 2) + shift
		end
		for _, plank in f.planks do
			local straps, strapsHome = plank.straps, plank.strapsHome
			if straps and strapsHome then
				straps:PivotTo(strapsHome + (if marked then plank.part.Position - plank.home else Vector3.zero))
			end
		end
		if not marked then
			if f.band then
				f.band:Destroy()
			end
			table.remove(self.follows, index) -- put back (the next round)
		end
	end
	if os.clock() >= self.bannerUntil then
		self.banner.Visible = false
	end
end

return UncoupleShow
