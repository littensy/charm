local signals = require("./signals")

local _effectScope = signals.effectScope
local onScopeDispose = signals.onScopeDispose

local function effectScope(callback: () -> ...() -> ()?, detached: boolean?): () -> ()
	return _effectScope(function()
		local cleanup = callback()
		if cleanup then
			onScopeDispose(cleanup)
		end
	end, detached)
end

return effectScope
