local signals = require("./signals")

local effect = signals.effect
local setCurrentSub = signals.setCurrentSub

local function subscribe<T>(selector: () -> T, listener: (state: T, lastState: T) -> ()): () -> ()
	local current: T
	local mounted = true

	return effect(function()
		local previous = current
		current = selector()

		if mounted then
			mounted = false
		elseif current ~= previous then
			local prevSub = setCurrentSub(nil)
			local success, result: unknown = pcall(listener, current, previous)
			setCurrentSub(prevSub)

			if not success then
				error(`subscribe() encountered an error: {result}`)
			end
		end
	end)
end

return subscribe
