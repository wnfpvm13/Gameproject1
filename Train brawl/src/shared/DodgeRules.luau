--!strict
-- The dodge roll as pure rules (decision 22, numbers from Config.Dodge): which way a roll goes, whether one may start
-- (its cooldown), whether one is still going and how long until the next. Requires nothing.

local DodgeRules = {}

-- The flat way a roll goes, as a unit (x, z): along (moveX, moveZ) - the way the fighter walks - when it walks, else
-- straight back from where it faces (lookX, lookZ), away from whoever it was facing. Straight back along -Z when even
-- that is unknown.
function DodgeRules.direction(moveX: number, moveZ: number, lookX: number, lookZ: number): (number, number)
	local length = math.sqrt(moveX * moveX + moveZ * moveZ)
	if length > 0.1 then
		return moveX / length, moveZ / length
	end
	length = math.sqrt(lookX * lookX + lookZ * lookZ)
	if length > 1e-3 then
		return -lookX / length, -lookZ / length
	end
	return 0, 1
end

-- Whether a roll may start at `now` when the last one started at `last` (nil: none yet): `cooldown` after it, taken up
-- to `slack` early (the network).
function DodgeRules.ready(last: number?, now: number, cooldown: number, slack: number): boolean
	return last == nil or now >= last + cooldown - slack
end

-- Whether a roll that started at `at` (nil: none) is still going at `now`.
function DodgeRules.rolling(at: number?, now: number, seconds: number): boolean
	return at ~= nil and now >= at and now < at + seconds
end

-- Seconds until the next roll may start after one at `last` (0 when it may now).
function DodgeRules.wait(last: number?, now: number, cooldown: number): number
	if last == nil then
		return 0
	end
	return math.max(0, last + cooldown - now)
end

return DodgeRules
