local validate = require(script.Parent.validate)

--[=[
	A special symbol that denotes the absence of a value. Used to represent
	deleted values in patches.
]=]
local None = { __none = "__none" }

local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

local function diff(prevState: { [any]: any }, nextState: { [any]: any }, convertArrays: boolean?)
	if convertArrays == nil then
		convertArrays = true
	end

	local patch = table.clone(nextState)

	for key, previous in next, prevState do
		local current = nextState[key]

		if previous == current then
			patch[key] = nil
		elseif current == nil then
			patch[key] = None
		elseif type(previous) == "table" and type(current) == "table" then
			patch[key] = diff(previous, current, convertArrays)
		end
	end

	-- JSON serialization can drop the last values of a sparse array. For example,
	-- `{ [1] = 1, [3] = 3 }` becomes `[1]` in some cases. Ambiguity in the
	-- serialization of sparse arrays can be resolved by coercing remote events
	-- to convert these arrays into dictionaries.
	if convertArrays and (prevState[1] ~= nil or nextState[1] ~= nil) then
		-- Set to an existing value to satisfy serialization
		patch[0] = prevState[1] or nextState[1]
	end

	if _G.__DEV__ then
		for key, value in next, prevState do
			validate(value, key)
		end

		for key, value in nextState do
			if prevState[key] ~= value then
				validate(value, key)
			end
		end
	end

	return patch
end

local function apply(state: any, patch: any): any
	if type(patch) == "table" and patch.__none == "__none" then
		return nil
	elseif type(state) ~= "table" or type(patch) ~= "table" then
		return patch
	end

	local result = table.clone(state)
	local numeric = state[1] ~= nil

	for key, value in next, patch do
		-- Diff-checking an array produces a sparse array, which will not be
		-- preserved when converted to JSON. To prevent this, we turn string
		-- keys back into numeric keys.
		if numeric then
			if key == "0" or key == 0 then
				continue
			end

			key = tonumber(key) or key
		end

		result[key] = apply(result[key], value)
	end

	return result
end

return {
	None = None,
	isNone = isNone,
	diff = diff,
	apply = apply,
}
