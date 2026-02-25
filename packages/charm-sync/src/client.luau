local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload
type ReactiveProxy<T = {}> = types.ReactiveProxy<T>

local trackedSignals: { [string]: (any) -> any } = {}
local trackedReactives: { [string]: ReactiveProxy } = {}

local function shallowMergeReactive(reactive: ReactiveProxy, source: { [any]: any })
	local target = reactive.__target
	for key, value in source do
		target[key] = value
	end
	Charm.trigger(reactive.__track)
end

--[[
	Registers a map of setters to the state with the corresponding keys on the
	server. When the server sends updates, these setters will be called with
	the new values.

	Atoms, signals converted to atoms, and signal setter functions are allowed.
	Note that `server.addSignalsToClient` still requires some way to get the
	state.

	@param signals A map of setter functions to sync with the server.
]]
local function addSignals(signals: { [string]: ((any) -> any) | {} })
	for key, signal in signals do
		if type(signal) == "function" then
			trackedSignals[key] = signal
		else
			trackedReactives[key] = (signal :: any) :: ReactiveProxy
		end
	end
end

--[[
	Unregisters from server state updates for the given keys. The signals
	will retain their current values, but will no longer receive updates
	from the server.
]]
local function removeSignals(...: string)
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		trackedSignals[key] = nil
		trackedReactives[key] = nil
	end
end

--[[
	Unsubscribes from all server state updates.
]]
local function removeAllSignals()
	table.clear(trackedSignals)
	table.clear(trackedReactives)
end

local function applyInitPayload(data: { [string]: any })
	for key, value in data do
		if trackedSignals[key] then
			trackedSignals[key](value)
		elseif trackedReactives[key] then
			shallowMergeReactive(trackedReactives[key], value)
		end
	end
end

local function applyPatchPayload(data: { [string]: any })
	for key, diffs in data do
		local trackedSignal = trackedSignals[key]
		local trackedReactive = trackedReactives[key]

		if trackedSignal then
			trackedSignal(function(value)
				return patch.apply(value, diffs)
			end)
		elseif trackedReactive then
			patch.applyMutable(trackedReactive.__target, diffs)
			Charm.trigger(trackedReactive.__track)
		end
	end
end

--[[
	Merges the server's state patches into the client's state, either
	initializing it with the full state or merging a partial patch.

	@param payloads The state updates received from the server.
]]
local function patch(payloads: { SyncPayload })
	for _, payload in payloads do
		if payload.type == "init" then
			Charm.batch(applyInitPayload, payload.data)
		elseif payload.type == "patch" then
			Charm.batch(applyPatchPayload, payload.data)
		end
	end
end

return {
	addSignals = addSignals,
	removeSignals = removeSignals,
	removeAllSignals = removeAllSignals,
	patch = patch,
}
