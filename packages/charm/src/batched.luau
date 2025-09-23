local core = require("./core")
local flags = require("./flags")
local utils = require("./utils")

local startBatch = core.startBatch
local endBatch = core.endBatch
local noYield = utils.noYield

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
	return handleBatched((if flags.strict then noYield else pcall)(callback, ...))
end

return batched
