local isAtom = require(script.Parent.Parent.isAtom)

local SAFE_KEYS = { string = true, number = true }
local SAFE_VALUES = { string = true, number = true, boolean = true, table = true }

local function isUnsafeTable(object: { [any]: any })
	local keyType = nil
	local objectSize = 0

	-- All keys must have the same type
	for key in object do
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

local function validate(value: any, key: any, log: (string) -> ())
	local typeOfKey = type(key)
	local typeOfValue = type(value)

	if not SAFE_KEYS[typeOfKey] then
		return log(`Invalid key type '{typeOfKey}' at key '{key}'`)
	elseif not SAFE_VALUES[typeOfValue] then
		return log(`Invalid value type '{typeOfValue}' at key '{key}'`)
	elseif typeOfValue == "table" then
		if getmetatable(value) ~= nil then
			return log(`Cannot sync tables with metatables! Got {value} at key '{key}'`)
		elseif isAtom(value) then
			return log(`Cannot sync nested atoms! Got atom '{value.debugLabel}' at key '{key}'`)
		elseif isUnsafeTable(value) then
			return log(
				`Cannot sync tables unsupported by remote events! The value has the key '{key}'.\n\n`
					.. "This can be for the following reasons:\n"
					.. "1. The object is an array with non-sequential keys\n"
					.. "2. The object is a dictionary with mixed key types (e.g. string and number)\n\n"
					.. "Read more: https://create.roblox.com/docs/scripting/events/remote#argument-limitations"
			)
		end
	end

	if typeOfValue == "number" then
		if value ~= value then
			return log(`Cannot sync NaN at key '{key}'`)
		elseif value == math.huge or value == -math.huge then
			return log(`Cannot sync infinity at key '{key}'`)
		end
	elseif typeOfKey == "number" then
		if key == math.huge or key == -math.huge then
			return log("Cannot sync infinity as key")
		elseif math.floor(key) ~= key then
			return log("Cannot sync non-integer number as key")
		end
	end
end

return validate
