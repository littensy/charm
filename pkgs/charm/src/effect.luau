local signals = require("./signals")

local onEffectCleanup = signals.onEffectCleanup

type Cleanup = () -> ()

local function effect(callback: (dispose: () -> ()) -> ...Cleanup?): () -> ()
	local disposeImmediately = false

	local function dispose()
		disposeImmediately = true
	end

	dispose = signals.effect(function()
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
