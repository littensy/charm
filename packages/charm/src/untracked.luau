local core = require("./core")

local setCurrentSub = core.setCurrentSub

local function handleUntracked(prevSub: core.ReactiveNode?, ok: boolean, ...)
	setCurrentSub(prevSub)
	if ok then
		return ...
	else
		error((...))
	end
end

local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	return handleUntracked(setCurrentSub(nil), pcall(callback, ...))
end

return untracked
