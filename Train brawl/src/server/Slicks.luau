--!strict
-- Oil slicks on the server (a weapon of style "pour", Config.Weapons: radius, ahead, lasts): poured `ahead` of its
-- pourer (short of a wall), a dark shiny puddle lies on the flat top there for `lasts` seconds, fading at the end; none
-- over a gap or on the sand (it runs away). Every other fighter whose feet are on the ground in it slips (handed to the
-- caller, with a point behind them along the way they were going: they fall that way; standing still, away from the
-- middle), at most once every Config.Thrown.SlipEvery on the same slick. Seen only, never collides (Names.SlickPart;
-- DropShow sounds it). clear() takes every slick away (the round is over).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local ArenaRay = require(shared:WaitForChild("ArenaRay"))

local Slicks = {}

local OIL = Color3.fromRGB(28, 24, 20)
local FLAT = 0.7 -- a slick lies only where the surface's normal points up at least this much
local FEET = 4 -- a fighter's middle this far above the slick or less, on the ground, stands in it
local FADE = 1 -- the slick fades out over its last this many seconds
local MOVING = 2 -- slower than this along the ground counts as standing still

type Lying = { part: BasePart, connection: RBXScriptConnection }
local lying: { Lying } = {}

local function stop(slick: Lying)
	slick.connection:Disconnect()
	slick.part:Destroy()
	local index = table.find(lying, slick)
	if index then
		table.remove(lying, index)
	end
end

-- Pours a slick of weapon `w` from `attacker` (standing at `root`) along the flat `facing` (length 1), in `parent`, on
-- `arena`'s flat tops. `fighters()` are those who can slip; `slip(victim, from)` for each one who does.
function Slicks.pour(parent: Instance, arena: Instance, fighters: () -> { Model }, attacker: Model, root: Vector3, facing: Vector3, w: WeaponRules.Weapon, slip: (Model, Vector3) -> ())
	local radius = assert(w.radius, "pour.radius")
	local lasts = assert(w.lasts, "pour.lasts")
	local params = ArenaRay.params()
	local spot = root + facing * assert(w.ahead, "pour.ahead")
	local blocked = ArenaRay.hit(root, spot, arena, params)
	if blocked then
		spot = blocked.Position - facing * 0.5
	end
	local floor = ArenaRay.floor(spot, 1.5, 8, arena, params)
	if not floor or floor.Normal.Y < FLAT or floor.Position.Y <= Config.Arena.GroundY + 0.5 then
		return
	end
	local center = floor.Position
	local part = PartUtil.decor(Names.SlickPart, Vector3.new(0.06, radius * 2, radius * 2), CFrame.new(center + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), OIL, Enum.Material.Glass, parent, Enum.PartType.Cylinder)
	part.Reflectance = 0.2
	part.Transparency = 0.05
	local slipped: { [Model]: number } = {}
	local started = os.clock()
	local fading = false
	local slick: Lying
	slick = {
		part = part,
		connection = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - started >= lasts then
				stop(slick)
				return
			end
			if not fading and now - started >= lasts - FADE then
				fading = true
				TweenService:Create(part, TweenInfo.new(FADE), { Transparency = 1 }):Play()
			end
			for _, model in fighters() do
				local body = if model ~= attacker then CharacterParts.body(model) else nil
				local last = slipped[model]
				if body and (not last or now - last >= Config.Thrown.SlipEvery) and body.humanoid.FloorMaterial ~= Enum.Material.Air then
					local at = body.root.Position
					local rise = at.Y - center.Y
					if rise >= 0 and rise <= FEET and WeaponRules.inArea(center.X, center.Y, center.Z, at.X, center.Y, at.Z, radius, 1) then
						slipped[model] = now
						local v = body.root.AssemblyLinearVelocity
						local way = Vector3.new(v.X, 0, v.Z)
						if way.Magnitude < MOVING then
							way = Vector3.new(at.X - center.X, 0, at.Z - center.Z)
						end
						slip(model, at - (if way.Magnitude > 1e-3 then way.Unit else facing) * 2)
					end
				end
			end
		end),
	}
	table.insert(lying, slick)
end

-- Takes every slick away.
function Slicks.clear()
	for _, slick in table.clone(lying) do
		stop(slick)
	end
end

return Slicks
