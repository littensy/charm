local Charm = require("../Charm")
local config = require("./config")
local types = require("./types")
local validate = require("./validate")

local flags = Charm.flags

export type None = types.None

--- A special symbol that denotes the absence of a value. Used to represent
--- deleted values in patches.
local None: None = { __none = "__none" }

--- Checks whether a value is `None`. If `true`, the value is scheduled to be
--- removed from the state when the patch is applied.
---
--- @param value The value to check.
--- @return `true` if the value is `None`, otherwise `false`.
local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

--- Converts `nil` values to the special `None` symbol. This is useful when
--- preparing data for serialization, since `nil` can represent both the absence
--- of a value and the removal of a value in patches.
local function nilToNone<T>(value: T?): T | None
	return if value == nil then None else value
end

--- JSON serialization can drop the last values of a sparse array. For example,
--- `{ [1] = 1, [3] = 3 }` becomes `[1]` in some cases. Ambiguity in the
--- serialization of sparse arrays can be resolved by converting them to
--- dictionaries with string keys.
---
--- The `apply` function will convert these dictionaries back into arrays as
--- long as the target array is not sparse. This function ensures that the diff
--- function produces a patch that can be correctly applied.
local function stringifySparseArray(object: { any }): { [string | number]: any }
	local maxn = table.maxn(object)

	if maxn == 0 or maxn == #object then
		-- The object is either not an array or a dense array
		return object
	end

	local dictionary = {}

	for index, value in object do
		dictionary[tostring(index)] = value
	end

	return dictionary
end

--- Compares two states and returns a patch that can be applied to the current
--- state to produce the next state.
---
--- @param currentState The current state.
--- @param nextState The next state.
--- @return A patch that can be applied to the current state.
local function diff(currentState: any, nextState: any): any
	if currentState == nextState then
		return nil
	elseif nextState == nil then
		return None
	elseif type(currentState) ~= "table" or type(nextState) ~= "table" then
		return nextState
	end

	local patches: { [any]: any } = table.clone(nextState)

	for key, previous in currentState do
		patches[key] = diff(previous, nextState[key])
	end

	if config.autoSerialize then
		-- Coerce sparse array patches into dictionaries
		if currentState[1] ~= nil or nextState[1] ~= nil then
			patches = stringifySparseArray(patches)
		end

		if flags.strict and config.validatePatches then
			for key, value in patches do
				validate(value, key)
			end
		end
	end

	return patches
end

--- Applies a patch to a state and returns the resulting value.
---
--- @param currentState The current state.
--- @param statePatch The patches to apply.
--- @return The new state with the patch applied.
local function apply(currentState: any, statePatch: any): any
	if isNone(statePatch) then
		return nil
	elseif type(currentState) ~= "table" or type(statePatch) ~= "table" then
		return statePatch
	end

	local nextState = table.clone(currentState)
	local stateIsArray = currentState[1] ~= nil

	for key, value in statePatch do
		-- Diff-checking an array produces a sparse array, which will not be
		-- preserved when converted to JSON. To prevent this, we turn string
		-- keys back into numeric keys.
		if stateIsArray and type(key) == "string" then
			key = tonumber(key) or key
		end

		nextState[key] = apply(nextState[key], value)
	end

	return nextState
end

return {
	isNone = isNone,
	nilToNone = nilToNone,
	diff = diff,
	apply = apply,
}
