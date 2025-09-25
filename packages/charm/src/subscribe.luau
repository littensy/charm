local core = require("./core")
local untracked = require("./untracked")

local computed = core.computed
local effect = core.effect

local function subscribe<T>(getter: () -> T, listener: (state: T, lastState: T) -> ()): () -> ()
	local tracked = computed(function()
		return getter()
	end)

	local current: T
	local mounted = true

	return effect(function()
		local previous = current
		current = tracked()
		if mounted then
			mounted = false
		else
			untracked(listener, current, previous)
		end
	end)
end

return subscribe
