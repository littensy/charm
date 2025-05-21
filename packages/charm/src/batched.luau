local signals = require("./signals")

type ReactiveNode = signals.ReactiveNode

local startBatch = signals.startBatch
local endBatch = signals.endBatch

local function handleBatched(ok: boolean, ...)
	endBatch()
	if ok then
		return ...
	else
		error(...)
	end
end

local function batched<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	startBatch()
	return handleBatched(pcall(callback, ...))
end

return batched
