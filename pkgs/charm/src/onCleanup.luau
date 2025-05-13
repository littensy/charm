local signals = require("./signals")

local onEffectCleanup = signals.onEffectCleanup
local onScopeDispose = signals.onScopeDispose
local getCurrentScope = signals.getCurrentScope
local getCurrentSub = signals.getCurrentSub

local warn = warn or error :: never

local function onCleanup(cleanup: () -> (), failSilently: boolean?)
	if getCurrentSub() then
		onEffectCleanup(cleanup)
	elseif getCurrentScope() then
		onScopeDispose(cleanup)
	elseif _G.__DEV__ and not failSilently then
		warn(debug.traceback("onCleanup() can only be called inside an effect or a scope.", 2))
	end
end

return onCleanup
