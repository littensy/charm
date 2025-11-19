local Charm = require("../Charm")

type Atom<T> = Charm.Atom<T>

type NestedTable = {
	[any]: NestedTable | any,
}

type FlattenedTable = {
	[any]: any,
}

--[[
	Flattens a nested table into a single table with slash-separated keys.
	Useful for recursively collecting atoms returned by modules.

	@param input A nested table.
	@return A flattened table with slash-separated keys.
]]
local function flatten(input: NestedTable): FlattenedTable
	local result: FlattenedTable = {}

	local function visit(node: NestedTable, path: string)
		for key, value in node do
			local location = if path == "" then key else path .. "/" .. key

			if type(value) == "table" then
				visit(value :: NestedTable, location)
			else
				result[location] = value
			end
		end
	end

	visit(input, "")

	return result
end

--[[
	Converts a signal getter and setter into an atom. This is useful for
	syncing client signals with the server, as the sync system requires both
	the getter and setter to update state.

	@param getter A function that returns the current value of the signal.
	@param setter A function that sets the value of the signal.
	@return An atom that can either get or set the signal's value.
]]
local function signalToAtom<T>(getter: () -> T, setter: (value: ((T) -> T) | T) -> T): Atom<T>
	return function(...)
		return if select("#", ...) == 0 then getter() else setter((...))
	end
end

--[[
	Returns a deep copy of the given table.
]]
local function deepCopy<T>(object: T): T
	local copy: any = table.clone(object :: any)
	for key, value in copy do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		end
	end
	return copy
end

return {
	flatten = flatten,
	signalToAtom = signalToAtom,
	deepCopy = deepCopy,
}
