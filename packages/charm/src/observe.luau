local store = require(script.Parent.store)
local subscribe = require(script.Parent.subscribe)
local types = require(script.Parent.types)
type Selector<T> = types.Selector<T>

local function noop() end

--[=[
	Creates an instance of `factory` for each item in the atom's state, and
	cleans up the instance when the item is removed. Returns a cleanup function
	that unsubscribes all instances.
	
	@param callback The atom or selector to observe.
	@param factory The function that tracks the lifecycle of each item.
	@return A function that unsubscribes all instances.
]=]
local function observe<K, V>(callback: Selector<{ [K]: V }>, factory: (value: V, key: K) -> (() -> ())?): () -> ()
	local connections: { [K]: () -> () } = {}

	local function listener(state: { [K]: V })
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
	end

	local unsubscribe = subscribe(callback, listener)

	store.peek(function(): ()
		listener(callback())
	end)

	return function()
		unsubscribe()
		for _, disconnect in next, connections do
			disconnect()
		end
		table.clear(connections)
	end
end

return observe
