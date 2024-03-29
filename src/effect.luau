local capture = require(script.Parent.capture)
local store = require(script.Parent.store)

local function effect(molecule: () -> nil): () -> ()
	local atoms = capture(molecule)

	local function listener()
		molecule()
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
