local signals = require("./signals")
local spawn = require("./spawn")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function listen<T>(selector: () -> T, listener: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local disposeImmediately = false
	local current: T?

	local function dispose()
		disposeImmediately = true
	end

	dispose = effect(function()
		local value = selector()

		if value ~= current then
			local previous = current
			current = value

			pauseTracking()
			spawn(listener, value, previous, dispose)
			resumeTracking()
		end
	end)

	if disposeImmediately then
		dispose()
	end

	return dispose
end

return listen
