local effectScope = require("./effectScope")
local signals = require("./signals")
local spawn = require("./spawn")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function subscribe<T>(selector: () -> T, listener: (T, T) -> ()): () -> ()
	local current: T
	local mount = true
	local dispose: () -> ()

	dispose = effectScope(function()
		effect(function()
			local value = selector()

			if mount then
				current = value
				mount = false
			else
				local previous = current
				current = value

				pauseTracking()
				spawn(listener, value, previous)
				resumeTracking()
			end
		end)
	end)

	return function()
		dispose()
	end
end

return subscribe
