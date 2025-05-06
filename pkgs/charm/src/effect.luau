local signals = require("./signals")

local _effect = signals.effect
local onEffectCleanup = signals.onEffectCleanup

local function effect(callback: (dispose: () -> ()) -> ...() -> ()?): () -> ()
	local disposeImmediately = false

	local function dispose()
		disposeImmediately = true
	end

	dispose = _effect(function()
		local cleanup = callback(dispose)
		if cleanup then
			onEffectCleanup(cleanup)
		end
	end)

	if disposeImmediately then
		dispose()
	end

	return dispose
end

return effect
