local Charm = require("../Charm")
local config = require("./config")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

local globals = Charm.globals

type SyncStatus = number

type ClientAtoms = {
	[string]: SyncStatus,
}

type TrackedState<T = any> = {
	getter: () -> T,
	currentValue: T,
	previousValue: T,
	dispose: () -> (),
}

type StateUpdate = {
	key: string,
	currentValue: any,
	previousValue: any,
}

local PENDING_INITIAL_STATE: SyncStatus = 0
local LISTENING_FOR_CHANGES: SyncStatus = 1

local trackedAtoms: { [string]: TrackedState } = {}
local globalUpdates: { StateUpdate } = {}
local clients: { [any]: ClientAtoms } = {}

local connection: RBXScriptConnection?
local syncCallback: (client: any, payloads: { SyncPayload }) -> ()?

local function startTracking<T>(key: string, getter: () -> T)
	if trackedAtoms[key] then
		-- Ignore duplicates, but warn against name collisions
		if trackedAtoms[key].getter ~= getter then
			warn("[Charm] Attempted to sync different states with the same key:", key)
		end
		return
	end

	local value = getter()
	local trackedState = {
		getter = getter,
		currentValue = value,
		previousValue = value,
	}

	trackedState.dispose = Charm.effect(function()
		local newValue = getter()

		-- When preserving history, we need to keep track of previous values
		-- so we can create granular patches for each change.
		if config.preserveHistory and trackedState.currentValue ~= newValue then
			table.insert(globalUpdates, {
				key = key,
				currentValue = newValue,
				previousValue = trackedState.previousValue,
			})
		end

		trackedState.currentValue = newValue
	end)

	trackedAtoms[key] = trackedState
end

local function stopTracking(key: string)
	local tracker = trackedAtoms[key]
	if tracker then
		tracker.dispose()
		trackedAtoms[key] = nil
	end
end

local function purgeUntracked()
	local active: { [string]: boolean } = {}

	for _, clientAtoms in clients do
		for key in clientAtoms do
			active[key] = true
		end
	end

	for key in trackedAtoms do
		if not active[key] then
			stopTracking(key)
		end
	end
end

local function diffGlobalUpdateBuffer(): { any }
	local patchCount = #globalUpdates
	local patches = table.create(patchCount)

	for index, update in globalUpdates do
		patches[index] = patch.diff(update.previousValue, update.currentValue)
	end

	return patches
end

local function selectFromGlobalPatchList(client: any, globalPatches: { any }): { SyncPayload }
	local clientAtoms = clients[client]

	if not clientAtoms then
		return {}
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
		local status = clientAtoms[key]

		if status == LISTENING_FOR_CHANGES then
			table.insert(payloads, {
				type = "patch",
				data = { [key] = patchData },
			})
		elseif status == PENDING_INITIAL_STATE then
			table.insert(payloads, {
				type = "init",
				data = { [key] = update.currentValue },
			})
			clientAtoms[key] = LISTENING_FOR_CHANGES
		end
	end

	-- If a pending atom was never updated, we still need to send its initial
	-- state. This can happen if the atom was registered after its last change.
	local initData: { [string]: any } = {}

	for key, status in clientAtoms do
		local trackedState = trackedAtoms[key]

		if status == PENDING_INITIAL_STATE and trackedState then
			initData[key] = trackedState.currentValue
			clientAtoms[key] = LISTENING_FOR_CHANGES
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

	for key, tracker in trackedAtoms do
		currentGlobalState[key] = tracker.currentValue
		previousGlobalState[key] = tracker.previousValue
		tracker.previousValue = tracker.currentValue
	end

	return patch.diff(previousGlobalState, currentGlobalState)
end

local function selectFromGlobalPatch(client: any, globalPatch: any): { SyncPayload }
	local clientAtoms = clients[client]

	if not clientAtoms then
		return {}
	end

	local payloads: { SyncPayload } = {}
	local initData: { [string]: any } = {}
	local patchData: { [string]: any } = {}

	-- Create patches for initialized atoms that changed, and add atoms that
	-- are still pending initial state to the init payload.
	for key, status in clientAtoms do
		local trackedState = trackedAtoms[key]

		if status == LISTENING_FOR_CHANGES then
			patchData[key] = globalPatch[key]
		elseif status == PENDING_INITIAL_STATE then
			initData[key] = trackedState.currentValue
			clientAtoms[key] = LISTENING_FOR_CHANGES
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

--- Subscribes a client to the given atoms. When an update occurs, the client
--- will receive a partial state patch to merge into their local state. May be
--- called multiple times to subscribe to additional keys.
---
--- Atoms, signals converted to atoms, and signal getter functions are allowed.
--- Note that the client still requires some way to set the state, so
--- registering signals on the client should be done through `signalToAtom()`.
---
--- @param client The client receiving state updates.
--- @param atoms A map of atoms to sync with the client.
local function subscribeClient(client: any, atoms: { [string]: () -> any })
	if not clients[client] then
		clients[client] = {}
	end

	local clientAtoms = clients[client]

	for key, state in atoms do
		startTracking(key, if type(state) == "function" then state else state.get)

		if not clientAtoms[key] then
			-- Mark the atom as pending initial state so we send its full value
			-- the next time we sync.
			clientAtoms[key] = PENDING_INITIAL_STATE
		end
	end
end

--- Unsubscribes a client from receiving all state updates. To only unsubscribe
--- from specific keys, use `unsubscribeClientFrom` instead.
---
--- @param client The client receiving state updates.
local function unsubscribeClient(client: any)
	clients[client] = nil
end

--- Unsubscribes a client from receiving updates for the given keys.
---
--- @param client The client receiving state updates.
--- @param keys The keys of the state to unsubscribe from.
local function unsubscribeClientFrom(client: any, ...: string)
	local clientAtoms = clients[client]

	if not clientAtoms then
		return
	end

	for index = 1, select("#", ...) do
		local key = select(index, ...)
		clientAtoms[key] = nil
	end

	if next(clientAtoms) == nil then
		clients[client] = nil
	end
end

--- Immediately sends pending updates to all clients. Normally, updates are
--- sent at the interval specified in `config.interval`, but this function
--- can be used to force an immediate sync.
local function flush()
	if not syncCallback then
		return
	end

	local globalPatch = if config.preserveHistory then diffGlobalUpdateBuffer() else diffGlobalState()

	-- While payload objects are technically mutable as they are unique to
	-- each client, the data inside them is not safe to mutate.
	if globals.frozen then
		Charm.deepFreeze(globalPatch)
	end

	for client in clients do
		local payloads: { SyncPayload } = if config.preserveHistory
			then selectFromGlobalPatchList(client, globalPatch)
			else selectFromGlobalPatch(client, globalPatch)

		if payloads[1] then
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
	table.clear(trackedAtoms)
	table.clear(clients)
	table.clear(globalUpdates)
	disconnect()
end

return {
	subscribeClient = subscribeClient,
	unsubscribeClient = unsubscribeClient,
	unsubscribeClientFrom = unsubscribeClientFrom,
	connect = connect,
	disconnect = disconnect,
	flush = flush,
	reset = reset,
}
