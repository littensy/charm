local atomTypes = require(script.Parent.Parent.types)
type Atom<T> = atomTypes.Atom<T>
local patch = require(script.Parent.patch)
local types = require(script.Parent.types)
type SyncPayload = types.SyncPayload

type ClientSyncOptions = {
	atoms: { [string]: Atom<any> },
}

type ClientSyncer = {
	sync: (self: ClientSyncer, payload: SyncPayload) -> (),
}

local function client(options: ClientSyncOptions): ClientSyncer
	local atoms = options.atoms
	local self = {} :: ClientSyncer

	function self:sync(payload)
		for key, state in payload.data do
			if payload.type == "patch" then
				atoms[key](patch.apply(atoms[key](), state))
			else
				atoms[key](state)
			end
		end
	end

	return self
end

return client
