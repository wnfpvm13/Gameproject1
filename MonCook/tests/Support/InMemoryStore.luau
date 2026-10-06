--!strict
-- Test/Studio-only adapter. Copies at the boundary to match DataStore isolation.
local Store = {}
Store.__index = Store
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end
function Store.new(): any
	return setmetatable({ Values = {}, FailNext = false, RetryNext = false, BeforeTransform = nil }, Store)
end
function Store.UpdateAsync(self: any, key: string, transform: (any) -> any): any
	if self.FailNext then self.FailNext = false; error("injected store failure") end
	local before: any = self.BeforeTransform
	if before ~= nil then (before :: () -> ())() end
	if self.RetryNext then self.RetryNext = false; transform(clone(self.Values[key])) end
	local result = transform(clone(self.Values[key]))
	if result ~= nil then self.Values[key] = clone(result) end
	return clone(result)
end
function Store.Read(self: any, key: string): any return clone(self.Values[key]) end
return Store
