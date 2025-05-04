local effectScope = require("./effectScope")
local signals = require("./signals")
local spawn = require("./spawn")

local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function listen<T>(selector: () -> T, listener: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local disposed = false
	local mounted = true
	local current: T?
	local dispose: () -> ()

	local function disposeSafe()
		disposed = true
		if dispose then
			dispose()
		end
	end

	dispose = effectScope(function()
		effect(function()
			local value = selector()

			if mounted then
				mounted = false
			elseif value == current then
				return
			end

			local previous = current
			current = value

			pauseTracking()
			spawn(listener, value, previous, disposeSafe)
			resumeTracking()
		end)
	end)

	if disposed then
		dispose()
	end

	return disposeSafe
end

return listen
