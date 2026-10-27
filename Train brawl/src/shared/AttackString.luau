--!strict
-- The attacker's 1-2-3 string, as pure rules (owner decision 11, DIRECTION 4: the launch is the attacker's third
-- attack in a row, not the victim's third hit). Only punches and swings make a string (a hammer's slam or a thrown
-- stick launches by its own rule and starts the string over). Each attack is the next step when it starts within
-- `gap` seconds after the last attack's weapon was ready again, whether the last one hit or swung at the air (owner
-- 2026-10-28: "even swinging at the air should go on to the 2nd and 3rd"; before, only a landed attack went on);
-- after the last step (`count`) or a longer pause the string starts again at 1. The last step's hit launches, and it
-- lands a little later than the weapon's own hitAt (`windup`), so everyone sees the bigger move coming. Being hit
-- breaks the string. The player's client draws each step at once and tells the server which step it drew; the server
-- takes that claim only when it is a 1 (a new string may always start) or the next step of a string it counted
-- itself, within `slack` of the gap (network jitter) - a changed client cannot skip to the launching step. Requires
-- nothing.

local AttackString = {}

export type Rules = { count: number, gap: number, slack: number, windup: number }
-- step: the last attack's step (0 = none); ready: when that attack's weapon was ready again.
export type State = { step: number, ready: number }

-- The rules from Config.Attack.
function AttackString.rules(attack: { StringCount: number, StringGap: number, StringSlack: number, FinisherWindup: number }): Rules
	return { count = attack.StringCount, gap = attack.StringGap, slack = attack.StringSlack, windup = attack.FinisherWindup }
end

function AttackString.new(): State
	return { step = 0, ready = -math.huge }
end

-- Whether attacks of this style make a string (punches and swings).
function AttackString.uses(style: string): boolean
	return style == "punch" or style == "swing"
end

-- The step an attack starting at `now` would be (the state is not changed).
function AttackString.next(state: State, rules: Rules, now: number): number
	if state.step <= 0 or state.step >= rules.count or now - state.ready > rules.gap then
		return 1
	end
	return state.step + 1
end

-- An attack of `style` starts at `now`, its weapon ready again `cooldown` later; `claim` is the step the attacker's
-- client drew (nil when it sent none). Returns the step taken and records it (a slam or a throw: 1, and the string
-- starts over after it).
function AttackString.take(state: State, rules: Rules, now: number, cooldown: number, style: string, claim: number?): number
	if not AttackString.uses(style) then
		state.step = 0
		return 1
	end
	local step = AttackString.next(state, rules, now)
	if claim == 1 then
		step = 1
	elseif claim and claim ~= step and state.step > 0 and claim == state.step + 1 and claim <= rules.count
		and now - state.ready <= rules.gap + rules.slack then
		step = claim -- the client's clock kept the string a moment longer than this server's
	end
	state.step = step
	state.ready = now + cooldown
	return step
end

-- The attacker was hit: the string is broken (the next attack is a 1).
function AttackString.reset(state: State)
	state.step = 0
end

-- Whether an attack of `style` at `step` is the string's launching last step.
function AttackString.launches(rules: Rules, step: number, style: string): boolean
	return step >= rules.count and AttackString.uses(style)
end

-- When an attack of `style` at `step` lands, seconds after it starts: the weapon's `hitAt`, a little later for the
-- launching last step.
function AttackString.hitAt(rules: Rules, hitAt: number, step: number, style: string): number
	return hitAt + (if AttackString.launches(rules, step, style) then rules.windup else 0)
end

return AttackString
