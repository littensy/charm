local validate = require(script.Parent.validate)

local __DEV__ = _G.__DEV__

--[=[
	A special symbol that denotes the absence of a value. Used to represent
	deleted values in patches.
]=]
local None = { __none = "__none" }

local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

--[=[
	JSON serialization can drop the last values of a sparse array. For example,
	`{ [1] = 1, [3] = 3 }` becomes `[1]` in some cases. Ambiguity in the
	serialization of sparse arrays can be resolved by converting them to
	dictionaries with string keys.

	The `apply` function will convert these dictionaries back into arrays as
	long as the target array is not sparse. This function ensures that the diff
	function produces a patch that can be correctly applied.
]=]
local function stringifySparseArray(object: { any }): { [string | number]: any }
	local maxn = table.maxn(object)

	if maxn == 0 or maxn == #object then
		-- The object is either not an array or a dense array
		return object
	end

	local dictionary = {}

	for index, value in next, object do
		dictionary[tostring(index)] = value
	end

	return dictionary
end

--[=[
	Compares two states and returns a patch that can be applied to the previous
	state to produce the next state.

	@param prevState The previous state.
	@param nextState The next state.
	@param serialize Whether to convert sparse arrays into dictionaries. Defaults to `true`.
	@returns A patch that can be applied to the previous state.
]=]
local function diff(prevState: { [any]: any }, nextState: { [any]: any }, serialize: boolean?)
	serialize = serialize ~= false

	local patches = table.clone(nextState)

	for key, previous in next, prevState do
		local current = nextState[key]

		if previous == current then
			patches[key] = nil
		elseif current == nil then
			patches[key] = None
		elseif type(previous) == "table" and type(current) == "table" then
			patches[key] = diff(previous, current, serialize)
		end
	end

	-- Coerce sparse array patches into dictionaries
	if serialize and (prevState[1] ~= nil or nextState[1] ~= nil) then
		patches = stringifySparseArray(patches)
	end

	if serialize and __DEV__ then
		for key, value in next, patches do
			validate(value, key)
		end
	end

	return patches
end

--[=[
	Applies a patch to a state and returns the next state.

	@param state The current state.
	@param patches The patches to apply.
	@returns The next state.
]=]
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
	isNone = isNone,
	diff = diff,
	apply = apply,
}
