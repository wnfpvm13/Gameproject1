--!strict
-- Shows what everyone holds (Config.Weapons, each character's Names.Weapon): above the player's own health bar the
-- weapon's name with its attacks left (Names.WeaponUses) or seconds left (Names.WeaponEndsAt), and over every other
-- fighter's head the name of the weapon it holds (nothing for bare fists), so a weapon coming at you can be seen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local WeaponHud = {}
WeaponHud.__index = WeaponHud

local GOLD = Color3.fromRGB(255, 226, 120)

type Fields = { own: TextLabel, tags: { [Model]: BillboardGui }, layer: Instance }
export type Hud = typeof(setmetatable({} :: Fields, WeaponHud))

local function label(parent: Instance, size: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Size = size
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0.35
	text.Parent = parent
	return text
end

-- What `model` holds, as shown: the name, then its attacks or seconds left (none for bare fists).
local function describe(model: Model, now: number): string
	local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon))
	local name = Config.Weapons[weapon].label
	local uses = model:GetAttribute(Names.WeaponUses)
	local ends = model:GetAttribute(Names.WeaponEndsAt)
	if typeof(uses) == "number" then
		return string.format("%s ×%d", name, uses)
	elseif typeof(ends) == "number" then
		return string.format("%s %d초", name, math.max(0, math.ceil(ends - now)))
	end
	return name
end

function WeaponHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlWeapon"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local own = label(gui, UDim2.fromOffset(260, 26))
	own.AnchorPoint = Vector2.new(0.5, 1)
	own.Position = UDim2.new(0.5, 0, 1, -46) -- just above the health bar (HealthBars)
	local fields: Fields = { own = own, tags = {}, layer = playerGui }
	return setmetatable(fields, WeaponHud)
end

-- Every frame: `fighters` the characters still in the round, `ownModel` the player's, `now` the server time.
function WeaponHud.update(self: Hud, fighters: { Model }, ownModel: Model?, now: number)
	local inRound = ownModel ~= nil and ownModel:GetAttribute(Names.Alive) == true
	self.own.Visible = inRound
	if ownModel and inRound then
		self.own.Text = describe(ownModel, now)
	end
	local seen: { [Model]: boolean } = {}
	for _, model in fighters do
		if model ~= ownModel then
			seen[model] = true
			local armed = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon)) ~= WeaponRules.FIST
			local tag: BillboardGui? = self.tags[model]
			local head = model:FindFirstChild("Head")
			if tag and (tag.Parent == nil or tag.Adornee ~= head) then
				tag:Destroy() -- gone with the player's respawn, or the fighter's head was replaced: made again below
				self.tags[model] = nil
				tag = nil
			end
			if armed and not tag and head and head:IsA("BasePart") then
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "TrainBrawlWeaponTag"
				billboard.Size = UDim2.fromOffset(110, 20)
				billboard.StudsOffset = Vector3.new(0, 3.4, 0) -- over the health bar
				billboard.AlwaysOnTop = true
				billboard.MaxDistance = 90
				billboard.ResetOnSpawn = false -- straight in PlayerGui: kept when the player respawns
				label(billboard, UDim2.fromScale(1, 1))
				billboard.Adornee = head
				billboard.Parent = self.layer -- in PlayerGui: a BillboardGui inside a ScreenGui is not drawn
				self.tags[model] = billboard
				tag = billboard
			end
			if tag then
				tag.Enabled = armed
				local text = tag:FindFirstChildOfClass("TextLabel")
				if text and armed then
					text.Text = Config.Weapons[WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon))].label
				end
			end
		end
	end
	for model, tag in self.tags do
		if not seen[model] then
			tag:Destroy()
			self.tags[model] = nil
		end
	end
end

return WeaponHud
