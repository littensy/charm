local signals = require("./signals")

local setCurrentSub = signals.setCurrentSub

local function untracked<T, Args...>(callback: ((Args...) -> T) | (Args...) -> (), ...: Args...): T
	local currentSub = setCurrentSub(nil)
	local success, result = pcall(callback, ...)
	setCurrentSub(currentSub)

	if not success then
		error(result)
	end

	return result
end

return untracked
