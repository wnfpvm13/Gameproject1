-- Offline authored source sampler. Run with official Luau CLI from this folder.
local Motion = require("../src/shared/Utilities/CombatAnimation")
local Config = require("../src/shared/Config/HuntingConfig")
local function json(value)
	if type(value) == "number" then return tostring(value) end
	if type(value) == "string" then return string.format("%q", value) end
	local pairs = {}
	for k, v in value do table.insert(pairs, json(tostring(k))..":"..json(v)) end
	table.sort(pairs)
	return "{"..table.concat(pairs, ",").."}"
end
local clips = {}
for _, name in { "Basic1", "Basic2", "Basic3", "Heavy", "Dodge" } do
	local kind = if string.sub(name,1,5) == "Basic" then "Basic" else name
	local combo = if kind == "Basic" then tonumber(string.sub(name,6)) else 0
	local attack = if kind == "Basic" then Config.Weapon.StarterCleaver.Basic[combo] else Config.Weapon.StarterCleaver.Heavy
	local windup = if kind == "Dodge" then Config.Combat.Rules.DodgeSeconds else attack.Windup
	local window, recovery = if kind == "Dodge" then 0 else attack.Window, if kind == "Dodge" then 0 else attack.Recovery
	local duration, frames = windup+window+recovery, {}
	local times = { 0, duration }
	if kind ~= "Dodge" then table.insert(times,windup); table.insert(times,windup+window/2); table.insert(times,windup+window) end
	for step = 1, math.floor(duration*60) do table.insert(times,step/60) end
	table.sort(times)
	for _, at in times do frames[tostring(at)] = Motion.player(kind,combo,at,windup,window,recovery) end
	clips[name] = { Duration = duration, Windup = windup, Window = window, Recovery = recovery, Frames = frames }
end
print(json(clips))
