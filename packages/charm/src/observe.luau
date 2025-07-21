local core = require("./core")

local effect = core.effect
local effectScope = core.effectScope
local onCleanup = core.onCleanup

local function observe<K, V>(selector: () -> { [K]: V }, observer: (item: V, key: K) -> ...(() -> ())?): () -> ()
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
			if previousItems[key] == nil then
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
		currentItems = selector()
		if currentItems ~= previousItems then
			updateScopes(currentItems, previousItems)
		end
	end)

	onCleanup(disposeScopes, true)

	return function()
		disposeEffect()
		disposeScopes()
	end
end

return observe
