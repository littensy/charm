local atom = require(script.Parent.Parent.atom)
type Atom<T> = atom.Atom<T>
local patch = require(script.Parent.patch)
local types = require(script.Parent.types)

type ClientSyncOptions = {
	atoms: { [string]: Atom<any> },
}

type ClientSyncer = {
	sync: (self: ClientSyncer, payload: types.SyncPayload) -> (),
}

local function client(options: ClientSyncOptions): ClientSyncer
	local atoms = options.atoms
	local self = {} :: ClientSyncer

	function self:sync(payload)
		for key, state in payload.data do
			if payload.type == "patch" then
				atoms[key]:set(patch.apply(atoms[key]:get(), state))
			else
				atoms[key]:set(state)
			end
		end
	end

	return self
end

return client
