local signals = require("./signals")

local startBatch = signals.startBatch
local endBatch = signals.endBatch

local function batched(callback: () -> ())
	startBatch()
	local success, result: any = pcall(callback)
	endBatch()

	if not success then
		error(result)
	end
end

return batched
