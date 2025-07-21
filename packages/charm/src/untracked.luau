local core = require("./core")

local setCurrentWatching = core.setCurrentWatching

local function handleUntracked(prevWatching: boolean, ok: boolean, ...)
	setCurrentWatching(prevWatching)
	if ok then
		return ...
	else
		error((...))
	end
end

local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	return handleUntracked(setCurrentWatching(false), pcall(callback, ...))
end

return untracked
