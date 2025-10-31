local core = require("./core")
local globals = require("./globals")

local batched = core.batched
local effect = core.effect
local effectScope = core.effectScope
local onCleanup = core.onCleanup

--- Calls the observer function for each unique key in the table returned by the
--- getter. The observer is called once for each key, and again when a new key
--- is added.
---
--- The observer may return a cleanup function, which will be called when the
--- key is removed or when the entire observer is disposed.
---
--- @param getter A function that returns the table to observe.
--- @param observer A function that is called for each key in the table.
--- @return A function for disposing the observer.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-observer
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
			batched(updateScopes, currentItems, previousItems)
		end
	end)

	if globals.trackInnerEffects then
		onCleanup(disposeScopes, true)
	end

	return function()
		disposeEffect()
		disposeScopes()
	end
end

return observe
