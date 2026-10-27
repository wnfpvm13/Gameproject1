--!strict
-- A player's sound settings (bundle 11a, docs/BUNDLE11_2026-10-27.md): background music and game sounds, 0..1 each.
-- Loaded from a DataStore when they join (one retry), kept here and sent to them when the load is over (whatever its
-- result) and again on every Sync; changed by the player (checked, at most Config.SETTINGS_RATE a second) and saved
-- Config.SETTINGS_SAVE_DELAY after the last change, when they leave and when the server closes.
-- Saves of one player run one at a time and carry a change number: only a save that worked marks its number saved,
-- a failed one is retried (Config.SETTINGS_SAVE_RETRIES). A player whose load failed is never saved this visit (a
-- default must not overwrite what they had), and neither is anyone while the store cannot be reached (Studio without
-- API access): their settings last for this visit only.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local SettingsService = {}

export type Settings = { music: number, effects: number }
-- What a DataStore needs to give here (the real one, or a fake in the tests).
export type Store = {
	GetAsync: (self: any, key: string) -> any,
	SetAsync: (self: any, key: string, value: any) -> any,
}

type Entry = {
	settings: Settings,
	loaded: boolean, -- the load is over (worked or not)
	canSave: boolean, -- the load worked (a missing key counts: a new player)
	touched: boolean, -- the player changed something: a load ending later keeps their values
	version: number, -- one more for each change
	savedVersion: number, -- the change number the last save that worked carried
	saving: boolean,
	timer: thread?, -- the delayed save waiting
	rateWindow: number,
	rateCount: number,
}

local CLOSE_WAIT = 25 -- seconds the server's closing waits for the last saves (Roblox gives 30)

local entries: { [Player]: Entry } = {}
local leaving = 0 -- saves of players who left, still running (the server's closing waits for them too)
local store: Store? = nil
local send: (Player, Settings) -> () = function(_player: Player, _settings: Settings) end

local steps = math.round(1 / Config.SETTINGS_STEP)

-- A volume as it is kept: a number from 0 to 1 on the steps, or nil (not a number, NaN, out of range).
local function volume(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value < 0 or value > 1 then
		return nil
	end
	return math.round(value * steps) / steps
end

local function defaults(): Settings
	return { music = Config.SETTINGS_DEFAULT.music, effects = Config.SETTINGS_DEFAULT.effects }
end

-- What a stored value holds, on top of the defaults (anything else in it is ignored).
local function parse(data: any): Settings
	local out = defaults()
	if typeof(data) == "table" then
		out.music = volume(data.music) or out.music
		out.effects = volume(data.effects) or out.effects
	end
	return out
end

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

-- Sets the store up (`fake`: the tests' own) and the way settings go to a player. Without a reachable store the
-- settings only last for the visit.
function SettingsService.init(sendTo: (Player, Settings) -> (), fake: Store?)
	send = sendTo
	if fake then
		store = fake
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.SETTINGS_STORE)
		end)
		if ok and result then
			store = result :: any
		else
			store = nil
			warn("[BannedWords] settings store unavailable, settings last for the visit only:", result)
		end
	end
	pcall(function() -- (the tests' fake game has no BindToClose)
		game:BindToClose(SettingsService.closeAll)
	end)
end

-- One save of `player`'s settings as they are now. Returns whether it worked. Saves of one player wait for each other.
local function saveNow(player: Player, entry: Entry): boolean
	local target = store
	if not target or not entry.canSave then
		return false
	end
	while entry.saving do
		task.wait(0.1)
	end
	if entry.savedVersion >= entry.version then
		return true -- (saved meanwhile)
	end
	entry.saving = true
	local version = entry.version
	local copy = { music = entry.settings.music, effects = entry.settings.effects }
	local ok, err = pcall(function()
		target:SetAsync(keyOf(player), copy)
	end)
	entry.saving = false
	if ok then
		entry.savedVersion = math.max(entry.savedVersion, version)
	else
		warn("[BannedWords] settings save failed:", err)
	end
	return ok
end

-- Saves after `delay` seconds, retrying a failed save after each of Config.SETTINGS_SAVE_RETRIES; a later change
-- starts over (the waiting save is replaced).
local function scheduleSave(player: Player, entry: Entry, delay: number)
	if entry.timer then
		task.cancel(entry.timer)
	end
	entry.timer = task.delay(delay, function()
		entry.timer = nil
		if entries[player] ~= entry then
			return -- (left: the leave saved)
		end
		if not entry.loaded then
			scheduleSave(player, entry, Config.SETTINGS_SAVE_DELAY) -- (the load is still out: after it)
			return
		end
		if saveNow(player, entry) then
			if entry.version > entry.savedVersion then
				scheduleSave(player, entry, Config.SETTINGS_SAVE_DELAY) -- (changed while it saved)
			end
			return
		end
		for _, wait in Config.SETTINGS_SAVE_RETRIES do
			task.wait(wait)
			if entries[player] ~= entry or entry.timer then
				return -- (left, or a newer change took over)
			end
			if saveNow(player, entry) then
				return
			end
		end
	end)
end

-- A player came: their settings load (defaults until then) and go to them once the load is over.
function SettingsService.join(player: Player)
	if entries[player] then
		return
	end
	local entry: Entry = { settings = defaults(), loaded = false, canSave = false, touched = false, version = 0,
		savedVersion = 0, saving = false, timer = nil, rateWindow = -math.huge, rateCount = 0 }
	entries[player] = entry
	task.spawn(function()
		local target = store
		local found, worked = nil, false
		if target then
			for attempt = 1, 2 do
				local ok, result = pcall(function()
					return target:GetAsync(keyOf(player))
				end)
				if ok then
					found, worked = result, true
					break
				end
				warn("[BannedWords] settings load failed:", result)
				if attempt == 1 then
					task.wait(Config.SETTINGS_LOAD_RETRY)
				end
				if entries[player] ~= entry then
					return -- (left meanwhile)
				end
			end
		end
		if entries[player] ~= entry then
			return
		end
		entry.canSave = worked
		if worked and not entry.touched then
			entry.settings = parse(found)
		end
		entry.loaded = true
		send(player, entry.settings)
	end)
end

-- The settings to send again (Sync), or nil while the load is still out (they go when it is over).
function SettingsService.get(player: Player): Settings?
	local entry = entries[player]
	if entry and entry.loaded then
		return { music = entry.settings.music, effects = entry.settings.effects }
	end
	return nil
end

-- The player changed their settings: `payload` = { music?, effects? }. Anything not a volume is ignored.
function SettingsService.change(player: Player, payload: any)
	local entry = entries[player]
	if not entry or typeof(payload) ~= "table" then
		return
	end
	local now = os.clock()
	if now - entry.rateWindow >= 1 then
		entry.rateWindow, entry.rateCount = now, 0
	end
	entry.rateCount += 1
	if entry.rateCount > Config.SETTINGS_RATE then
		return
	end
	local music, effects = volume(payload.music), volume(payload.effects)
	if (music == nil or music == entry.settings.music) and (effects == nil or effects == entry.settings.effects) then
		return
	end
	entry.settings = { music = music or entry.settings.music, effects = effects or entry.settings.effects }
	entry.touched = true
	entry.version += 1
	scheduleSave(player, entry, Config.SETTINGS_SAVE_DELAY)
end

-- A player left: what they changed and was not saved yet is saved now (once, no retries: they are gone).
function SettingsService.leave(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entries[player] = nil
	if entry.timer then
		task.cancel(entry.timer)
		entry.timer = nil
	end
	if entry.loaded and entry.version > entry.savedVersion then
		leaving += 1
		task.spawn(function()
			saveNow(player, entry)
			leaving -= 1
		end)
	end
end

-- The server closes: everyone with unsaved changes is saved at once, and the closing waits for those saves and for the
-- saves of players who just left (at most CLOSE_WAIT seconds). Not in Studio (stopping a test would wait each time).
function SettingsService.closeAll()
	if RunService:IsStudio() then
		return
	end
	local pending = 0
	for player, entry in entries do
		if entry.timer then
			task.cancel(entry.timer)
			entry.timer = nil
		end
		if entry.loaded and entry.version > entry.savedVersion then
			pending += 1
			task.spawn(function()
				saveNow(player, entry)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + CLOSE_WAIT
	while (pending > 0 or leaving > 0) and os.clock() < deadline do
		task.wait(0.2)
	end
end

return SettingsService
