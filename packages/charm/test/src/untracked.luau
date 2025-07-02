local core = require("./core")

local setCurrentTracking = core.setCurrentTracking

local function handleUntracked(prevTracking: boolean, ok: boolean, ...)
	setCurrentTracking(prevTracking)
	if ok then
		return ...
	else
		error((...))
	end
end

local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	return handleUntracked(setCurrentTracking(false), pcall(callback, ...))
end

return untracked
