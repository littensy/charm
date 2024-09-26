local validate = require(script.Parent.validate)

--[=[
	A special symbol that denotes the absence of a value. Used to represent
	deleted values in patches.
]=]
local NONE = { __none = "__none" }

local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

--[=[
	JSON serialization can drop the last values of a sparse array. For example,
	`{ [1] = 1, [3] = 3 }` becomes `[1]` in some cases. This loss of data can
	cause hard-to-debug issues down the line, so we need to ensure that all
	arrays are dense.

	This function coerces the input object into being interpreted as a dense
	array, so that the above result would instead be `[1, null, 3]`.
]=]
local function coerceDenseArray(array: { any })
	local maxn = -1

	for index in next, array do
		if type(index) ~= "number" then
			return array
		end

		if index > 2 ^ 16 then
			-- The object is too large to be considered a dense array
			if _G.__DEV__ then
				warn(
					"Charm encountered an array that may not be synced reliably. This can happen for any of the following reasons:",
					"\n1. The array is too large (more than 2^16 elements).",
					"\n2. The array has large gaps between elements (e.g. { [1] = foo, [100000] = bar }).",
					"\n3. The array is keyed by large numbers (e.g. { [1234] = foo, [5678] = bar }).",
					"\nTo resolve this issue, consider using string keys instead of an array.",
					`\n\tat index {index} of array`,
					array
				)
			end

			return array
		end

		maxn = math.max(maxn, index)
	end

	if maxn == -1 or maxn == #array then
		-- If the table is already dense, return it as-is
		return array
	end

	local result = table.create(maxn)

	table.move(array, 1, maxn, 1, result)

	return result
end

local function diff(prevState: { [any]: any }, nextState: { [any]: any })
	local patches = table.clone(nextState)
	local numeric = true

	for key, previous in next, prevState do
		local next = nextState[key]

		if numeric and type(key) ~= "number" then
			numeric = false
		end

		if previous == next then
			patches[key] = nil
		elseif next == nil then
			patches[key] = NONE
		elseif type(previous) == "table" and type(next) == "table" then
			patches[key] = diff(previous, next)
		end
	end

	if numeric then
		-- Coerce sparse array patches into being interpreted as dense arrays
		patches = coerceDenseArray(patches)
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

	return patches
end

local function apply(state: any, patches: any): any
	if type(patches) == "table" and patches.__none == "__none" then
		return nil
	elseif type(state) ~= "table" or type(patches) ~= "table" then
		return patches
	end

	local nextState = table.clone(state)
	local stateIsArray = state[1] ~= nil

	for key, patch in next, patches do
		-- Diff-checking an array produces a sparse array, which will not be
		-- preserved when converted to JSON. To prevent this, we turn string
		-- keys back into numeric keys.
		if stateIsArray and type(key) == "string" then
			key = tonumber(key) or key
		end

		nextState[key] = apply(nextState[key], patch)
	end

	return nextState
end

return {
	NONE = NONE,
	isNone = isNone,
	diff = diff,
	apply = apply,
}
