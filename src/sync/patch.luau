local validate = require(script.Parent.validate)

--[=[
	A special value that denotes the absence of a value. Used to represent
	undefined values in patches.
]=]
local NONE = { __none = "__none" }

local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

--[=[
	Some sparse arrays lose outlying values when serialized to JSON. For
	example, `[1, 2, nil, nil, 5]` becomes `[1, 2]` in some cases. This loss of
	data can cause hard-to-debug issues down the line.

	This function coerces the input object into being interpreted as a dense
	array, so that the aforementioned `[1, 2]` result would instead be
	`[1, 2, nil, nil, 5]`.
]=]
local function coerceSparseArray(object: any)
	-- The object must be a table with a numeric key
	if type(object) ~= "table" or type((next(object))) ~= "number" then
		return object
	end

	local maxn = table.maxn(object :: any)

	-- If the table is already dense, return it as-is
	if maxn == #object then
		return object
	end

	local result = table.create(maxn, 0)

	table.move(object, 1, maxn, 1, result)

	return result
end

local function diff(prevState: { [any]: any }, nextState: { [any]: any })
	local patches = table.clone(nextState)

	for key, previous in next, prevState do
		local next = nextState[key]

		if previous == next then
			patches[key] = nil
		elseif next == nil then
			patches[key] = NONE
		elseif type(previous) == "table" and type(next) == "table" then
			patches[key] = diff(previous, next)
		end
	end

	-- Coerce the patches into being interpreted as dense arrays.
	patches = coerceSparseArray(patches)

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
