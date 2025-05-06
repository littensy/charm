local signals = require("./signals")

local effect = signals.effect
local effectScope = signals.effectScope
local getCurrentSub = signals.getCurrentSub
local onEffectCleanup = signals.onEffectCleanup
local onScopeDispose = signals.onScopeDispose
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function observe<K, V>(selector: () -> { [K]: V }, observer: (item: V, key: K) -> ...() -> ()?): () -> ()
	local scopes: { [K]: () -> () } = {}
	local currentItems: { [K]: V } = {}

	local function update(currentItems: { [K]: V }, previousItems: { [K]: V })
		for key in previousItems do
			if currentItems[key] == nil then
				local dispose = scopes[key]
				scopes[key] = nil
				dispose()
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
		local nextItems = selector()

		if nextItems ~= currentItems then
			local previousItems = currentItems
			currentItems = nextItems

			pauseTracking()
			local success, result: unknown = pcall(update, currentItems, previousItems)
			resumeTracking()

			if not success then
				error(`observe() encountered an error: {result}`, 2)
			end
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
