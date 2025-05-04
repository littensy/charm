local effectScope = require("./effectScope")
local signals = require("./signals")

local effectImpl = signals.effect

local function effect(callback: (dispose: () -> ()) -> ...() -> ()?): () -> ()
	local disposed = false
	local dispose: () -> ()

	local function disposeSafe()
		disposed = true
		if dispose then
			dispose()
		end
	end

	dispose = effectScope(function()
		effectImpl(function()
			return callback(disposeSafe)
		end)
	end)

	if disposed then
		dispose()
	end

	return disposeSafe
end

return effect
