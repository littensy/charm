local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Molecule<T> = types.Molecule<T>

local function capture<T>(molecule: Molecule<T>): ({ [Atom<any>]: true }, T)
	if store.listeners[molecule] then
		return { [molecule] = true }, molecule()
	end

	store.setCapturing(true)
	local success, result = pcall(molecule)
	store.setCapturing(false)

	local dependencies = table.clone(store.captured)
	table.clear(store.captured)

	if not success then
		warn("An error occurred while calling an atom:", result)
	end

	return dependencies, result
end

return capture
