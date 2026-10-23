--!strict
-- The banned-word talk (docs/DESIGN_V3.md §5-6; bundle 6a, owner 2026-10-23: banned words are one minigame, played
-- only while speech judging is on). Prep: everyone alive gets a banned word only they do not know (RoundService draws
-- them, never inside the topic) and sees the topic; with a presenter they may re-draw words for TALK_REROLL_SECONDS or
-- start at once, else TALK_PREP_SECONDS. Talk: TALK_SECONDS of everyone talking about the topic, trying to make the
-- others say their word; the system judges (chat, speech) and the presenter flings what it missed. The settle stage
-- (late results, rescues, then the words go) is RoundService's: it runs after every talk, also a cancelled or broken
-- one, so no word or chat rule is left behind.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local TalkTopics = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("TalkTopics"))

-- MissionRunner.MissionCtx (missions cannot require services, so the shape is repeated here).
type Ctx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	wait: (seconds: number) -> boolean,
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	screen: (payload: { [string]: any }?) -> (),
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { { id: string, title: string, recommended: boolean } }, seconds: number) -> string?,
	lever: () -> (),
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
}

local BannedTalk = {
	id = "bannedTalk",
	title = Config.TEXT.TALK_TITLE,
	-- The longest run: the presenter's re-draw window, the talk, then the settle stage (a late speech result and a
	-- rescue still waiting).
	expectedSeconds = Config.TALK_REROLL_SECONDS + Config.TALK_SECONDS + Config.SETTLE_MAX + Config.RESCUE_SECONDS,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = 2 :: number?,
	needsPresenter = nil :: boolean?,
}

function BannedTalk.available(final: boolean): boolean
	return not final and Match.voiceJudging and #TalkTopics > 0
end

function BannedTalk.run(ctx: Ctx): boolean?
	local topic = TalkTopics[ctx.rng:NextInteger(1, #TalkTopics)]
	ctx.talk("prep", topic)
	local presenting = Match.presenter ~= nil
	local prepSeconds = if presenting then Config.TALK_REROLL_SECONDS else Config.TALK_PREP_SECONDS
	ctx.screen({ kind = "talk", stage = "prep", topic = topic, endsAt = Match.now() + prepSeconds })
	ctx.show(Config.TEXT.TALK_PREP)
	local ready = if presenting then ctx.presenterReroll(prepSeconds) else ctx.wait(prepSeconds)
	if not ready then
		return true
	end
	ctx.talk("talk")
	ctx.screen({ kind = "talk", stage = "talk", topic = topic, endsAt = Match.now() + Config.TALK_SECONDS })
	ctx.show(Config.TEXT.TALK_ON)
	ctx.wait(Config.TALK_SECONDS)
	return true
end

return BannedTalk
