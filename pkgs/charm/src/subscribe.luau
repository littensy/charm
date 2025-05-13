local signals = require("./signals")

local computed = signals.computed
local effect = signals.effect
local effectScope = signals.effectScope
local onEffectCleanup = signals.onEffectCleanup

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
			return
		end

		local stopScope = effectScope(function()
			listener(current, previous)
		end)

		onEffectCleanup(stopScope)
	end)
end

return subscribe
