local function isTableUnsafe(object: { [any]: any })
	local key = next(object)

	if key == nil then
		return false
	end

	local keyType = type(key)
	local maxKey = 0

	-- Keys must all be the same type
	for key in object do
		if type(key) ~= keyType then
			return true
		elseif keyType == "number" and key > maxKey then
			maxKey = key
		end
	end

	-- Array keys must be sequential
	if keyType == "number" and maxKey > #object then
		return true
	end

	return false
end

--- Throws an error if the value is a table that cannot be synced via
--- RemoteEvents or RemoteFunctions. This only aims to catch common mistakes
--- with remote argument limitations, such as sparse arrays or mixed tables.
---
--- @param value The table value.
--- @param key The key of the value.
--- @error Throws an error if the value cannot be synced.
local function validate(value: { [any]: any })
	if isTableUnsafe(value) then
		-- Silence warnings during testing
		if game then
			warn("Cannot sync table:", value)
		end
		error(
			`Cannot sync tables unsupported by remote events! See the warning above for more info.\n\n`
				.. "This can be for the following reasons:\n"
				.. "1. The table is a sparse array with non-sequential indices\n"
				.. "2. The table is a mixed table (not all keys have the same type)\n\n"
				.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations"
		)
	end
end

return validate
