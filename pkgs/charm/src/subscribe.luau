local signals = require("./signals")
local spawn = require("./spawn")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function subscribe<T>(selector: () -> T, listener: (T, T) -> ()): () -> ()
	local current: T
	local mounted = true

	return effect(function()
		local value = selector()

		if mounted then
			current = value
			mounted = false
		elseif value ~= current then
			local previous = current
			current = value

			pauseTracking()
			spawn(listener, value, previous)
			resumeTracking()
		end
	end)
end

return subscribe
