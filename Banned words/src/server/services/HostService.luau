--!strict
-- Assistant host: picks the round's theme and loose roles, and only steps in when the table goes quiet
-- (topic card, then a small event). It never forces anyone to speak and never touches judging.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local Themes = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("Themes"))

local HostService = {}

local theme: Themes.Theme? = nil
local lastThemeName: string? = nil
local themePayload: any = nil
local onScreen: { [string]: any } = {} -- kind ("topic" | "event") -> what is shown (late joiners, re-checks)
local lastLaunchAt = -math.huge
local used: { [string]: boolean } = {} -- cards already shown this round (repeats only when all are used)

-- A card is shown only if reading it aloud cannot make anyone say a word in play.
local function isSafe(text: string): boolean
	for _, word in Match.wordsInPlay() do
		if Judge.isConfirmed(word, text) then
			return false
		end
	end
	return true
end

local function pickSafe(list: { string }, rng: Random): string?
	local start = rng:NextInteger(1, #list)
	for pass = 1, 2 do
		for offset = 0, #list - 1 do
			local text = list[(start + offset - 1) % #list + 1]
			if (pass == 2 or not used[text]) and isSafe(text) then
				used[text] = true
				return text
			end
		end
	end
	return nil
end

-- After words are assigned: theme (not the same twice in a row) and one unique role per participant.
function HostService.setup(rng: Random)
	local options = {}
	for _, t in Themes.list do
		if t.name ~= lastThemeName and isSafe(t.situation) then
			table.insert(options, t)
		end
	end
	local chosen = if #options > 0 then options[rng:NextInteger(1, #options)] else Themes.list[1]
	theme = chosen
	lastThemeName = chosen.name
	table.clear(used)
	Match.theme = chosen.name

	local roles = {}
	for _, role in chosen.roles do
		if isSafe(role) then
			table.insert(roles, role)
		end
	end
	for i = #roles, 2, -1 do
		local j = rng:NextInteger(1, i)
		roles[i], roles[j] = roles[j], roles[i]
	end
	local byUser = {}
	local i = 0
	for player, p in Match.participants do
		i += 1
		p.role = roles[i]
		if p.role then
			byUser[tostring(player.UserId)] = p.role
		end
	end
	themePayload = { kind = "theme", theme = chosen.name, situation = chosen.situation, roles = byUser }
	table.clear(onScreen)
	Net.toAll("Host", themePayload)
end

local function show(kind: string, text: string, spotlight: Player?)
	local payload = { kind = kind, text = text, spotlightId = if spotlight then spotlight.UserId else nil }
	onScreen[kind] = payload
	Net.toAll("Host", payload)
end

local function event(rng: Random): boolean
	local t = theme
	if not t then
		return false
	end
	local text = pickSafe(t.events, rng)
	if not text then
		return false
	end
	local spotlight: Player? = nil
	if string.find(text, "{name}", 1, true) then
		local alive = Match.aliveList()
		if #alive == 0 then
			return false
		end
		spotlight = alive[rng:NextInteger(1, #alive)]
		text = string.gsub(text, "{name}", (spotlight :: Player).DisplayName)
		if not isSafe(text) then
			return false -- the display name itself contains a word in play
		end
	end
	show("event", text, spotlight)
	return true
end

local function topic(rng: Random)
	local t = theme
	local pool = table.clone(Themes.general)
	if t then
		for _, text in t.topics do
			table.insert(pool, text)
		end
	end
	local text = pickSafe(pool, rng)
	if text then
		show("topic", text)
	end
end

-- Runs alongside the talk: one opening topic, then a topic after QUIET_TOPIC seconds of silence and an event
-- after QUIET_EVENT (not right after a launch, and at most one event per EVENT_COOLDOWN).
function HostService.run(stillTalking: () -> boolean, rng: Random)
	topic(rng)
	local lastTopicAt = os.clock()
	local lastEventAt = -math.huge
	while stillTalking() do
		local now = os.clock()
		local quiet = now - math.max(Match.lastActivityAt, lastTopicAt, lastEventAt)
		local quietTalk = now - Match.lastActivityAt
		if quietTalk >= Config.QUIET_EVENT and now - lastEventAt >= Config.EVENT_COOLDOWN and now - lastLaunchAt >= Config.AFTER_LAUNCH_QUIET then
			if event(rng) then
				lastEventAt = now
			end
		elseif quiet >= Config.QUIET_TOPIC then
			topic(rng)
			lastTopicAt = now
		end
		task.wait(1)
	end
end

-- After new words: hide any card on screen that now contains a word in play.
function HostService.revalidate()
	for kind, payload in onScreen do
		if not isSafe(payload.text) then
			onScreen[kind] = nil
			Net.toAll("Host", { kind = "hide", which = kind })
		end
	end
end

function HostService.noteLaunch()
	lastLaunchAt = os.clock()
end

-- Late joiners: the theme and whatever card is up.
function HostService.send(player: Player)
	if themePayload then
		Net.to(player, "Host", themePayload)
	end
	for _, payload in onScreen do
		Net.to(player, "Host", payload)
	end
end

function HostService.clear()
	theme = nil
	themePayload = nil
	table.clear(onScreen)
	Net.toAll("Host", { kind = "clear" })
end

return HostService
