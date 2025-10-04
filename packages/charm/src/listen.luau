local core = require("./core")

local computed = core.computed
local effect = core.effect
local peek = core.peek

--- Creates an effect that runs the callback one immediately, and then again
--- when the value returned by the getter changes. The callback receives the new
--- value, the previous value, and a cleanup function as arguments.
---
--- @param getter A function that returns the value to watch.
--- @param callback The function to run when the value changes.
--- @return A function for disposing the effect.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
local function listen<T>(getter: () -> T, callback: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local tracked = computed(function()
		return getter()
	end)

	local current: T
	local disposed = false

	local function dispose()
		disposed = true
	end

	dispose = effect(function()
		local previous = current
		current = tracked()
		peek(callback, current, previous, dispose)
	end)

	if disposed then
		dispose()
	end

	return dispose
end

return listen
