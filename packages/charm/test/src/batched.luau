local core = require("./core")

local startBatch = core.startBatch
local endBatch = core.endBatch

local function handleBatched(ok: boolean, ...)
	endBatch()
	if ok then
		return ...
	else
		error((...))
	end
end

local function batched<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	startBatch()
	return handleBatched(pcall(callback, ...))
end

return batched
