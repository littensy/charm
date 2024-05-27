local store = require(script.Parent.store)

local function effect(molecule: () -> nil): () -> ()
	local captured = store.capture(molecule)

	local function listener()
		molecule()
	end

	for atom in captured do
		store.listeners[atom][listener] = true
	end

	return function()
		for atom in captured do
			store.listeners[atom][listener] = nil
		end
	end
end

return effect
