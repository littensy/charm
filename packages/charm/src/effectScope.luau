local signals = require("./signals")

local effectScopeImpl = signals.effectScope

local function effectScope(callback: () -> ...() -> ()?): () -> ()
	local dispose = effectScopeImpl(callback)

	return function()
		dispose()
	end
end

return effectScope
