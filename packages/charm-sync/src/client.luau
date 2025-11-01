local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type Atom<T = any> = Charm.Atom<T>
type SyncPayload = types.SyncPayload

local trackedAtoms: { [string]: Atom } = {}

--- Registers a map of atoms to the state with the corresponding keys on the
--- server. When the server sends updates, these atoms will be hydrated with
--- the new values.
---
--- If syncing signals instead of atoms, you can use `signalToAtom` to sync
--- signal getters and setters.
---
--- @param atoms A map of atoms to sync with the server.
local function register(atoms: { [string]: Atom })
	for key, atom in atoms do
		trackedAtoms[key] = atom
	end
end

--- Unregisters from server state updates for the given keys. The atoms
--- will retain their current values, but will no longer receive updates
--- from the server.
local function unregister(...: string)
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		trackedAtoms[key] = nil
	end
end

--- Unsubscribes from all server state updates.
local function reset()
	table.clear(trackedAtoms)
end

local function applyInitPayload(data: { [string]: any })
	for key, value in data do
		local atom = trackedAtoms[key]
		if atom then
			atom(value)
		end
	end
end

local function applyPatchPayload(data: { [string | number]: any })
	local target = {}

	for key, atom in trackedAtoms do
		target[key] = atom()
	end

	target = patch.apply(target, data)

	for key, atom in trackedAtoms do
		atom(target[key])
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
	register = register,
	unregister = unregister,
	reset = reset,
	hydrate = hydrate,
}
