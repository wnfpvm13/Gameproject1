-- Test prelude (Speech suite): virtual clock, coroutine scheduler, fake Instances (only what Speech.luau touches).
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
		local ok, err = coroutine.resume(best.co, table.unpack(best.args, 1, best.args.n))
		if not ok then
			error(err)
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
local workspace = { GetServerTimeNow = function() return now end }

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
local created = {}
local function makeInstance(className, initial)
	local props = initial or {}
	props.ClassName = className
	local signals = {}
	local obj = {}
	obj.GetPropertyChangedSignal = function(_, name)
		signals[name] = signals[name] or signal()
		return signals[name]
	end
	obj.IsA = function(_, c) return c == className end
	obj.Destroy = function() end
	setmetatable(obj, {
		__index = function(_, k) return props[k] end,
		__newindex = function(_, k, v)
			local old = props[k]
			props[k] = v
			if old ~= v and signals[k] then
				signals[k].fire()
			end
		end,
	})
	created[className] = obj
	return obj
end
local Instance = { new = function(className) return makeInstance(className) end }
local micInput = makeInstance("AudioDeviceInput", { Active = true, Muted = false })
local localPlayer = {
	ChildAdded = signal(),
	ChildRemoved = signal(),
	FindFirstChildOfClass = function(_, c) return if c == "AudioDeviceInput" then micInput else nil end,
}
local game = { GetService = function(_, name) return if name == "Players" then { LocalPlayer = localPlayer } else nil end }
