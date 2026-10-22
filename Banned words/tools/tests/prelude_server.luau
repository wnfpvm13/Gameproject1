-- Server test prelude: virtual clock + coroutine scheduler, fake Roblox services, a module loader that runs the
-- real module sources (require(node) by name), and a Net stub that records what would be sent. `warn` records into
-- `warnings` (a round crash or a failing mission shows up there).
local now = 1000
local queue = {}
local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end
local function runDue(target)
	while true do
		local best, index = nil, nil
		for i, item in queue do
			if item.at <= target and (best == nil or item.at < best.at) then
				best, index = item, i
			end
		end
		if not best then
			break
		end
		table.remove(queue, index)
		now = math.max(now, best.at)
		if coroutine.status(best.co) == "suspended" then
			local ok, err = coroutine.resume(best.co, table.unpack(best.args, 1, best.args.n))
			if not ok then
				error(err)
			end
		end
	end
	now = target
end
local function at(t)
	runDue(t)
end
local task = {
	wait = function(s)
		schedule(now + (s or 0), coroutine.running())
		return coroutine.yield()
	end,
	delay = function(s, fn, ...)
		schedule(now + s, coroutine.create(fn), ...)
	end,
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
	end,
}
local os = { clock = function() return now end }
local workspaceAttributes = {}
local workspace = {
	GetServerTimeNow = function() return now end,
	GetAttribute = function(_, name) return workspaceAttributes[name] end,
}
local warnings = {}
local function warn(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	table.insert(warnings, table.concat(parts, " ", 1, parts.n))
	print("WARN " .. warnings[#warnings])
end

-- Deterministic Random (Park-Miller), enough for NextNumber / NextInteger.
local Random = {
	new = function(seed)
		local state = (seed or 12345) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local function nextFloat()
			state = (state * 16807) % 2147483647
			return (state - 1) / 2147483646
		end
		return {
			NextNumber = function(_, a, b)
				local f = nextFloat()
				return if a then a + (b - a) * f else f
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nextFloat() * (b - a + 1))
			end,
		}
	end,
}

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		fire = function(...)
			for _, h in handlers do
				h(...)
			end
		end,
	}
end

local playerList = {}
local Players = {
	GetPlayers = function() return playerList end,
	PlayerRemoving = signal(),
	PlayerAdded = signal(),
}
local RunService = { IsStudio = function() return true end }

local loaders = {}
local cache = {}
local function node(name)
	return setmetatable({ __name = name }, {
		__index = function(_, k)
			if k == "Parent" then
				return node("parent")
			elseif k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, n) return node(n) end
			end
			return nil
		end,
	})
end
local function require(n)
	local name = n.__name
	if cache[name] == nil then
		assert(loaders[name], "no loader for " .. tostring(name))
		cache[name] = loaders[name]()
	end
	return cache[name]
end
local script = node("script")
local game = {
	GetService = function(_, n)
		if n == "Players" then
			return Players
		elseif n == "RunService" then
			return RunService
		end
		return node(n)
	end,
}

local NetStub = { listeners = {}, sent = {}, notices = {} }
function NetStub.listen(name, fn) NetStub.listeners[name] = fn end
function NetStub.toAll(name, payload) table.insert(NetStub.sent, { at = now, name = name, payload = payload }) end
function NetStub.to(player, name, payload) table.insert(NetStub.sent, { at = now, name = name, payload = payload, to = player }) end
function NetStub.notice(text) table.insert(NetStub.notices, { at = now, text = text }) end
loaders.Net = function() return NetStub end
