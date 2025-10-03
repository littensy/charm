local core = require("./core")

local UNTRACKED = core.ReactiveFlags.Untracked
local getCurrentSub = core.getCurrentSub

local function handlePeek(sub: core.ReactiveNode?, ok: boolean, ...)
	if sub then
		sub.flags = bit32.band(sub.flags, bit32.bnot(UNTRACKED))
	end
	if ok then
		return ...
	else
		error((...))
	end
end

local function peek<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	local sub = getCurrentSub()
	if not sub or bit32.btest(sub.flags, UNTRACKED) then
		return callback(...)
	else
		sub.flags = bit32.bor(sub.flags, UNTRACKED)
	end
	return handlePeek(sub, pcall(callback, ...))
end

return peek
