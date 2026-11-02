--!strict
-- The golden crate on this client (decision 25; the server's WeaponDrops drops and gives it). While Workspace has
-- Names.GoldenAt (when it starts falling) and GoldenSpot (where), a tall beam of golden light stands there with a
-- ring on the roof, and a banner counts down to it ("황금 상자가 온다! 가운데 기차") and then says how to take it; a
-- brass bell rings when it is first told. When someone takes it (Names.GoldenTaken: "name|weapon"), everyone is told
-- who got what for a moment, with a cheer. Nothing here collides or is seen by raycasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local GoldenShow = {}
GoldenShow.__index = GoldenShow

local BEAM_HEIGHT = 90
local BEAM_WIDTH = 2.2
local RING = 6 -- the ring on the roof, across
local TAKEN_SECONDS = 4 -- who took it stays up this long

type Fields = {
	beam: Part,
	ring: Part,
	banner: TextLabel,
	told: number?, -- the GoldenAt whose bell has rung
	taken: string?, -- the GoldenTaken last shown
	takenUntil: number, -- os.clock() its line goes
}
export type Show = typeof(setmetatable({} :: Fields, GoldenShow))

function GoldenShow.new(playerGui: Instance): Show
	local gold = Config.Drops.Golden.Color
	local folder = PartUtil.folder(Workspace, "TrainBrawlGolden")
	folder:ClearAllChildren()
	local beam = PartUtil.decor("GoldenBeam", Vector3.new(BEAM_HEIGHT, BEAM_WIDTH, BEAM_WIDTH), CFrame.identity, gold, Enum.Material.Neon, nil, Enum.PartType.Cylinder)
	beam.Transparency = 0.7
	local ring = PartUtil.decor("GoldenRing", Vector3.new(0.12, RING, RING), CFrame.identity, gold, Enum.Material.Neon, nil, Enum.PartType.Cylinder)
	ring.Transparency = 0.55
	beam.Parent, ring.Parent = nil, nil
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlGolden"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local banner = UiStyle.label(gui, "Banner", UDim2.fromOffset(620, 34), 28, gold)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 176) -- (under a bridge's warning at 136)
	banner.Visible = false
	local fields: Fields = { beam = beam, ring = ring, banner = banner, told = nil, taken = nil, takenUntil = 0 }
	return setmetatable(fields, GoldenShow)
end

-- Every frame: the beam and the banner while the golden crate is coming or lying there; who took it, for a moment.
function GoldenShow.update(self: Show)
	local folder = Workspace:FindFirstChild("TrainBrawlGolden") or Workspace
	local at = PartUtil.number(Workspace, Names.GoldenAt)
	local spot = Workspace:GetAttribute(Names.GoldenSpot)
	local taken = Workspace:GetAttribute(Names.GoldenTaken)
	local now = Workspace:GetServerTimeNow()
	if typeof(taken) == "string" and taken ~= self.taken then
		self.taken = taken
		self.takenUntil = os.clock() + TAKEN_SECONDS
		local name, weapon = string.match(taken, "^(.*)|([^|]*)$")
		self.banner.Text = Words.goldenTaken(name or taken, weapon or "")
		SoundBank.play("Cheer")
	elseif taken == nil then
		self.taken = nil
	end
	if at and typeof(spot) == "Vector3" then
		if self.told ~= at then
			self.told = at
			SoundBank.play("GoldenBell")
		end
		local pulse = 0.68 + 0.1 * math.sin(now * 6) -- a soft column of light, not a solid pole
		self.beam.CFrame = CFrame.new(spot + Vector3.new(0, BEAM_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		self.beam.Transparency = pulse
		self.ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		self.beam.Parent, self.ring.Parent = folder, folder
		if os.clock() >= self.takenUntil then
			local left = at - now
			self.banner.Text = if left > 0 then Words.goldenComing(math.ceil(left)) else Words.GoldenHere
		end
		self.banner.Visible = true
		return
	end
	self.beam.Parent, self.ring.Parent = nil, nil
	self.banner.Visible = os.clock() < self.takenUntil
end

return GoldenShow
