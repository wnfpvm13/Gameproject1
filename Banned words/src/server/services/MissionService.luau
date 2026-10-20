--!strict
-- Assistant host (V2.1): the round's theme and loose roles, then the theme's mission cards one after another
-- (situation, problem, goal, options -> notice -> short vote -> follow-up), plus topic cards / small events only
-- when the table goes quiet. Nobody dies for a mission, and nothing here ever looks at the secret words:
-- theme, roles, missions and their timing depend only on missionRng, public votes and time, so they can never
-- hint at anyone's word. Card texts are kept word-free ahead of time by tools/check_content.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local Themes = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("Themes"))

local MissionService = {}

export type VoteSpec = { id: string, options: { Themes.Option }, seconds: number }

local theme: Themes.Theme? = nil
local lastThemeName: string? = nil
local themePayload: any = nil
local missionPayload: any = nil -- the mission card on screen
local cardPayloads: { [string]: any } = {} -- "topic" | "event" -> what is shown (late joiners)
local used: { [string]: boolean } = {} -- quiet-time cards already shown this round
local lastLaunchAt = -math.huge

local function shuffled<T>(list: { T }, rng: Random): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- After words are assigned: theme (not the same twice in a row) and one unique role per participant.
function MissionService.setup(rng: Random)
	local options = {}
	for _, t in Themes.list do
		if t.name ~= lastThemeName then
			table.insert(options, t)
		end
	end
	local chosen = if #options > 0 then options[rng:NextInteger(1, #options)] else Themes.list[1]
	theme = chosen
	lastThemeName = chosen.name
	Match.theme = chosen.name
	table.clear(used)
	table.clear(cardPayloads)
	missionPayload = nil

	local roles = shuffled(chosen.roles, rng)
	local players = {}
	for player in Match.participants do
		table.insert(players, player)
	end
	table.sort(players, function(a, b)
		return a.UserId < b.UserId -- stable order, so the role only depends on missionRng
	end)
	local byUser = {}
	for i, player in players do
		local role = roles[i]
		Match.participants[player].role = role
		if role then
			byUser[tostring(player.UserId)] = role
		end
	end
	themePayload = { kind = "theme", theme = chosen.name, roles = byUser }
	Net.toAll("Host", themePayload)
end

local function pickUnused(list: { string }, rng: Random): string
	local fresh = {}
	for _, text in list do
		if not used[text] then
			table.insert(fresh, text)
		end
	end
	local pool = if #fresh > 0 then fresh else list
	local text = pool[rng:NextInteger(1, #pool)]
	used[text] = true
	return text
end

local function showCard(kind: string, text: string, spotlight: Player?)
	local payload = {
		kind = kind,
		text = text,
		spotlightId = if spotlight then spotlight.UserId else nil,
		expiresAt = if kind == "event" then Match.now() + Config.EVENT_SHOW_SECONDS else nil,
	}
	cardPayloads[kind] = { payload = payload, at = os.clock() }
	Net.toAll("Host", payload)
end

local function quietEvent(rng: Random)
	local t = theme
	if not t then
		return
	end
	local text = pickUnused(t.events, rng)
	local spotlight: Player? = nil
	if string.find(text, "{name}", 1, true) then
		-- A role, never a display name: role texts are checked against the word bank, names are not.
		local alive = Match.aliveList()
		table.sort(alive, function(a, b)
			return a.UserId < b.UserId
		end)
		if #alive == 0 then
			return
		end
		spotlight = alive[rng:NextInteger(1, #alive)]
		local role = Match.participants[spotlight :: Player].role or "누군가"
		text = string.gsub(text, "{name}{이가}", role .. Judge.josa(role, "이", "가"))
		text = string.gsub(text, "{name}", role)
	end
	showCard("event", text, spotlight)
end

local function quietTopic(rng: Random)
	local pool = table.clone(Themes.general)
	if theme then
		for _, text in (theme :: Themes.Theme).topics do
			table.insert(pool, text)
		end
	end
	showCard("topic", pickUnused(pool, rng))
end

local function showMission(index: number, total: number, mission: Themes.Mission, condition: string?, stage: string)
	local options = {}
	for _, option in mission.options do
		table.insert(options, option.text)
	end
	missionPayload = {
		kind = "mission",
		index = index,
		total = total,
		situation = mission.situation,
		problem = mission.problem,
		goal = mission.goal,
		options = options,
		condition = condition,
		stage = stage, -- "open" | "notice" | "vote" | "after"
	}
	Net.toAll("Host", missionPayload)
end

-- Waits until os.clock() reaches `t`; false if the talk ended first.
local function waitUntil(t: number, stillTalking: () -> boolean): boolean
	while os.clock() < t do
		if not stillTalking() then
			return false
		end
		task.wait(0.2)
	end
	return stillTalking()
end

-- Quiet-time help (runs next to the missions): a topic card after QUIET_TOPIC seconds without speech, a small
-- event after QUIET_EVENT (never right after a launch, at most one per EVENT_COOLDOWN).
local function runQuietHelp(stillTalking: () -> boolean, rng: Random)
	local lastTopicAt = os.clock()
	local lastEventAt = -math.huge
	while stillTalking() do
		local now = os.clock()
		local quietTalk = now - Match.lastActivityAt
		local quiet = now - math.max(Match.lastActivityAt, lastTopicAt, lastEventAt)
		if quietTalk >= Config.QUIET_EVENT and now - lastEventAt >= Config.EVENT_COOLDOWN and now - lastLaunchAt >= Config.AFTER_LAUNCH_QUIET then
			quietEvent(rng)
			lastEventAt = now
		elseif quiet >= Config.QUIET_TOPIC then
			quietTopic(rng)
			lastTopicAt = now
		end
		task.wait(1)
	end
end

-- Runs alongside the talk. `runVote(spec)` (wired by RoundService to VoteService) blocks until the vote closes
-- and returns the winning option id or "undecided".
function MissionService.run(stillTalking: () -> boolean, rng: Random, runVote: (VoteSpec) -> string)
	local t = theme
	if not t then
		return
	end
	task.spawn(runQuietHelp, stillTalking, rng)
	local missions = t.missions -- in order: each theme's missions tell a small story
	for index, mission in missions do
		local started = os.clock()
		showMission(index, #missions, mission, nil, "open")
		if not waitUntil(started + Config.MISSION_NOTICE_AT, stillTalking) then
			return
		end
		showMission(index, #missions, mission, mission.notice, "notice")
		if not waitUntil(started + Config.VOTE_OPEN_AFTER, stillTalking) then
			return
		end
		showMission(index, #missions, mission, mission.notice, "vote")
		local outcome = runVote({ id = mission.id, options = mission.options, seconds = Config.VOTE_SECONDS })
		if not stillTalking() then
			return
		end
		showMission(index, #missions, mission, mission.followups[outcome] or mission.followups.undecided, "after")
		if not waitUntil(started + Config.MISSION_LENGTH, stillTalking) then
			return
		end
	end
end

function MissionService.noteLaunch()
	lastLaunchAt = os.clock()
end

-- Late joiners: the theme, the mission card and whatever quiet-time card is up.
function MissionService.send(player: Player)
	if themePayload then
		Net.to(player, "Host", themePayload)
	end
	if missionPayload then
		Net.to(player, "Host", missionPayload)
	end
	for kind, card in cardPayloads do
		-- Topics stay up; an event banner only while it is still on everyone's screen.
		if kind ~= "event" or os.clock() - card.at < Config.EVENT_SHOW_SECONDS then
			Net.to(player, "Host", card.payload)
		end
	end
end

function MissionService.clear()
	theme = nil
	themePayload = nil
	missionPayload = nil
	table.clear(cardPayloads)
	Net.toAll("Host", { kind = "clear" })
end

return MissionService
