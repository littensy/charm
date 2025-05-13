local noYield = require("./noYield")
local signals = require("./signals")

type ReactiveNode = signals.ReactiveNode

local setCurrentSub = signals.setCurrentSub

local function handleUntracked(currentSub: ReactiveNode?, ok: boolean, ...)
	setCurrentSub(currentSub)
	if ok then
		return ...
	else
		error(...)
	end
end

local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	return handleUntracked(setCurrentSub(nil), noYield(callback, ...))
end

return untracked
