local Charm = require("../Charm")
local patch = require("./patch")
local types = require("./types")

type SyncPayload = types.SyncPayload

local atomRegister: { [string]: Charm.Atom } = {}

local function syncAtoms(atoms: { [string]: Charm.Atom })
	for key, atom in atoms do
		if atomRegister[key] and atomRegister[key] ~= atom then
			warn("[Charm] Attempted to sync different atoms with the same key:", key)
			continue
		end

		atomRegister[key] = atom
	end
end

local function unsyncAtoms(...: string)
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		atomRegister[key] = nil
	end
end

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
