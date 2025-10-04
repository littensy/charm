local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

local atomRegister: { [string]: Charm.Atom } = {}

--- Registers atoms to be kept in sync with the server. Atoms with matching
--- keys on the server will be synced to these atoms.
---
--- @param atoms An object mapping string keys to atoms to be synced.
local function syncAtoms(atoms: { [string]: Charm.Atom })
	for key, atom in atoms do
		if atomRegister[key] and atomRegister[key] ~= atom then
			warn("[Charm] Attempted to sync different atoms with the same key:", key)
			continue
		end

		atomRegister[key] = atom
	end
end

--- Unregisters one or more atoms from being kept in sync with the server.
--- The atoms will retain their current values, but will no longer receive
--- updates from the server.
---
--- @param keys The keys of the atoms to stop syncing.
local function unsyncAtoms(...: string)
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		atomRegister[key] = nil
	end
end

--- Unregisters all atoms from being kept in sync with the server. The
--- atoms will retain their current values, but will no longer receive
--- updates from the server.
local function reset()
	table.clear(atomRegister)
end

local function applyInitPayload(data: { [string]: any })
	for key, value in data do
		local atom = atomRegister[key]
		if atom then
			atom(value)
		end
	end
end

local function applyPatchPayload(data: { [string | number]: any })
	local target = {}

	for key, atom in atomRegister do
		target[key] = atom()
	end

	target = patch.apply(target, data)

	for key, atom in atomRegister do
		atom(target[key])
	end
end

--- Applies one or more payloads received from the server to the synced
--- atoms. Payloads are state patches or initial state updates sent by the
--- server, and are usually received via a remote event.
---
--- @param payloads The payloads to apply.
local function applyPayloads(payloads: { SyncPayload })
	for _, payload in payloads do
		if payload.type == "init" then
			Charm.batched(applyInitPayload, payload.data)
		elseif payload.type == "patch" then
			Charm.batched(applyPatchPayload, payload.data)
		end
	end
end

return {
	syncAtoms = syncAtoms,
	unsyncAtoms = unsyncAtoms,
	reset = reset,
	applyPayloads = applyPayloads,
}
