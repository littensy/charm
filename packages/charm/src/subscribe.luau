local core = require("./core")

local computed = core.computed
local effect = core.effect
local peek = core.peek

--- Creates an effect that only runs the callback when the value returned by the
--- getter changes. The callback receives the new value and the previous value
--- as arguments.
---
--- @param getter A function that returns the value to watch.
--- @param callback The function to run when the value changes.
--- @return A function for disposing the effect.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
local function subscribe<T>(getter: () -> T, callback: (state: T, lastState: T) -> ()): () -> ()
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
			peek(callback, current, previous)
		end
	end)
end

return subscribe
