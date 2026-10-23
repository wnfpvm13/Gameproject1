--!strict
-- Damped spring for the squash value (0 = normal, 1 = flat). Pure math with no Roblox API, so the luau CLI tests
-- run it unchanged. Requires nothing.

local SquashSpring = {}

export type State = { value: number, velocity: number }

local SUB_STEP = 1 / 240 -- small fixed steps keep the spring stable at any frame rate
local MAX_FRAME = 0.1 -- a longer hitch is cut short instead of fast-forwarded

function SquashSpring.new(): State
	return { value = 0, velocity = 0 }
end

-- Moves the state toward target over dt seconds. frequency is in rad/s; damping below 1 overshoots and wobbles.
function SquashSpring.step(
	state: State,
	target: number,
	dt: number,
	frequency: number,
	damping: number,
	minValue: number,
	maxValue: number
)
	local remaining = math.min(math.max(dt, 0), MAX_FRAME)
	while remaining > 0 do
		local h = math.min(remaining, SUB_STEP)
		local accel = frequency * frequency * (target - state.value) - 2 * damping * frequency * state.velocity
		state.velocity += accel * h
		state.value += state.velocity * h
		remaining -= h
	end
	if state.value < minValue then
		state.value = minValue
		state.velocity = 0
	elseif state.value > maxValue then
		state.value = maxValue
		state.velocity = 0
	end
end

-- True once the spring has stopped at target; it is then snapped exactly onto target.
function SquashSpring.settle(state: State, target: number, epsilon: number): boolean
	if math.abs(state.value - target) < epsilon and math.abs(state.velocity) < epsilon then
		state.value = target
		state.velocity = 0
		return true
	end
	return false
end

return SquashSpring
