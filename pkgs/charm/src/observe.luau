local signals = require("./signals")

local effect = signals.effect
local effectScope = signals.effectScope
local onEffectCleanup = signals.onEffectCleanup
local onScopeDispose = signals.onScopeDispose
local getCurrentSub = signals.getCurrentSub

local function observe<K, V>(selector: () -> { [K]: V }, observer: (item: V, key: K) -> ...(() -> ())?): () -> ()
	local scopes: { [K]: () -> () } = {}
	local currentItems: { [K]: V } = {}

	local function updateScopes(currentItems: { [K]: V }, previousItems: { [K]: V })
		for key in previousItems do
			if currentItems[key] == nil and scopes[key] then
				scopes[key]()
				scopes[key] = nil
			end
		end

		for key, value in currentItems do
			if previousItems[key] == nil then
				scopes[key] = effectScope(function()
					local cleanup = observer(value, key)
					if cleanup then
						onScopeDispose(cleanup)
					end
				end, true)
			end
		end
	end

	local function disposeScopes()
		for _, dispose in scopes do
			dispose()
		end
		table.clear(scopes)
	end

	local disposeEffect = effect(function()
		local previousItems = currentItems
		currentItems = selector()

		if currentItems ~= previousItems then
			updateScopes(currentItems, previousItems)
		end
	end)

	if getCurrentSub() then
		onEffectCleanup(disposeScopes)
	else
		onScopeDispose(disposeScopes)
	end

	return function()
		disposeEffect()
		disposeScopes()
	end
end

return observe
