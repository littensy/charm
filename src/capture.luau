local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>

local function capture<T>(callback: () -> T): ({ [Atom<any>]: true }, T)
	if store.listeners[callback] then
		return { [callback] = true }, callback()
	end

	store.setCapturing(true)
	local result = callback()
	store.setCapturing(false)

	local dependencies = table.clone(store.captured)
	table.clear(store.captured)

	return dependencies, result
end

return capture
