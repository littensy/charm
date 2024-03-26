local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Source<T> = types.Source<T>

local function capture<T>(source: Source<T>): ({ [Atom<any>]: true }, T)
	if store.listeners[source] then
		return { [source] = true }, source()
	end

	store.setCapturing(true)
	local success, result = pcall(source)
	store.setCapturing(false)

	local dependencies = table.clone(store.captured)
	table.clear(store.captured)

	if not success then
		warn("An error occurred while calling an atom:", result)
	end

	return dependencies, result
end

return capture
