local capture = require(script.Parent.capture)
local store = require(script.Parent.store)

local function effect(source: () -> nil): () -> ()
	local atoms = capture(source)

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
