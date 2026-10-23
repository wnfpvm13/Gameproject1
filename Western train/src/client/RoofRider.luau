--!strict
-- Keeps a cowboy standing on a train's roof as the roof squashes and springs back. Each frame, after the train has
-- been drawn, it finds the roof floor under the cowboy's feet (the train's Names.Walkable parts) and, for the
-- player's own character, moves the character with that floor: up and down with its top, and along with its stretch.
-- Moving the character by the floor's change (not by physics) means a roof springing up never flings the cowboy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local RoofRider = {}
RoofRider.__index = RoofRider

type Fields = {
	params: RaycastParams,
	floor: BasePart?, -- the floor under the feet in the last frame
	floorCFrame: CFrame, -- that floor's place and size then
	floorSize: Vector3,
}
export type Rider = typeof(setmetatable({} :: Fields, RoofRider))

function RoofRider.new(train: Model): Rider
	local floors: { Instance } = {}
	for _, item in train:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute(Names.Walkable) == true then
			table.insert(floors, item)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = floors
	local fields: Fields = { params = params, floor = nil, floorCFrame = CFrame.new(), floorSize = Vector3.one }
	return setmetatable(fields, RoofRider)
end

-- The roof floor straight under the character's feet (within Config.Cowboy.OnRoof, plus `slack`), or nil. An R6
-- character's HipHeight leaves out its 2-stud legs; an R15 one's includes them.
local function floorUnder(self: Rider, root: BasePart, humanoid: Humanoid, slack: number): BasePart?
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local reach = humanoid.HipHeight + legs + root.Size.Y / 2 + Config.Cowboy.OnRoof + slack
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), self.params)
	local part = hit and hit.Instance
	return if part and part:IsA("BasePart") then part else nil
end

-- Call every frame after the train is drawn. carry: move the character with the floor (only for the player's own
-- character: other characters are moved by their own players). Returns the floor the character stands on, or nil.
function RoofRider.update(self: Rider, character: Model?, carry: boolean): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		self.floor = nil
		return nil
	end
	local floor = self.floor
	if carry and floor then
		-- Where the feet were on the floor last frame, in shares of its size, is where they are on it now.
		local before = self.floorCFrame:PointToObjectSpace(root.Position) / self.floorSize
		local after = floor.CFrame:PointToWorldSpace(before * floor.Size)
		local topBefore = self.floorCFrame.Position.Y + self.floorSize.Y / 2
		local topAfter = floor.Position.Y + floor.Size.Y / 2
		local shift = Vector3.new(after.X - root.Position.X, topAfter - topBefore, after.Z - root.Position.Z)
		if shift.Magnitude > 1e-4 then
			root.CFrame += shift
		end
	end
	local now = floorUnder(self, root, humanoid, if carry then 0 else Config.Cowboy.OthersReach)
	self.floor = now
	if now then
		self.floorCFrame = now.CFrame
		self.floorSize = now.Size
	end
	return now
end

return RoofRider
