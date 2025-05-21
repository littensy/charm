local signals = require("./signals")

local computed = signals.computed
local effect = signals.effect
local effectScope = signals.effectScope
local onEffectCleanup = signals.onEffectCleanup

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

		local stopScope = effectScope(function()
			listener(current, previous, dispose)
		end)

		onEffectCleanup(stopScope)
	end)

	if disposed then
		dispose()
	end

	return dispose
end

return listen
