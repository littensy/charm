local signals = require("./signals")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function subscribe<T>(selector: () -> T, listener: (state: T, lastState: T) -> ()): () -> ()
	local current: T
	local mounted = true

	return effect(function()
		local previous = current
		current = selector()

		if mounted then
			mounted = false
		elseif current ~= previous then
			pauseTracking()
			local success, result: unknown = pcall(listener, current, previous)
			resumeTracking()

			if not success then
				error(`subscribe() encountered an error: {result}`)
			end
		end
	end)
end

return subscribe
