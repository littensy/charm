local store = require(script.Parent.store)
local types = require(script.Parent.types)
type ReadonlyAtom<T> = types.ReadonlyAtom<T>

local function effect(source: ReadonlyAtom<nil>): () -> ()
	local atoms = store.capture(source)

	local function listener()
		source()
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

return effect
