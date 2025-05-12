local signals = require("./signals")

local computed = signals.computed
local effect = signals.effect

local function subscribe<T>(selector: () -> T, listener: (state: T, lastState: T) -> ()): () -> ()
	local tracked = computed(function()
		return selector()
	end)

	local current = tracked()

	return effect(function()
		local previous = current
		current = tracked()

		if current ~= previous then
			listener(current, previous)
		end
	end)
end

return subscribe
