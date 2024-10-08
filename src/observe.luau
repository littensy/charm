local effect = require(script.Parent.effect)
local types = require(script.Parent.types)
type Molecule<T> = types.Molecule<T>

local function noop() end

--[=[
	Creates an instance of `factory` for each item in the atom's state, and
	cleans up the instance when the item is removed. Returns a cleanup function
	that unsubscribes all instances.
	
	@param molecule The atom or molecule to observe.
	@param factory The function that tracks the lifecycle of each item.
	@return A function that unsubscribes all instances.
]=]
local function observe<K, V>(molecule: Molecule<{ [K]: V }>, factory: (value: V, key: K) -> (() -> ())?): () -> ()
	local connections: { [K]: () -> () } = {}

	local unsubscribe = effect(function()
		local state = molecule()

		for key, disconnect in next, connections do
			if state[key] == nil then
				connections[key] = nil
				disconnect()
			end
		end

		for key, value in next, state do
			if not connections[key] then
				connections[key] = factory(value, key) or noop
			end
		end
	end)

	local function cleanup()
		unsubscribe()
		for _, disconnect in next, connections do
			disconnect()
		end
		table.clear(connections)
	end

	return cleanup
end

return observe
