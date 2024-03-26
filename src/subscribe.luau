local capture = require(script.Parent.capture)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Source<T> = types.Source<T>

local function subscribe<T>(source: Source<T>, callback: (state: T, prev: T) -> ()): () -> ()
	local atoms, state = capture(source)

	local function listener()
		local prevState = state
		state = source()
		callback(state, prevState)
	end

	for atom in atoms do
		store.listeners[atom][listener] = true
	end

	return function()
		for atom in atoms do
			store.listeners[atom][listener] = nil
		end
	end
end

return subscribe
