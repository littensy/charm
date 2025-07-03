local core = require("./core")

local setCurrentTracking = core.setCurrentTracking

local function handlePeek(prevTracking: boolean, ok: boolean, ...)
	setCurrentTracking(prevTracking)
	if ok then
		return ...
	else
		error((...))
	end
end

local function peek<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	return handlePeek(setCurrentTracking(false), pcall(callback, ...))
end

return peek
