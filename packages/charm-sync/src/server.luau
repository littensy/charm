local Charm = require("../Charm")
local config = require("./config")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

type RegisteredAtom<T = any> = {
	atom: () -> T,
	value: T,
	valueLastSynced: T,
	stop: () -> (),
}

type SyncStatus = number

local PENDING_INITIAL_STATE: SyncStatus = 0
local LISTENING_FOR_CHANGES: SyncStatus = 1

local atomRegister: { [string]: RegisteredAtom } = {}
local clientRegister: { [any]: { [string]: SyncStatus } } = {}
local globalUpdates: { { key: string, value: any, previousValue: any } } = {}

local connection: RBXScriptConnection?
local onSyncCallback: (client: any, payloads: { SyncPayload }) -> ()?

local function registerAtom<T>(key: string, atom: () -> T)
	if atomRegister[key] then
		if atomRegister[key].atom ~= atom then
			warn("[Charm] Attempted to sync different atoms with the same key:", key)
		end
		return
	end

	local registeredAtom: RegisteredAtom<T> = {
		atom = atom,
		value = atom(),
		valueLastSynced = atom(),
		stop = function() end,
	}

	registeredAtom.stop = Charm.effect(function()
		local value = atom()

		-- When preserving history, we need to keep track of previous values
		-- so we can create granular patches for each change.
		if config.preserveHistory and registeredAtom.value ~= value then
			table.insert(globalUpdates, {
				key = key,
				value = value,
				previousValue = registeredAtom.value,
			})
		end

		registeredAtom.value = value
	end)

	atomRegister[key] = registeredAtom
end

local function unregisterAtom(key: string)
	local registeredAtom = atomRegister[key]

	if registeredAtom then
		registeredAtom.stop()
		atomRegister[key] = nil
	end
end

local function unregisterUnusedAtoms()
	local used: { [string]: boolean } = {}

	for _, clientAtoms in clientRegister do
		for key in clientAtoms do
			used[key] = true
		end
	end

	for key in atomRegister do
		if not used[key] then
			unregisterAtom(key)
		end
	end
end

local function createHistoricalPatches(): { any }
	local patchCount = #globalUpdates
	local patches = table.create(patchCount)

	for index, update in globalUpdates do
		patches[index] = patch.diff(update.previousValue, update.value)
	end

	return patches
end

local function createHistoricalPayloadsForClient(client: any, patches: { any }): { SyncPayload }
	local syncedAtoms = clientRegister[client]

	if not syncedAtoms then
		return {}
	end

	local payloads: { SyncPayload } = {}

	-- Iterate over all global updates and see if the client is interested in
	-- any of them. If so, we create a patch payload for the update.
	for index, update in globalUpdates do
		local patchData = patches[index]

		if not patchData then
			continue
		end

		local key = update.key
		local status = syncedAtoms[key]

		if status == LISTENING_FOR_CHANGES then
			table.insert(payloads, {
				type = "patch",
				data = { [key] = patchData },
			})
		elseif status == PENDING_INITIAL_STATE then
			table.insert(payloads, {
				type = "init",
				data = { [key] = update.value },
			})

			syncedAtoms[key] = LISTENING_FOR_CHANGES
		end
	end

	-- If a pending atom was never updated, we still need to send its initial
	-- state. This can happen if the atom was registered after its last change.
	local initPayload: { [string]: any } = {}

	for key, status in syncedAtoms do
		local registeredAtom = atomRegister[key]

		if status == PENDING_INITIAL_STATE and registeredAtom then
			initPayload[key] = registeredAtom.value
			syncedAtoms[key] = LISTENING_FOR_CHANGES
		end
	end

	if next(initPayload) ~= nil then
		table.insert(payloads, 1, { type = "init" :: "init", data = initPayload })
	end

	return payloads
end

local function createPatch(): any
	local current: { [string]: any } = {}
	local previous: { [string]: any } = {}

	for key, registeredAtom in atomRegister do
		current[key] = registeredAtom.value
		previous[key] = registeredAtom.valueLastSynced
		registeredAtom.valueLastSynced = registeredAtom.value
	end

	return patch.diff(previous, current)
end

local function createPayloadsForClient(client: any, patchData: any): { SyncPayload }
	local syncedAtoms = clientRegister[client]
	local payloads: { SyncPayload } = {}

	if not syncedAtoms then
		return payloads
	end

	local initPayload: { [string]: any } = {}
	local patchPayload: { [string]: any } = {}

	-- Create patches for initialized atoms that changed, and add atoms that
	-- are still pending initial state to the init payload.
	for key, status in syncedAtoms do
		local registeredAtom = atomRegister[key]

		if status == LISTENING_FOR_CHANGES then
			patchPayload[key] = patchData[key]
		elseif status == PENDING_INITIAL_STATE then
			initPayload[key] = registeredAtom.value
			syncedAtoms[key] = LISTENING_FOR_CHANGES
		end
	end

	if next(initPayload) ~= nil then
		table.insert(payloads, { type = "init", data = initPayload })
	end

	if next(patchPayload) ~= nil then
		table.insert(payloads, { type = "patch", data = patchPayload })
	end

	return payloads
end

--- Registers atoms to be kept in sync with a specific client. Should be
--- called when a player joins the game to start syncing atoms to them. Call
--- `unsyncAtomsFromClient` or `unsyncClient` to stop syncing.
---
--- Each atom should be assigned a unique key, allowing the server to re-use
--- patches between multiple clients.
---
--- @param client The player to sync atoms to.
--- @param atoms An object mapping string keys to atoms to be synced.
local function syncAtomsToClient(client: any, atoms: { [string]: () -> any })
	if not clientRegister[client] then
		clientRegister[client] = {}
	end

	local syncedAtoms = clientRegister[client]

	for key, atom in atoms do
		registerAtom(key, atom)

		if not syncedAtoms[key] then
			-- Mark the atom as pending initial state so we send its full value
			-- the next time we sync.
			syncedAtoms[key] = PENDING_INITIAL_STATE
		end
	end
end

--- Unregisters all atoms from being kept in sync with a specific client.
--- Should be called when a player leaves the game.
---
--- @param client The player to stop syncing atoms to.
local function unsyncClient(client: any)
	clientRegister[client] = nil
end

--- Unregisters one or more atoms from being kept in sync with a specific
--- client.
---
--- @param client The player to stop syncing atoms to.
--- @param keys The keys of the atoms to stop syncing.
local function unsyncAtomsFromClient(client: any, ...: string)
	local syncedAtoms = clientRegister[client]

	if not syncedAtoms then
		return
	end

	for index = 1, select("#", ...) do
		local key = select(index, ...)
		syncedAtoms[key] = nil
	end

	if next(syncedAtoms) == nil then
		clientRegister[client] = nil
	end
end

--- Immediately sends pending updates and initial states to all clients.
--- Normally, updates are sent at the interval specified in `config.interval`.
--- Calling this function forces all pending updates to be sent immediately.
local function flush()
	if not onSyncCallback then
		return
	end

	local patches = if config.preserveHistory then createHistoricalPatches() else createPatch()

	-- While payload objects are technically mutable as they are unique to
	-- each client, the data inside them is not safe to mutate.
	if Charm.flags.frozen then
		Charm.deepFreeze(patches)
	end

	for client in clientRegister do
		local payloads: { SyncPayload } = if config.preserveHistory
			then createHistoricalPayloadsForClient(client, patches)
			else createPayloadsForClient(client, patches)

		if payloads[1] then
			if task then
				task.spawn(onSyncCallback, client, payloads)
			else
				onSyncCallback(client, payloads)
			end
		end
	end

	unregisterUnusedAtoms()
	table.clear(globalUpdates)
end

--- Stops automatically syncing registered atoms to clients. Patches will
--- no longer be sent to clients until `startSync` is called again.
local function stopSync()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

--- Unregisters all atoms from being kept in sync with all clients, and
--- stops automatic syncing.
local function reset()
	table.clear(atomRegister)
	table.clear(clientRegister)
	table.clear(globalUpdates)
	stopSync()
end

--- Starts automatically syncing registered atoms to clients. Patches will
--- be sent to clients whenever the atoms are updated.
---
--- @param onSync The function to call when patches can be sent to a client.
--- @return `stopSync()`
local function startSync(onSync: (client: any, payloads: { SyncPayload }) -> ()): () -> ()
	if connection then
		connection:Disconnect()
	end

	onSyncCallback = onSync

	if not game then
		return stopSync
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

	return stopSync
end

return {
	syncAtomsToClient = syncAtomsToClient,
	unsyncClient = unsyncClient,
	unsyncAtomsFromClient = unsyncAtomsFromClient,
	startSync = startSync,
	stopSync = stopSync,
	flush = flush,
	reset = reset,
}
