local function isTableUnsafe(object: { [any]: any })
	local firstKey = next(object)

	if firstKey == nil then
		return false
	end

	local keyType = type(firstKey)
	local maxKey = 0

	-- Keys must all be the same type
	for key in object do
		if type(key) ~= keyType then
			return true
		elseif type(key) == "number" and key > maxKey then
			maxKey = key
		end
	end

	-- Array keys must be sequential
	if keyType == "number" and maxKey > #object then
		return true
	end

	return false
end

--[[
	Emits a warning if the value is a table that cannot be synced via
	RemoteEvents or RemoteFunctions. This only aims to catch common mistakes
	with remote argument limitations, such as sparse arrays or mixed tables.

	@param value The table value.
]]
local function validate(value: { [any]: any })
	if isTableUnsafe(value) then
		warn(
			"Cannot sync tables unsupported by remote events! This can be for the following reasons:\n"
				.. "1. The table is a sparse array with non-sequential indices\n"
				.. "2. The table is a mixed table (not all keys have the same type)\n\n"
				.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations\n",
			value
		)
	end
end

return validate
