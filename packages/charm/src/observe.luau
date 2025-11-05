local core = require("./core")

type ReactiveNode = core.ReactiveNode

local batch = core.batch
local effect = core.effect
local effectScope = core.effectScope

--- Calls the callback function for each unique key in the table returned by the
--- getter. The callback is called once for each key, and again when a new key
--- is added.
---
--- The callback may return a cleanup function, which will be called when the
--- key is removed or the `observe()` effect is disposed. Effects created
--- during the callback will also be bound to the lifetime of the key.
---
--- @param getter A function that returns the table to observe.
--- @param callback A function that is called for each key in the table.
--- @return A function for disposing the observer.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
local function observe<K, V>(getter: () -> { [K]: V }, callback: (item: V, key: K) -> ...(() -> ())?): () -> ()
	local innerScopes: { [K]: () -> () } = {}

	local function updateScopes(data: { [K]: V })
		for key, dispose in innerScopes do
			if data[key] == nil then
				innerScopes[key] = nil
				dispose()
			end
		end

		for key, value in data do
			if innerScopes[key] == nil then
				-- Detach the inner scope from the parent effect to prevent
				-- disposing when the effect re-runs.
				innerScopes[key] = effectScope(function()
					return callback(value, key)
				end, true)
			end
		end
	end

	return effectScope(function()
		effect(function()
			-- Batch so that side effects run after all scopes are created. This
			-- ensures that a scope creating or removing items doesn't interfere
			-- with the current update cycle.
			batch(updateScopes, getter())

			-- Effects can't trigger themselves more than once, so if a scope
			-- creates or removes items, we need to check for updates again. The
			-- way we do this abuses a weird property of signal accesses that
			-- causes the effect to re-run.
			getter()
		end)

		return function()
			for _, dispose in innerScopes do
				dispose()
			end
			table.clear(innerScopes)
		end
	end)
end

return observe
