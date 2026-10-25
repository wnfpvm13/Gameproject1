--!strict
-- The canyon the trains run through, drawn on this client from CanyonLayout (Config.Canyon): sandstone walls either
-- side of the arena, stretch after stretch of stepped coloured layers with a rubble slope at the foot, ribs of rock
-- and now and then a rock spire, sliding past like the rest of the scenery (ScrollLoop at Config.Run.Speed; each
-- stretch wraps around as one). The stretches are laid out far ahead and behind, so the wrap-around happens deep in
-- the haze (Lighting's Atmosphere); the server's sand reaches under all of it (ArenaBuilder). Nothing here collides
-- or casts a shadow (in the low sun a wall's shadow would reach across the trains).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ScrollLoop = require(shared:WaitForChild("ScrollLoop"))
local CanyonLayout = require(shared:WaitForChild("CanyonLayout"))

local Canyon = {}
Canyon.__index = Canyon

type Fields = {
	folder: Folder,
	loop: ScrollLoop.Loop,
}
export type View = typeof(setmetatable({} :: Fields, Canyon))

function Canyon.new(): View
	local c = Config.Canyon
	local old = Workspace:FindFirstChild(Names.CanyonFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.CanyonFolder)
	local loop = ScrollLoop.new(c.Ahead, c.Behind)
	local material = Enum.Material.Sandstone
	for _, piece in CanyonLayout.pieces(c, Config.Arena.GroundY) do
		local color = c.Colors[piece.color]
		local at = CFrame.new(piece.x, piece.y, piece.z)
		if piece.wedge then
			-- The wedge's back (+Z) turned toward the wall, so the slope runs down toward the track.
			local part = PartUtil.decorWedge(piece.kind, Vector3.new(piece.length, piece.height, piece.width), CFrame.identity, color, material, folder)
			loop:add(part, at * CFrame.Angles(0, piece.side * math.pi / 2, 0), piece.anchor)
		else
			local part = PartUtil.decor(piece.kind, Vector3.new(piece.width, piece.height, piece.length), CFrame.identity, color, material, folder)
			loop:add(part, at * CFrame.Angles(0, piece.yaw, 0), piece.anchor)
		end
	end
	local fields: Fields = { folder = folder, loop = loop }
	local self = setmetatable(fields, Canyon)
	self:update(0)
	return self
end

-- Slides the canyon backward by this frame's run (dt seconds).
function Canyon.update(self: View, dt: number)
	self.loop:update(dt, Config.Run.Speed)
end

function Canyon.destroy(self: View)
	self.folder:Destroy()
end

return Canyon
