local signals = require("./signals")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function listen<T>(selector: () -> T, listener: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local disposeImmediately = false
	local current: T

	local function dispose()
		disposeImmediately = true
	end

	dispose = effect(function()
		local previous: T? = current
		current = selector()

		if current ~= previous then
			pauseTracking()
			local success, result: unknown = pcall(listener, current, previous, dispose)
			resumeTracking()

			if not success then
				error(`listen() encountered an error: {result}`)
			end
		end
	end)

	if disposeImmediately then
		dispose()
	end

	return dispose
end

return listen
