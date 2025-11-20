local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type ReactiveProxy<T = {}> = Charm.ReactiveProxy<T>
type SyncPayload = types.SyncPayload

type SignalSetter<T = any> = (T | (T) -> T) -> ()
type ReactiveSetter<T = any> = (T | (T) -> ()) -> ()

local trackedSignals: { [string]: SignalSetter } = {}
local trackedReactives: { [string]: ReactiveSetter } = {}

--[[
	Registers a map of setters to the state with the corresponding keys on the
	server. When the server sends updates, these setters will be called with
	the new values.

	Atoms, signals converted to atoms, and signal setter functions are allowed.
	Note that `server.addSignalsToClient` still requires some way to get the
	state.

	@param signals A map of setter functions to sync with the server.
]]
local function addSignals(signals: { [string]: SignalSetter | {} })
	for key, signal in signals do
		if type(signal) == "function" then
			trackedSignals[key] = signal
		else
			trackedReactives[key] = getmetatable(signal :: ReactiveProxy).set
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
		local trackedSignal: SignalSetter? = trackedSignals[key] or trackedReactives[key]
		if trackedSignal then
			trackedSignal(value)
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
			trackedReactive(function(value)
				patch.applyMutable(value, diffs)
			end)
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
