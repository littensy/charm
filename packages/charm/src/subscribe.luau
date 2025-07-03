local core = require("./core")
local peek = require("./peek")

local computed = core.computed
local effect = core.effect

local function subscribe<T>(selector: () -> T, listener: (state: T, lastState: T) -> ()): () -> ()
	local tracked = computed(function()
		return selector()
	end)

	local current: T
	local mounted = true

	return effect(function()
		local previous = current
		current = tracked()
		if mounted then
			mounted = false
		else
			peek(listener, current, previous)
		end
	end)
end

return subscribe
