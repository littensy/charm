local signals = require("./signals")

local onEffectCleanup = signals.onEffectCleanup

local function effect(callback: (dispose: () -> ()) -> ...(() -> ())?): () -> ()
	local disposed = false

	local function dispose()
		disposed = true
	end

	dispose = signals.effect(function()
		local cleanup = callback(dispose)
		if cleanup then
			onEffectCleanup(cleanup)
		end
	end)

	if disposed then
		dispose()
	end

	return dispose
end

return effect
