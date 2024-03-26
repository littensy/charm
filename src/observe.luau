local effect = require(script.Parent.effect)
local types = require(script.Parent.types)
type Source<T> = types.Source<T>

local function observe<K, V>(source: Source<{ [K]: V }>, factory: (value: V, key: K) -> () -> ()): () -> ()
	local connections: { [K]: () -> () } = {}

	local unsubscribe = effect(function()
		local state = source()

		for key, disconnect in connections do
			if state[key] == nil then
				connections[key] = nil
				disconnect()
			end
		end

		for key, value in state do
			if not connections[key] then
				connections[key] = factory(value, key)
			end
		end
	end)

	local function cleanup()
		unsubscribe()
		for _, disconnect in connections do
			disconnect()
		end
	end

	return cleanup
end

return observe
