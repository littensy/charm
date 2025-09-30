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
	local patches: { any } = table.create(patchCount)

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

	local shouldSendInitialState = false
	local initPayload: { [string]: any } = {}
	local patchPayload: { [string]: any } = {}

	for key, status in syncedAtoms do
		local registeredAtom = atomRegister[key]

		if status == LISTENING_FOR_CHANGES then
			patchPayload[key] = patchData[key]
		elseif status == PENDING_INITIAL_STATE then
			initPayload[key] = registeredAtom.value
			syncedAtoms[key] = LISTENING_FOR_CHANGES
			shouldSendInitialState = true
		end
	end

	if shouldSendInitialState then
		table.insert(payloads, { type = "init", data = initPayload })
	end

	if next(patchPayload) ~= nil then
		table.insert(payloads, { type = "patch", data = patchPayload })
	end

	return payloads
end

--- @server
local function syncAtomsToClient(client: any, atoms: { [string]: () -> any })
	if not clientRegister[client] then
		clientRegister[client] = {}
	end

	local syncedAtoms = clientRegister[client]

	for key, atom in atoms do
		registerAtom(key, atom)

		if not syncedAtoms[key] then
			syncedAtoms[key] = PENDING_INITIAL_STATE
		end
	end
end

--- @server
local function unsyncClient(client: any)
	clientRegister[client] = nil
end

--- @server
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

--- @server
local function startSync(onSync: (client: any, payloads: { SyncPayload }) -> ())
	if connection then
		connection:Disconnect()
	end

	local elapsedTime = 0

	local function sync()
		local patches = if config.preserveHistory then createHistoricalPatches() else createPatch()

		if Charm.flags.frozen then
			Charm.deepFreeze(patches)
		end

		for client in clientRegister do
			local payloads: { SyncPayload } = if config.preserveHistory
				then createHistoricalPayloadsForClient(client, patches)
				else createPayloadsForClient(client, patches)

			if payloads[1] then
				task.spawn(onSync, client, payloads)
			end
		end

		unregisterUnusedAtoms()
		table.clear(globalUpdates)
	end

	connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime: number)
		elapsedTime += deltaTime

		if elapsedTime >= config.interval then
			elapsedTime %= config.interval

			debug.profilebegin("CharmSync")
			sync()
			debug.profileend()
		end
	end)
end

return {
	syncAtomsToClient = syncAtomsToClient,
	unsyncClient = unsyncClient,
	unsyncAtomsFromClient = unsyncAtomsFromClient,
	startSync = startSync,
}
