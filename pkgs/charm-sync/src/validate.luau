local SAFE_KEYS = { string = true, number = true }
local UNSAFE_VALUES = { ["function"] = true, thread = true }

local function isTableUnsafe(object: { [any]: any })
	local keyType = nil
	local objectSize = 0

	-- All keys must have the same type
	for key in next, object do
		local currentType = type(key)

		if not keyType and SAFE_KEYS[currentType] then
			keyType = currentType
		elseif keyType ~= currentType then
			return true
		end

		objectSize += 1
	end

	-- If there are more keys than the length of the array, it's an array with
	-- non-sequential keys.
	if objectSize > #object and keyType == "number" then
		return true
	end

	return false
end

--[=[
	Validates a value to ensure it can be synced over a remote event.

	@param value The value to validate.
	@param key The key of the value in the table.
	@error Throws an error if the value cannot be synced.
]=]
local function validate(value: any, key: any)
	local typeOfKey = type(key)
	local typeOfValue = type(value)

	if not SAFE_KEYS[typeOfKey] then
		error(`Invalid key type '{typeOfKey}' at key '{key}'`)
	elseif UNSAFE_VALUES[typeOfValue] then
		error(`Invalid value type '{typeOfValue}' at key '{key}'`)
	elseif typeOfValue == "table" then
		if getmetatable(value) ~= nil then
			error(`Cannot sync tables with metatables! Got {value} at key '{key}'`)
		elseif isTableUnsafe(value) then
			error(
				`Cannot sync tables unsupported by remote events! The value has the key '{key}'.\n\n`
					.. "This can be for the following reasons:\n"
					.. "1. The object is an array with non-sequential keys\n"
					.. "2. The object is a dictionary with mixed key types (e.g. string and number)\n\n"
					.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations"
			)
		end
	end

	if typeOfKey == "number" then
		if key == math.huge or key == -math.huge then
			error("Cannot sync infinity as key")
		elseif key ~= math.floor(key) then
			error("Cannot sync non-integer number as key")
		end
	end
end

return validate
