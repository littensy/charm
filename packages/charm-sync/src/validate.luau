local SAFE_KEYS = { string = true, number = true }
local UNSAFE_VALUES = { ["function"] = true, thread = true }

local function isTableUnsafe(object: { [any]: any })
	local key = next(object)

	if key == nil then
		-- An empty table is always safe
		return false
	end

	local keyType = type(key)
	local keyCount = 0

	-- Keys must either be all strings or all numbers
	for key in object do
		if type(key) ~= keyType then
			return true
		end
		keyCount += 1
	end

	-- Array keys must be sequential
	if keyType == "number" and keyCount > #object then
		return true
	end

	return false
end

--- Validates a value to ensure it can be synced over a remote event.
---
--- @param value The value to validate.
--- @param key The key of the value in the table.
--- @error Throws an error if the value cannot be synced.
local function validate(value: any, key: any)
	local typeKey = type(key)
	local typeValue = type(value)

	if not SAFE_KEYS[typeKey] then
		error(`Invalid key type '{typeKey}' at key '{key}'`)
	elseif UNSAFE_VALUES[typeValue] then
		error(`Invalid value type '{typeValue}' at key '{key}'`)
	elseif typeValue == "table" then
		if getmetatable(value) ~= nil then
			error(`Cannot sync tables with metatables! Got {value} at key '{key}'`)
		elseif isTableUnsafe(value) then
			error(
				`Cannot sync tables unsupported by remote events! The table was found at the key '{key}'.\n\n`
					.. "This can be for the following reasons:\n"
					.. "1. The object is an array with non-sequential keys\n"
					.. "2. The object is a dictionary with mixed key types (e.g. string and number)\n\n"
					.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations"
			)
		end
	end

	if typeKey == "number" then
		if key == math.huge or key == -math.huge then
			error("Cannot sync infinity as key")
		elseif key ~= math.floor(key) then
			error("Cannot sync non-integer number as key")
		end
	end
end

return validate
