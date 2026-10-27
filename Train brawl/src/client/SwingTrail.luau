--!strict
-- The streak behind a blow, on this client, for every character: behind the striking fist (bare fists: the left for a
-- jab, the right for the rest: AttackPoses.hand) or along the part of the weapon that strikes (between the held
-- weapon's Names.TrailTip and Names.TrailBase, made by WeaponGear; a dynamite stick has none). It is drawn only through
-- the blow itself - from part way into the wind-up until just after the blow lands (AttackString.hitAt) - so walking
-- and the guard leave none. A string's launching last step leaves a gold streak, the others a white one. It shows a
-- swing at the air as much as a hit, and the player's own blows from behind (the shoulder camera sees the back). A
-- trail is made for each blow and removed after it.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local AttackString = require(shared:WaitForChild("AttackString"))
local AttackPoses = require(shared:WaitForChild("AttackPoses"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local SwingTrail = {}

local STRING = AttackString.rules(Config.Attack)
local FROM = 0.45 -- the streak starts this share of the way to the blow
local AFTER = 0.06 -- and stops this long after it lands
local FIST_HALF = 0.3 -- a fist's streak reaches this far each side of the hand (across the knuckles)
local WHITE = Color3.fromRGB(255, 250, 238)

-- The two points the streak of a blow of `w` at `step` by `model` runs between, and whether they were made here (a
-- fist's, removed with the streak); nil when there are none.
local function ends(model: Model, w: WeaponRules.Weapon, step: number, finisher: boolean): (Attachment?, Attachment?, boolean)
	if w.style == "punch" then
		local hand = model:FindFirstChild(AttackPoses.hand(w.style, step, finisher))
		if not (hand and hand:IsA("BasePart")) then
			return nil, nil, false
		end
		local a = Instance.new("Attachment")
		a.Name = "TrainBrawlStreak"
		a.Position = Vector3.new(FIST_HALF, 0, 0)
		a.Parent = hand
		local b = a:Clone()
		b.Position = Vector3.new(-FIST_HALF, 0, 0)
		b.Parent = hand
		return a, b, true
	end
	local held = model:FindFirstChild(Names.WeaponPart)
	local tip = if held then held:FindFirstChild(Names.TrailTip) else nil
	local base = if held then held:FindFirstChild(Names.TrailBase) else nil
	if tip and base and tip:IsA("Attachment") and base:IsA("Attachment") then
		return tip, base, false
	end
	return nil, nil, false
end

-- A blow by `model` with `weapon` at `step` of its string, begun at server time `at` (the player's own: now; another's
-- as heard, maybe a little late: what is left of it).
function SwingTrail.play(model: Model, weapon: string, step: number, at: number)
	local w = Config.Weapons[WeaponRules.named(Config.Weapons, weapon)]
	local finisher = AttackString.launches(STRING, step, w.style)
	local lands = AttackString.hitAt(STRING, w.hitAt, step, w.style)
	local now = Workspace:GetServerTimeNow()
	local startIn = at + lands * FROM - now
	local stopIn = at + lands + AFTER - now
	if stopIn <= 0 then
		return -- heard after the blow was over
	end
	local a, b, made = ends(model, w, step, finisher)
	if not (a and b) then
		return
	end
	local fist = w.style == "punch"
	local lifetime = Config.Feedback.StreakSeconds[if fist then "punch" else "weapon"]
	local trail = Instance.new("Trail")
	trail.Name = "TrainBrawlStreak"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Lifetime = lifetime
	trail.MinLength = 0
	trail.FaceCamera = fist -- a fist's two points sit close: turned to the camera it reads from any side
	trail.Color = ColorSequence.new(if finisher then Config.Feedback.Gold else WHITE)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	trail.LightEmission = 0.7
	trail.LightInfluence = 0
	trail.Enabled = false
	trail.Parent = a.Parent
	task.delay(math.max(startIn, 0), function()
		if trail.Parent then
			trail:Clear()
			trail.Enabled = true
		end
	end)
	task.delay(stopIn, function()
		trail.Enabled = false
	end)
	local gone = stopIn + lifetime + 0.1
	Debris:AddItem(trail, gone)
	if made then
		Debris:AddItem(a, gone)
		Debris:AddItem(b, gone)
	end
end

return SwingTrail
