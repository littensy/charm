local unsafe = { thread = true, ["function"] = true }

--[=[
	Validates a value to ensure it can be passed through Charm Sync.

	@param value The value to validate.
	@param key The key of the value in the table.
	@error Throws an error if the value cannot be synced.
]=]
local function validate(value: any, key: any, path: string)
	local typeKey = type(key)
	local typeValue = type(value)

	if unsafe[typeKey] then
		error(`Invalid key type {typeKey} at path '{path}/{key}'`)
	elseif unsafe[typeValue] then
		error(`Invalid value type {typeValue} at path '{path}/{key}'`)
	end

	if typeKey == "table" then
		assert(getmetatable(key) == nil, `Invalid key has metatable at path '{path}/{key}'`)

		for k, v in next, key do
			validate(v, k, `{path}/{key}`)
		end
	end

	if typeValue == "table" then
		assert(getmetatable(value) == nil, `Invalid value has metatable at path '{path}/{key}'`)

		for k, v in next, value do
			validate(v, k, `{path}/{key}`)
		end
	end
end

return validate
