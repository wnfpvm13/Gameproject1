--!strict
-- The player's own cowboy on a train's roof: a low bridge passing over a cowboy who is too tall there (in the air, or
-- not lying flat on a flat roof) knocks them off backward ("splat"); a cowboy who has left the train ("fell") or was
-- knocked off goes back onto the last car after Config.Cowboy.SplatSeconds; a rolling barrel reaching the cowboy's legs
-- in its lane knocks them off too ("barrel"); a cowboy whose middle comes close to the next mail bag picks it up
-- ("mail", reported to the server). The player's client moves its own character, so this runs there.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))
local BarrelTrack = require(shared:WaitForChild("BarrelTrack"))

local CowboyRules = {}
CowboyRules.__index = CowboyRules

export type Event = "splat" | "fell" | "barrel" | "mail"

type Fields = {
	train: Model,
	base: BasePart,
	backUntil: number?, -- os.clock time the cowboy goes back onto the last car (while knocked off or fallen)
	picked: { index: number, at: number, version: number }?, -- the bag last reported (os.clock, run version)
	roofs: { BasePart }, -- the car roof floors the barrels roll on (BarrelTrack.roofs)
}
export type Rules = typeof(setmetatable({} :: Fields, CowboyRules))

function CowboyRules.new(train: Model, base: BasePart): Rules
	local fields: Fields = { train = train, base = base, backUntil = nil, picked = nil, roofs = BarrelTrack.roofs(train) }
	return setmetatable(fields, CowboyRules)
end

-- The cowboy's top above the rails: the head's top, or, standing on a roof and lying down by `lie` (0..1), between
-- standing up and lying flat on it.
local function topOf(character: Model, floor: BasePart?, lie: number, baseY: number): number?
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local headTop = head.Position.Y + head.Size.Y / 2 - baseY
	if not floor or lie <= 0 then
		return headTop
	end
	local roof = floor.Position.Y + floor.Size.Y / 2 - baseY
	local flat = roof + Config.Cowboy.FlatHeight
	return headTop + (flat - headTop) * lie
end

local function putBack(self: Rules, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local floor = PartUtil.lastRoofFloor(self.train, Names.Walkable, Names.RestCFrame)
	if not (root and root:IsA("BasePart") and humanoid and floor) then
		return
	end
	humanoid.PlatformStand = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(PartUtil.aboveFloor(floor.CFrame, floor.Size, Config.Cowboy.SpawnLift))
end

-- Knocked off backward, stiff (PlatformStand), and back on the last car after Config.Cowboy.SplatSeconds.
local function knockOff(self: Rules, humanoid: Humanoid, root: BasePart)
	local c = Config.Cowboy
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = self.base.CFrame:VectorToWorldSpace(Vector3.new(0, c.KnockUp, c.KnockBack))
	self.backUntil = os.clock() + c.SplatSeconds
end

-- The player stops riding this train (it went, or a new one came): a cowboy still knocked stiff gets up again.
function CowboyRules.stop(self: Rules, character: Model?)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if self.backUntil and humanoid then
		humanoid.PlatformStand = false
	end
	self.backUntil = nil
end

-- Every frame, after RoofRider. distance: the train's run distance (nil before the run); floor: the roof floor under
-- the feet; lie: how far the cowboy lies down. Returns what just happened, if anything (and the bag, for "mail").
function CowboyRules.update(self: Rules, character: Model?, floor: BasePart?, lie: number, distance: number?): (Event?, number?)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and root:IsA("BasePart") and humanoid) then
		return nil
	end
	local backUntil = self.backUntil
	if backUntil then
		if os.clock() >= backUntil then
			self.backUntil = nil
			putBack(self, character)
		end
		return nil
	end
	local c = Config.Cowboy
	local baseCFrame = self.base.CFrame
	local here = baseCFrame:PointToObjectSpace(root.Position)
	-- Off the train: the feet down by the rails and on no roof (an R6 HipHeight leaves out the 2-stud legs).
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local feet = here.Y - humanoid.HipHeight - legs - root.Size.Y / 2
	if not floor and feet < c.FellBelow then
		self.backUntil = os.clock() + c.SplatSeconds
		return "fell"
	end
	-- A bridge over the cowboy (its span along the track, locomotive space: ahead is -Z).
	if distance then
		local b = Config.Bridge
		-- The run distance at the cowboy's place is distance - here.Z; the first bridge not yet past it is the one.
		local margin = c.BridgeMargin
		local index = CourseMath.nextBridge(distance - here.Z - margin, b.FirstAt, b.Gaps, b.Depth, 0)
		local middle = distance - CourseMath.bridgeAt(index, b.FirstAt, b.Gaps)
		local over = math.abs(here.Z - middle) <= b.Depth / 2 + margin and math.abs(here.X) <= b.Span / 2 + b.PierWidth + margin
		local top = topOf(character, floor, lie, baseCFrame.Position.Y)
		if top and over and top > b.Clearance then
			knockOff(self, humanoid, root) -- stiff as a board, carried off by the girder
			return "splat"
		end
		-- A rolling barrel in the cowboy's lane, at the legs: jumped clear only with the feet above its top as drawn (on the
		-- roof under it now). While the run is held or waiting to go again the barrels stand still and knock no one.
		local run, version = TrainState.run(self.train)
		if run and run.speed > 0 and Workspace:GetServerTimeNow() >= run.start then
			local k = Config.Barrels
			for _, barrel in BarrelTrack.active(self.train, distance) do
				local roof = BarrelTrack.roofTopAt(self.roofs, baseCFrame, barrel.z)
				local along = math.abs(here.Z - barrel.z) <= k.Radius + k.HitAlong
				local across = math.abs(here.X - barrel.lane * k.LaneX) <= k.Length / 2 + k.HitAcross
				if roof and along and across and feet < roof + k.Radius * 2 then
					knockOff(self, humanoid, root)
					return "barrel"
				end
			end
		end
		-- The next bag: picked up when the cowboy's middle passes close to it. Reported once; again after a second (if the
		-- server did not take it, e.g. it came in too late) or once the run has changed.
		local nextBag = PartUtil.number(self.train, Names.MailNext)
		local last = self.picked
		local waiting = last ~= nil and last.index == nextBag and last.version == version and os.clock() - last.at < c.ReportAgain
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
		if nextBag and not waiting and torso and torso:IsA("BasePart") then
			local m = Config.Mail
			local at, side = CourseMath.mailAt(nextBag, b.FirstAt, b.Gaps)
			local bag = Vector3.new(side * m.BagX, m.BagY, distance - at)
			if (baseCFrame:PointToObjectSpace(torso.Position) - bag).Magnitude <= m.Reach then
				self.picked = { index = nextBag, at = os.clock(), version = version }
				return "mail", nextBag
			end
		end
	end
	return nil
end

return CowboyRules
