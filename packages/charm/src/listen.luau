local core = require("./core")
local untracked = require("./untracked")

local computed = core.computed
local effect = core.effect

local function listen<T>(getter: () -> T, listener: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
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
		untracked(listener, current, previous, dispose)
	end)

	if disposed then
		dispose()
	end

	return dispose
end

return listen
