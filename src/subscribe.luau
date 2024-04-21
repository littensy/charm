local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Molecule<T> = types.Molecule<T>

local function subscribe<T>(molecule: Molecule<T>, callback: (state: T, prev: T) -> ()): () -> ()
	local atoms, state = store.capture(molecule)

	local function listener()
		local prevState = state
		state = molecule()
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
