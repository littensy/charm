local core = require("./core")
local peek = require("./peek")

local computed = core.computed
local effect = core.effect

local function listen<T>(selector: () -> T, listener: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local tracked = computed(function()
		return selector()
	end)

	local current: T
	local disposed = false

	local function dispose()
		disposed = true
	end

	dispose = effect(function()
		local previous = current
		current = tracked()
		peek(listener, current, previous, dispose)
	end)

	if disposed then
		dispose()
	end

	return dispose
end

return listen
