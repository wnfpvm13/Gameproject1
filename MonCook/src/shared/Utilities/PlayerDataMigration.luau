--!strict
local Defaults = require(script.Parent.PlayerDataDefaults)
local Migration = {}

local function fail(path: string, message: string)
	error("PlayerData " .. path .. ": " .. message, 3)
end

-- Persisted data must be an acyclic data tree. Copy before validation/filling;
-- an error cannot partially mutate the caller's loaded profile.
local function clone(value: any, path: string, ancestors: { [any]: boolean }): any
	local kind = type(value)
	if kind == "number" then
		if value ~= value or math.abs(value) == math.huge then fail(path, "non-finite number") end
	elseif kind ~= "table" and kind ~= "string" and kind ~= "boolean" then
		fail(path, "unsupported persisted type " .. kind)
	end
	if kind ~= "table" then return value end
	if ancestors[value] then fail(path, "cyclic data") end
	ancestors[value] = true
	local copy = {}
	for key, child in value do
		if type(key) ~= "string" and type(key) ~= "number" then fail(path, "invalid data key") end
		copy[key] = clone(child, path .. "." .. tostring(key), ancestors)
	end
	ancestors[value] = nil
	return copy
end

local function fillKnown(target: any, template: any, path: string)
	for key, expected in template do
		local childPath = path .. "." .. tostring(key)
		local actual = target[key]
		if actual == nil then
			target[key] = clone(expected, childPath, {})
		elseif type(actual) ~= type(expected) then
			fail(childPath, "expected " .. type(expected) .. ", received " .. type(actual))
		elseif type(expected) == "table" then
			if #expected > 0 then
				-- Existing arrays may legitimately be empty; never restore sample entries.
				local count = 0
				for index, element in actual do
					if type(index) ~= "number" or index < 1 or index % 1 ~= 0 then fail(childPath, "expected array keys") end
					if type(element) ~= type(expected[1]) then fail(childPath, "invalid array element type") end
					count += 1
				end
				if count ~= #actual then fail(childPath, "expected dense array") end
			else
				-- Empty templates intentionally leave unspecified collection layouts intact.
				fillKnown(actual, expected, childPath)
			end
		end
	end
end

function Migration.migrate(raw: any): any
	if type(raw) ~= "table" then fail("root", "expected an existing profile table; use Defaults.new for new players") end
	local version = raw.SchemaVersion
	-- Only the documented v1 and unversioned/v0 legacy seed are understood.
	if version ~= nil then
		if type(version) ~= "number" or version % 1 ~= 0 or version < 0 then fail("SchemaVersion", "invalid version") end
		if version > Defaults.SchemaVersion then fail("SchemaVersion", "unsupported future version " .. tostring(version)) end
	end
	local result = clone(raw, "root", {})
	fillKnown(result, Defaults.new(), "root")
	local signature = result.Restaurant.SignatureDishId
	if signature ~= nil and type(signature) ~= "string" then fail("root.Restaurant.SignatureDishId", "expected optional string") end
	-- Explicit hook for future version-to-version transforms; no inventory/economy reset.
	result.SchemaVersion = Defaults.SchemaVersion
	return result
end

return table.freeze(Migration)
