local signals = require("./signals")

local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function untracked<T, Args...>(callback: ((Args...) -> T) | (Args...) -> (), ...: Args...): T
	pauseTracking()
	local success, result = pcall(callback, ...)
	resumeTracking()

	if not success then
		error(result)
	end

	return result
end

return untracked
