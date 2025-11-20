local function isTableUnsafe(object: {})
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
	@param key The key of the value.
]]
local function validate(value: {})
	if isTableUnsafe(value) then
		warn(
			`Cannot sync tables unsupported by remote events! See the table below for more info.\n\n`
				.. "This can be for the following reasons:\n"
				.. "1. The table is a sparse array with non-sequential indices\n"
				.. "2. The table is a mixed table (not all keys have the same type)\n\n"
				.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations\n",
			value
		)
	end
end

return validate
