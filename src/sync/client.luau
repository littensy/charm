local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>
type SyncPayload = types.SyncPayload
local patch = require(script.Parent.patch)

type ClientOptions = {
	atoms: { [string]: Atom<any> },
}

type ClientSyncer = {
	sync: (self: ClientSyncer, payload: SyncPayload) -> (),
}

local function client(options: ClientOptions): ClientSyncer
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
