local core = require("./core")

local setCurrentSub = core.setCurrentSub
local setCurrentScope = core.setCurrentScope
local getCurrentSub = core.getCurrentSub
local getCurrentScope = core.getCurrentScope

local function handleUntracked(
	prevSub: core.ReactiveNode?,
	prevScope: core.Effect | core.EffectScope?,
	ok: boolean,
	...
)
	if prevSub then
		setCurrentSub(prevSub)
	elseif prevScope then
		setCurrentScope(prevScope)
	end
	if ok then
		return ...
	else
		error((...))
	end
end

local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	if getCurrentSub() then
		return handleUntracked(setCurrentSub(nil), nil, pcall(callback, ...))
	elseif getCurrentScope() then
		return handleUntracked(nil, setCurrentScope(nil), pcall(callback, ...))
	else
		return callback(...)
	end
end

return untracked
