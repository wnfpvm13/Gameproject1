--!strict
-- Everyone's answers over their heads (bundle 12, owner 2026-10-27: "시간이 끝나고 각자의 머리 위에 어떤 선택했는지
-- 나오고 날리면 되겠다"). When a quiz question's time is up, its screen carries `picks` (userId string -> what that
-- player answered, and once the right answer shows, whether it was right); the client draws them on the head tags. Data
-- only: the missions build it, the client reads it.
local Picks = {}

export type Pick = { text: string, verdict: string? } -- verdict: nil (not shown yet) | "right" | "wrong"
export type Map = { [string]: Pick }

Picks.NONE = "?" -- no answer

-- The picks of `players`: `labelOf(player)` is the shown answer (nil: none), `verdictOf(player)` (optional) "right" or
-- "wrong" once the answer is out.
function Picks.build(players: { Player }, labelOf: (Player) -> string?, verdictOf: ((Player) -> string?)?): Map
	local out: Map = {}
	for _, player in players do
		out[tostring(player.UserId)] = { text = labelOf(player) or Picks.NONE, verdict = if verdictOf then verdictOf(player) else nil }
	end
	return out
end

-- A choice's label as numbered on the answer buttons ("1" .. "4"); O / X keep their own.
function Picks.choiceLabel(index: number?, choices: { string }): string?
	if index == nil then
		return nil
	end
	if #choices == 2 then
		return choices[index]
	end
	return tostring(index)
end

return Picks
