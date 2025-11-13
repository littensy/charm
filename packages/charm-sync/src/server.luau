local Charm = require("../Charm")
local config = require("./config")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

type SyncStatus = number

type ClientKeys = { [string]: SyncStatus }

type GetterState<T = any> = {
	getter: () -> T,
	currentValue: T,
	lastSyncedValue: T,
	dispose: () -> (),
}

type StateUpdate = {
	key: string,
	newValue: any,
	oldValue: any,
}

local PENDING_INITIAL_STATE: SyncStatus = 0
local LISTENING_FOR_CHANGES: SyncStatus = 1

local trackedGetters: { [string]: GetterState } = {}
local globalUpdates: { StateUpdate } = {}
local clients: { [any]: ClientKeys } = {}

local connection: RBXScriptConnection?
local syncCallback: (client: any, payloads: { SyncPayload }) -> ()?

local function startTracking<T>(key: string, getter: () -> T)
	if trackedGetters[key] then
		-- Ignore duplicates, but warn against name collisions
		if trackedGetters[key].getter ~= getter then
			warn("[Charm] Attempted to sync different states with the same key:", key)
		end
		return
	end

	local value = getter()
	local trackedState = {
		getter = getter,
		currentValue = value,
		lastSyncedValue = value,
	}

	trackedState.dispose = Charm.subscribe(getter, function(newValue, oldValue)
		-- When preserving history, we need to keep track of previous values
		-- so we can create granular patches for each change.
		if config.preserveHistory then
			table.insert(globalUpdates, {
				key = key,
				newValue = newValue,
				oldValue = oldValue,
			})
		end
		trackedState.currentValue = newValue
	end)

	trackedGetters[key] = trackedState
end

local function stopTracking(key: string)
	local trackedState = trackedGetters[key]
	if trackedState then
		trackedState.dispose()
		trackedGetters[key] = nil
	end
end

local function purgeUntracked()
	local active: { [string]: boolean } = {}

	for _, clientKeys in clients do
		for key in clientKeys do
			active[key] = true
		end
	end

	for key in trackedGetters do
		if not active[key] then
			stopTracking(key)
		end
	end
end

local function diffGlobalUpdateBuffer(): { any }
	local patchCount = #globalUpdates
	local patches = table.create(patchCount)

	for index, update in globalUpdates do
		patches[index] = patch.diff(update.oldValue, update.newValue)
	end

	return patches
end

local function selectFromGlobalPatchList(client: any, globalPatches: { any }): { SyncPayload }?
	local clientKeys = clients[client]

	if not clientKeys then
		return nil
	end

	local payloads: { SyncPayload } = {}

	-- Iterate over all global updates and see if the client is interested in
	-- any of them. If so, we create a patch payload for the update.
	for index, update in globalUpdates do
		local patchData = globalPatches[index]

		if not patchData then
			continue
		end

		local key = update.key
		local status = clientKeys[key]

		if status == LISTENING_FOR_CHANGES then
			table.insert(payloads, {
				type = "patch",
				data = { [key] = patchData },
			})
		elseif status == PENDING_INITIAL_STATE then
			table.insert(payloads, {
				type = "init",
				data = { [key] = update.newValue },
			})
			clientKeys[key] = LISTENING_FOR_CHANGES
		end
	end

	-- If a pending signal was never updated, we still need to send its initial
	-- state. This can happen if a signal was registered after its last change.
	local initData: { [string]: any } = {}

	for key, status in clientKeys do
		local trackedState = trackedGetters[key]

		if status == PENDING_INITIAL_STATE and trackedState then
			initData[key] = trackedState.currentValue
			clientKeys[key] = LISTENING_FOR_CHANGES
		end
	end

	if next(initData) ~= nil then
		table.insert(payloads, 1, { type = "init" :: "init", data = initData })
	end

	return payloads
end

local function diffGlobalState(): any
	local currentGlobalState: { [string]: any } = {}
	local previousGlobalState: { [string]: any } = {}

	for key, trackedState in trackedGetters do
		currentGlobalState[key] = trackedState.currentValue
		previousGlobalState[key] = trackedState.lastSyncedValue
		trackedState.lastSyncedValue = trackedState.currentValue
	end

	return patch.diff(previousGlobalState, currentGlobalState)
end

local function selectFromGlobalPatch(client: any, globalPatch: any): { SyncPayload }?
	local clientKeys = clients[client]

	if not clientKeys then
		return nil
	end

	local payloads: { SyncPayload } = {}
	local initData: { [string]: any } = {}
	local patchData: { [string]: any } = {}

	-- Create patches for initialized signals that changed, and add signals
	-- that are still pending initial state to the init payload.
	for key, status in clientKeys do
		local trackedState = trackedGetters[key]

		if status == LISTENING_FOR_CHANGES then
			patchData[key] = globalPatch[key]
		elseif status == PENDING_INITIAL_STATE then
			initData[key] = trackedState.currentValue
			clientKeys[key] = LISTENING_FOR_CHANGES
		end
	end

	if next(initData) ~= nil then
		table.insert(payloads, { type = "init", data = initData })
	end

	if next(patchData) ~= nil then
		table.insert(payloads, { type = "patch", data = patchData })
	end

	return payloads
end

--- Subscribes a client to the given signals. When an update occurs, the client
--- will receive a partial state patch to merge into their local state. May be
--- called multiple times to subscribe to additional keys.
---
--- Atoms, signals converted to atoms, and signal getter functions are allowed.
--- Note that `client.addSignals` still requires some way to set the state.
---
--- @param client The client receiving state updates.
--- @param getters A map of getter functions to sync with the client.
local function addSignalsToClient(client: any, getters: { [string]: () -> any })
	if not clients[client] then
		clients[client] = {}
	end

	local clientKeys = clients[client]

	for key, getter in getters do
		startTracking(key, if type(getter) == "function" then getter else getter.get)

		if not clientKeys[key] then
			-- Mark the getter as pending initial state so we send its full
			-- value the next time we sync.
			clientKeys[key] = PENDING_INITIAL_STATE
		end
	end
end

--- Unsubscribes a client from receiving all state updates. To only unsubscribe
--- from specific keys, use `unsubscribeClientFrom` instead.
---
--- @param client The client receiving state updates.
local function removeClient(client: any)
	clients[client] = nil
end

--- Unsubscribes a client from receiving updates for the given keys.
---
--- @param client The client receiving state updates.
--- @param keys The keys of the state to unsubscribe from.
local function removeSignalsFromClient(client: any, ...: string)
	local clientKeys = clients[client]

	if not clientKeys then
		return
	end

	for index = 1, select("#", ...) do
		local key = select(index, ...)
		clientKeys[key] = nil
	end

	if next(clientKeys) == nil then
		removeClient(client)
	end
end

--- Immediately sends pending updates to all clients. Normally, updates are
--- sent at the interval specified in `config.interval`, but this function
--- can be used to force an immediate sync.
local function flush()
	if not syncCallback then
		return
	end

	local granular = config.preserveHistory
	local globalPatch = if granular then diffGlobalUpdateBuffer() else diffGlobalState()

	for client in clients do
		local payloads = if granular
			then selectFromGlobalPatchList(client, globalPatch)
			else selectFromGlobalPatch(client, globalPatch)

		if payloads and payloads[1] then
			if task then
				task.spawn(syncCallback, client, payloads)
			else
				syncCallback(client, payloads)
			end
		end
	end

	purgeUntracked()
	table.clear(globalUpdates)
end

--- Uses the callback to send state updates to clients that are subscribed
--- to state changes. Starts automatically sending updates at the interval
--- specified in `config.interval`.
---
--- @param onSync Called when sending patches to a client.
local function connect(onSync: (client: any, payloads: { SyncPayload }) -> ())
	if connection then
		connection:Disconnect()
	end

	syncCallback = onSync

	if not game then
		return
	end

	local timer = 0

	connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
		if config.interval < 0 then
			return
		end

		timer += deltaTime

		if timer >= config.interval then
			timer = 0
			debug.profilebegin("CharmSync")
			flush()
			debug.profileend()
		end
	end)
end

--- Stops syncing state updates to clients at the automatic interval.
--- Flushing can still be performed manually via `flush`.
local function disconnect()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

--- Unsubscribes all clients, stops tracking all state, and disconnects
--- from the automatic sync interval.
local function reset()
	table.clear(trackedGetters)
	table.clear(clients)
	table.clear(globalUpdates)
	disconnect()
end

return {
	addSignalsToClient = addSignalsToClient,
	removeClient = removeClient,
	removeSignalsFromClient = removeSignalsFromClient,
	connect = connect,
	disconnect = disconnect,
	flush = flush,
	reset = reset,
}
