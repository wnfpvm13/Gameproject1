--!strict
-- Assistant host (V2.1): the round's theme, then the theme's mission cards one after another on a fixed timetable
-- (card -> notice -> short vote -> follow-up), plus topic cards / small events only when the table goes quiet.
-- Nobody dies for a mission, there are no personal roles, and nothing here ever looks at the secret words:
-- theme, missions and their timing depend only on a fresh RNG, public votes, public events and time, so they can
-- never hint at anyone's word. Card texts are kept word-free ahead of time by tools/check_content.luau.
--
-- One big thing at a time (report V2.1 §7.2): a new stage, a vote or a quiet-time event waits while
-- Match.hostHeldUntil is in the future (a word warning/addition or a launch is on screen).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
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

-- After words are assigned: the theme (not the same twice in a row).
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
	themePayload = { kind = "theme", theme = chosen.name }
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

local function showCard(kind: string, text: string)
	local payload = {
		kind = kind,
		text = text,
		expiresAt = if kind == "event" then Match.now() + Config.EVENT_SHOW_SECONDS else nil,
	}
	cardPayloads[kind] = { payload = payload, at = os.clock() }
	Net.toAll("Host", payload)
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

-- stage: "open" | "notice" | "vote" | "after". decision: the chosen option's text after the vote.
local function showMission(index: number, total: number, mission: Themes.Mission, stage: string, condition: string?, decision: string?)
	local options = {}
	for _, option in mission.options do
		table.insert(options, option.text)
	end
	missionPayload = {
		kind = "mission",
		index = index,
		total = total,
		title = mission.title,
		situation = mission.situation,
		problem = mission.problem,
		goal = mission.goal,
		options = options,
		condition = condition,
		decision = decision,
		stage = stage,
	}
	Net.toAll("Host", missionPayload)
end

-- True if something shown now for `seconds` would not clash with anything big: nothing is on screen and no
-- (public, scheduled) word warning starts inside that time.
local function clearFor(seconds: number): boolean
	local now = os.clock()
	if now < Match.hostHeldUntil then
		return false
	end
	local untilWarn = Match.nextWordWarnAt - now
	return not (untilWarn >= -1 and untilWarn <= seconds + 1)
end

-- Waits until os.clock() reaches `t` and the next step (shown for `showFor` seconds) is clear; false if the talk
-- ended first.
local function waitUntil(t: number, showFor: number, stillTalking: () -> boolean): boolean
	while os.clock() < t or not clearFor(showFor) do
		if not stillTalking() then
			return false
		end
		task.wait(0.2)
	end
	return stillTalking()
end

-- Quiet-time help (runs next to the missions): a topic line after QUIET_TOPIC seconds without speech, a small
-- event after QUIET_EVENT (at most one per EVENT_COOLDOWN, never while something big is on screen).
local function runQuietHelp(stillTalking: () -> boolean, rng: Random)
	local lastTopicAt = os.clock()
	local lastEventAt = -math.huge
	while stillTalking() do
		local now = os.clock()
		local quietTalk = now - Match.lastActivityAt
		local quiet = now - math.max(Match.lastActivityAt, lastTopicAt, lastEventAt)
		if clearFor(Config.EVENT_SHOW_SECONDS) and quietTalk >= Config.QUIET_EVENT and now - lastEventAt >= Config.EVENT_COOLDOWN and theme then
			showCard("event", pickUnused((theme :: Themes.Theme).events, rng))
			Match.holdHost(Config.EVENT_SHOW_SECONDS) -- the banner has the stage while it shows
			lastEventAt = now
		elseif quiet >= Config.QUIET_TOPIC then
			quietTopic(rng)
			lastTopicAt = now
		end
		task.wait(1)
	end
end

-- Runs alongside the talk. `runVote(spec)` (wired by RoundService to VoteService) blocks until the vote closes
-- and returns the winning option id (or "undecided") plus a function that shows the result to everyone.
function MissionService.run(stillTalking: () -> boolean, rng: Random, runVote: (VoteSpec) -> (string, () -> ()))
	local t = theme
	if not t then
		return
	end
	task.spawn(runQuietHelp, stillTalking, rng)
	local missions = t.missions -- in order: each theme's missions tell a small story
	for index, mission in missions do
		if not waitUntil(os.clock(), Config.CARD_OPEN_SECONDS, stillTalking) then
			return
		end
		local started = os.clock()
		showMission(index, #missions, mission, "open")
		Match.holdHost(Config.CARD_OPEN_SECONDS) -- the new card has the stage while it is open
		if not waitUntil(started + Config.MISSION_NOTICE_AT, Config.STAGE_HOLD, stillTalking) then
			return
		end
		showMission(index, #missions, mission, "notice", mission.notice)
		Match.holdHost(Config.STAGE_HOLD)
		-- Talk time after the notice is kept even when the notice itself was held back.
		local noticeShownAt = os.clock()
		local voteAt = math.max(started + Config.VOTE_OPEN_AFTER, noticeShownAt + Config.VOTE_OPEN_AFTER - Config.MISSION_NOTICE_AT)
		-- The vote and its result must both fit before any scheduled word warning.
		if not waitUntil(voteAt, Config.VOTE_SECONDS + Config.STAGE_HOLD, stillTalking) then
			return
		end
		showMission(index, #missions, mission, "vote", mission.notice)
		Match.holdHost(Config.VOTE_SECONDS + 1) -- no quiet-time event pops up during the vote
		local outcome, announce = runVote({ id = mission.id, options = mission.options, seconds = Config.VOTE_SECONDS })
		-- Counted at the close; shown once nothing big is on screen (e.g. a launch during the vote).
		if not waitUntil(os.clock(), Config.STAGE_HOLD, stillTalking) then
			return
		end
		announce()
		local decision = "결정 못 함"
		for _, option in mission.options do
			if option.id == outcome then
				decision = option.text
			end
		end
		showMission(index, #missions, mission, "after", mission.followups[outcome] or mission.followups.undecided, decision)
		Match.holdHost(Config.STAGE_HOLD)
		if not waitUntil(started + Config.MISSION_LENGTH, 0, stillTalking) then
			return
		end
	end
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
