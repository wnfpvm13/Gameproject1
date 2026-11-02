--!strict
-- Where the weapon crates are when they are out of sight (persona fix 3, 2026-10-29: the testers picked a weapon up
-- twice in eight rounds and often never saw a crate). For every crate falling or lying on the trains that nobody has
-- taken (the crates folder, WeaponDrops' attributes) a gold chevron on a dark round plate sits at the screen's edge
-- pointing toward it (a bare thin chevron was small and read as an "L" in Studio), with
-- the weapon's name just inside it; once the crate is on screen its own name tag shows instead and the arrow goes. Shown
-- only while the player fights on the trains. Drawn with frames only (no uploaded image); the look is UiStyle's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local CrateArrows = {}
CrateArrows.__index = CrateArrows

-- The arrows stay this far in from the screen's sides, top (under the round's plates and status line) and bottom (over the health bar,
-- weapon and tickets); a crate inside that frame counts as on screen.
local EDGE = 64
local EDGE_TOP = 130
local EDGE_BOTTOM = 130
local PLATE = 38
local STROKE = Vector2.new(17, 6)
local LABEL_IN = 46 -- the name sits this far inward from its arrow
-- The bottom-right corner an arrow keeps out of: the music button (RoundAudio) and the touch buttons (attack, block,
-- roll: SwingInput, BlockInput, DodgeInput) - an arrow next to the music button read as a button (2026-10-31).
local KEEP_OUT = Vector2.new(300, 290) -- from the right and from the bottom

type Arrow = { plate: Frame, chevron: Frame, label: TextLabel }
type Fields = { gui: ScreenGui, folder: Instance, arrows: { [Model]: Arrow } }
export type Arrows = typeof(setmetatable({} :: Fields, CrateArrows))

-- One stroke of the chevron, centred at (x, y) in its box and turned `angle` degrees.
local function stroke(parent: Instance, x: number, y: number, angle: number)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromOffset(x, y)
	bar.Size = UDim2.fromOffset(STROKE.X, STROKE.Y)
	bar.Rotation = angle
	bar.BackgroundColor3 = UiStyle.Gold
	bar.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = UiStyle.Outline
	edge.Thickness = 1.5
	edge.Parent = bar
	bar.Parent = parent
end

local function makeArrow(gui: ScreenGui, weapon: string): Arrow
	local plate = Instance.new("Frame")
	plate.Name = "CrateArrow"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Size = UDim2.fromOffset(PLATE, PLATE)
	UiStyle.plate(plate, PLATE // 2)
	plate.Parent = gui
	-- A ">" pointing along +x: two strokes meeting at the tip, the box turned as a whole toward the crate.
	local chevron = Instance.new("Frame")
	chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Position = UDim2.fromScale(0.5, 0.5)
	chevron.Size = UDim2.fromOffset(PLATE, PLATE)
	chevron.BackgroundTransparency = 1
	chevron.Parent = plate
	local tipX, mid = PLATE * 0.68, PLATE / 2
	-- Each stroke's middle a little short of half its length back from the tip along 45 degrees, so the two overlap there.
	local back = (STROKE.X / 2 - STROKE.Y / 2) * math.cos(math.rad(45))
	stroke(chevron, tipX - back, mid - back, 45)
	stroke(chevron, tipX - back, mid + back, -45)
	local label = UiStyle.label(gui, "CrateName", UDim2.fromOffset(130, 22), 18, UiStyle.Gold)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Text = Words.Weapons[weapon] or weapon
	return { plate = plate, chevron = chevron, label = label }
end

local function remove(arrow: Arrow)
	arrow.plate:Destroy()
	arrow.label:Destroy()
end

-- folder: where the server puts the crates (Names.CratesFolder).
function CrateArrows.new(playerGui: Instance, folder: Instance): Arrows
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlCrateArrows"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- screen points from the camera are measured from the true top
	gui.Parent = playerGui
	local fields: Fields = { gui = gui, folder = folder, arrows = {} }
	return setmetatable(fields, CrateArrows)
end

-- Every frame. show: whether the player fights on the trains now.
function CrateArrows.update(self: Arrows, show: boolean)
	local camera = Workspace.CurrentCamera
	local size = camera.ViewportSize
	local cx, cy = size.X / 2, size.Y / 2
	local left, right, top, bottom = EDGE, size.X - EDGE, EDGE_TOP, size.Y - EDGE_BOTTOM
	local seen: { [Model]: boolean } = {}
	if show then
		for _, child in self.folder:GetChildren() do
			local box = if child:IsA("Model") then child.PrimaryPart else nil
			local weapon = child:GetAttribute(Names.CrateWeapon)
			if box and typeof(weapon) == "string" and child:GetAttribute(Names.CrateTakenBy) == nil then
				local point = camera:WorldToViewportPoint(box.Position)
				local inside = point.Z > 0 and point.X >= left and point.X <= right and point.Y >= top and point.Y <= bottom
				if not inside then
					local model = child :: Model
					seen[model] = true
					local arrow = self.arrows[model] or makeArrow(self.gui, weapon)
					self.arrows[model] = arrow
					-- From the middle toward it (behind the camera the projection is mirrored), out to the frame's edge.
					local dx, dy = point.X - cx, point.Y - cy
					if point.Z <= 0 then
						dx, dy = -dx, -dy
					end
					if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
						dy = 1
					end
					local reachX = (if dx > 0 then right - cx else cx - left) / math.max(math.abs(dx), 1e-3)
					local reachY = (if dy > 0 then bottom - cy else cy - top) / math.max(math.abs(dy), 1e-3)
					local scale = math.min(reachX, reachY)
					local x, y = cx + dx * scale, cy + dy * scale
					-- Out of the buttons' corner: up the right edge, or left along the bottom one.
					local cornerX, cornerY = size.X - KEEP_OUT.X - PLATE / 2, size.Y - KEEP_OUT.Y - PLATE / 2
					if x > cornerX and y > cornerY then
						if x >= right - 1 then
							y = cornerY
						else
							x = cornerX
						end
					end
					local length = math.sqrt(dx * dx + dy * dy)
					arrow.plate.Position = UDim2.fromOffset(x, y)
					arrow.chevron.Rotation = math.deg(math.atan2(dy, dx))
					arrow.label.Position = UDim2.fromOffset(x - dx / length * LABEL_IN, y - dy / length * LABEL_IN)
				end
			end
		end
	end
	for model, arrow in self.arrows do
		if not seen[model] then
			remove(arrow)
			self.arrows[model] = nil
		end
	end
end

return CrateArrows
