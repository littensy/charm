local Charm = require("../Charm")
local config = require("./config")
local types = require("./types")
local validate = require("./validate")

local flags = Charm.flags

export type None = types.None

local None: None = { __none = "__none" }

--[[
	Checks whether a value is `None`. If `true`, the value is scheduled to be
	removed from the state when the patch is applied.

	@param value The value to check.
	@return `true` if the value is `None`, otherwise `false`.
]]
local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

--[[
	Converts `nil` values to the special `None` symbol. This is useful when
	preparing data for serialization, since `nil` can represent both the absence
	of a value and the removal of a value in patches.
]]
local function nilToNone<T>(value: T?): T | None
	return if value == nil then None else value
end

--[[
	JSON serialization can drop the last values of a sparse array. For example,
	`{ [1] = 1, [3] = 3 }` becomes `[1]` in some cases. Ambiguity in the
	serialization of sparse arrays can be resolved by converting them to
	dictionaries with string keys.

	The `patch` functions will convert these dictionaries back into arrays as
	long as the target array is not sparse. This function ensures that the diff
	function produces a patch that can be correctly applied.
]]
local function stringifySparseArray(object: {}): { [string | number]: any }
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

local function diff(oldState: any, newState: any): any
	if oldState == newState then
		return nil
	elseif newState == nil then
		return None
	elseif type(oldState) ~= "table" or type(newState) ~= "table" then
		return newState
	end

	local diffs = table.clone(newState)

	for key, oldValue in oldState do
		diffs[key] = diff(oldValue, newState[key])
	end

	if next(diffs) == nil then
		return nil
	end

	if config.fixArrays then
		-- Convert sparse array patches that could be misserialized
		if oldState[1] ~= nil or newState[1] ~= nil then
			diffs = stringifySparseArray(diffs)
		end
		if flags.strict and config.validatePatches then
			validate(diffs)
		end
	end

	return diffs
end

local function apply(oldState: any, diffs: any): any
	if isNone(diffs) then
		return nil
	elseif type(oldState) ~= "table" or type(diffs) ~= "table" then
		return diffs
	end

	local newState = table.clone(oldState)
	local stateIsArray = oldState[1] ~= nil

	for key, value in diffs do
		-- Diff-checking an array produces a sparse array, which will not be
		-- preserved when converted to JSON. To prevent this, we turn string
		-- keys back into numeric keys.
		if stateIsArray and type(key) == "string" then
			key = tonumber(key) or key
		end
		newState[key] = apply(newState[key], value)
	end

	return newState
end

local function applyMutable(targetState: any, diffs: any): any
	if isNone(diffs) then
		return nil
	elseif type(targetState) ~= "table" or type(diffs) ~= "table" then
		return diffs
	end

	local targetIsArray = targetState[1] ~= nil

	for key, value in diffs do
		if targetIsArray and type(key) == "string" then
			key = tonumber(key) or key
		end
		targetState[key] = applyMutable(targetState[key], value)
	end

	return targetState
end

return {
	isNone = isNone,
	nilToNone = nilToNone,
	diff = diff,
	apply = apply,
	applyMutable = applyMutable,
}
