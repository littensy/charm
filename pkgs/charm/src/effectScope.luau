local signals = require("./signals")

local onScopeDispose = signals.onScopeDispose

type Cleanup = () -> ()

local function effectScope(callback: () -> ...Cleanup?, detached: boolean?): () -> ()
	return signals.effectScope(function()
		local cleanup = callback()
		if cleanup then
			onScopeDispose(cleanup)
		end
	end, detached)
end

return effectScope
