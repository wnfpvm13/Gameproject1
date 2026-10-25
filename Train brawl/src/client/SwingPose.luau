--!strict
-- Draws attacks on every client, for every character, by turning the right shoulder (no uploaded animation), each
-- weapon's way (its style in Config.Weapons, over its `seconds`, striking at its `hitAt`):
-- - punch: the arm shoots straight ahead and back;
-- - swing: the arm lifts out to the side cocked back, sweeps round across the front to the left (the weapon level at
--   shoulder height, pointing straight ahead as the hit lands) and comes down;
-- - slam: the arm rises high overhead for a long wind-up, then crashes down in front;
-- - throw: the arm goes back over the shoulder and whips forward.
-- The turns are for R15's RightShoulder, whose joint frame lines up with the torso (the place uses R15 avatars). An
-- attack starts at the character's Names.SwingAt (server time, set by WeaponService with Names.SwingWeapon), or at
-- once for the player's own (play()). The joint is written in RunService.Stepped, after the Animator has written it
-- for the frame (a value written in RenderStepped is overwritten before it is drawn - learned in Western train's
-- CowboyPose).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local SwingPose = {}

-- Attacks being drawn: the shoulder, the server time the attack started and its weapon.
local swinging: { [Model]: { joint: CharacterParts.Joint, at: number, weapon: string } } = {}

-- The side swing at `u` (0..1) with the hit at `k`: `lift` raises the arm out to the right (about the joint's forward
-- axis), then `turn` swings it round the torso's up axis (negative = toward the back, positive = across the front).
local function swing(u: number, k: number): CFrame
	local windUp, strikeEnd = k * 0.6, math.min(k * 1.4, 0.8)
	local lift, turn
	if u < windUp then
		local s = u / windUp
		lift, turn = s, -40 * s
	elseif u < strikeEnd then
		local s = (u - windUp) / (strikeEnd - windUp)
		lift, turn = 1, -40 + 170 * s
	else
		local s = (u - strikeEnd) / (1 - strikeEnd)
		lift, turn = 1 - s, 130 * (1 - s)
	end
	return CFrame.Angles(0, math.rad(turn), 0) * CFrame.Angles(0, 0, math.rad(90) * lift)
end

-- The arm raised forward by `degrees` (about the joint's side axis: 0 hangs down, 90 points ahead, 180 straight up).
local function forward(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

-- The shoulder's turn `u` (0..1) through an attack of `weapon`.
local function pose(weapon: string, u: number): CFrame
	local w = Config.Weapons[weapon]
	local k = math.clamp(w.hitAt / w.seconds, 0.1, 0.9) -- when it strikes, as a share of the drawn attack
	if w.style == "punch" then
		-- Out to straight ahead by the strike, back down after.
		local reach = if u < k then u / k else 1 - (u - k) / (1 - k)
		return forward(95 * reach)
	elseif w.style == "slam" then
		-- Up and back overhead by the strike (slowly), down to ahead at it, then back to hanging.
		if u < k * 0.85 then
			return forward(190 * (u / (k * 0.85)))
		elseif u < k then
			return forward(190 - 120 * ((u - k * 0.85) / (k * 0.15)))
		end
		return forward(70 * (1 - (u - k) / (1 - k)))
	elseif w.style == "throw" then
		-- Back over the shoulder, then whipped forward through ahead as it lets go.
		if u < k then
			return forward(170 * (u / k))
		end
		return forward(170 - 150 * ((u - k) / (1 - k)))
	end
	return swing(u, k)
end

RunService.Stepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for model, attack in swinging do
		local u = (now - attack.at) / Config.Weapons[attack.weapon].seconds
		if u >= 1 or not attack.joint:IsDescendantOf(Workspace) then
			swinging[model] = nil
			if attack.joint:IsDescendantOf(Workspace) then
				(attack.joint :: any).Transform = CFrame.identity -- put straight once
			end
		elseif u >= 0 then
			-- Both joint kinds have Transform; the type checker cannot write through the union.
			(attack.joint :: any).Transform = pose(attack.weapon, u)
		end
	end
end)

-- Starts drawing an attack of `model` with `weapon` that began at server time `at`.
function SwingPose.play(model: Model, at: number, weapon: string)
	local joint = CharacterParts.shoulder(model)
	if joint then
		swinging[model] = { joint = joint, at = at, weapon = WeaponRules.named(Config.Weapons, weapon) }
	end
end

-- Follows a character's Names.SwingAt (every attack the server takes). `skip(at)` returns true for an attack this
-- client already drew (the player's own, started at once); `heard(weapon)` sounds the others. Returns the connection.
function SwingPose.follow(model: Model, skip: (number) -> boolean, heard: (string) -> ()): RBXScriptConnection
	return model:GetAttributeChangedSignal(Names.SwingAt):Connect(function()
		local at = model:GetAttribute(Names.SwingAt)
		if typeof(at) == "number" and not skip(at) then
			local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.SwingWeapon))
			SwingPose.play(model, at, weapon)
			heard(weapon)
		end
	end)
end

return SwingPose
