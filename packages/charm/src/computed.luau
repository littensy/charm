local signals = require("./signals")

local computedImpl = signals.computed

local function computed<T>(selector: (previous: T?) -> T): () -> T
	local getter = computedImpl(selector)

	return function()
		return getter()
	end
end

return computed
