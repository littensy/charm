local Charm = require("../Charm")

type Atom<T> = Charm.Atom<T>

type NestedState = {
	[string]: NestedState | () -> any,
}

type FlattenedState = {
	[string]: () -> any,
}

local function isAtomOrSignal(value: any): boolean
	return type(value) ~= "table" or (type(value.get) == "function" and type(value.set) == "function")
end

--- Flattens a nested map of atoms or signals into a single object with
--- slash-separated keys. Useful for recursively collecting atoms returned by
--- modules.
---
--- @param states A nested table of atoms or signals.
--- @return A flattened map of atoms or signals.
local function flattenState(states: NestedState): FlattenedState
	local result: FlattenedState = {}

	local function visit(node: NestedState, path: string)
		for key, value in node do
			local location = if path == "" then key else path .. "/" .. key

			if isAtomOrSignal(value) then
				result[location] = value :: () -> any
			else
				visit(value :: NestedState, location)
			end
		end
	end

	visit(states, "")

	return result
end

--- Converts a signal getter and setter into an atom. This is useful for
--- syncing client signals with the server, as the sync system requires both
--- the getter and setter to update state.
---
--- @param getter A function that returns the current value of the signal.
--- @param setter A function that sets the value of the signal.
--- @return An atom that can either get or set the signal's value.
local function signalToAtom<T>(getter: () -> T, setter: (value: ((T) -> T) | T) -> T): Atom<T>
	return function(...)
		return if select("#", ...) == 0 then getter() else setter((...))
	end
end

return {
	flattenState = flattenState,
	signalToAtom = signalToAtom,
}
