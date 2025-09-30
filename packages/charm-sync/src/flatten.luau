type NestedAtomMap = {
	[string]: NestedAtomMap | () -> any,
}

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
