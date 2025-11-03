local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

type Setter<T = any> = (update: ((T) -> T) | T) -> ()

local trackedSetters: { [string]: Setter } = {}

--- Registers a map of setters to the state with the corresponding keys on the
--- server. When the server sends updates, these setters will be called with
--- the new values.
---
--- Atoms, signals converted to atoms, and signal setter functions are allowed.
--- Note that `server.addSignalsToClient` still requires some way to get the
--- state.
---
--- @param setters A map of setter functions to sync with the server.
local function addSignals(setters: { [string]: Setter })
	for key, setter in setters do
		trackedSetters[key] = setter
	end
end

--- Unregisters from server state updates for the given keys. The signals
--- will retain their current values, but will no longer receive updates
--- from the server.
local function removeSignals(...: string)
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		trackedSetters[key] = nil
	end
end

--- Unsubscribes from all server state updates.
local function removeAllSignals()
	table.clear(trackedSetters)
end

local function applyInitPayload(data: { [string]: any })
	for key, value in data do
		local setter = trackedSetters[key]
		if setter then
			setter(value)
		end
	end
end

local function applyPatchPayload(data: { [string]: any })
	for key, value in data do
		local setter = trackedSetters[key]
		if setter then
			setter(function(current)
				return patch.apply(current, value)
			end)
		end
	end
end

--- Merges the server's state patches into the client's state, either
--- initializing it with the full state or merging a partial patch.
---
--- @param payloads The state updates received from the server.
local function hydrate(payloads: { SyncPayload })
	for _, payload in payloads do
		if payload.type == "init" then
			Charm.batched(applyInitPayload, payload.data)
		elseif payload.type == "patch" then
			Charm.batched(applyPatchPayload, payload.data)
		end
	end
end

return {
	addSignals = addSignals,
	removeSignals = removeSignals,
	removeAllSignals = removeAllSignals,
	hydrate = hydrate,
}
