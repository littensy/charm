local core = require("./core")

local effect = core.effect
local effectScope = core.effectScope
local onCleanup = core.onCleanup
local startBatch = core.startBatch
local endBatch = core.endBatch

local function observe<K, V>(getter: () -> { [K]: V }, observer: (item: V, key: K) -> ...(() -> ())?): () -> ()
	local scopes: { [K]: () -> () } = {}
	local currentItems: { [K]: V } = {}

	local function updateScopes(currentItems: { [K]: V }, previousItems: { [K]: V })
		for key in previousItems do
			local dispose = scopes[key]
			if currentItems[key] == nil and dispose then
				dispose()
				scopes[key] = nil
			end
		end

		for key, value in currentItems do
			if previousItems[key] == nil and scopes[key] == nil then
				scopes[key] = effectScope(function()
					return observer(value, key)
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
		currentItems = getter()
		if currentItems ~= previousItems then
			startBatch()
			updateScopes(currentItems, previousItems)
			endBatch()
		end
	end)

	onCleanup(disposeScopes, true)

	return function()
		disposeEffect()
		disposeScopes()
	end
end

return observe
