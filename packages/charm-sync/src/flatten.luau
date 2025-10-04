type NestedAtomMap = {
	[string]: NestedAtomMap | () -> any,
}

--- Flattens a nested atom map into a single object with slash-separated keys.
--- Useful for recursively collecting atoms returned by modules.
---
--- @param atoms The nested atom map to flatten.
--- @return A flattened atom map.
local function flatten(atoms: NestedAtomMap): { [string]: () -> any }
	local result: { [string]: () -> any } = {}

	local function visit(node: NestedAtomMap, path: string)
		for key, value in node do
			local location = if path == "" then key else path .. "/" .. key

			if type(value) == "table" then
				visit(value, location)
			else
				result[location] = value
			end
		end
	end

	visit(atoms, "")

	return result
end

return flatten
