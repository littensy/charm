local signals = require("./signals")

local onScopeDispose = signals.onScopeDispose

local function effectScope(callback: () -> ...(() -> ())?, detached: boolean?): () -> ()
	return signals.effectScope(function()
		local cleanup = callback()
		if cleanup then
			onScopeDispose(cleanup)
		end
	end, detached)
end

return effectScope
