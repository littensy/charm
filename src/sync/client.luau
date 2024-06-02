local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>
type SyncPayload = types.SyncPayload
local patch = require(script.Parent.patch)

type ClientOptions = {
	--[=[
		The atoms to synchronize with the server.
	]=]
	atoms: { [string]: Atom<any> },
}

type ClientSyncer = {
	--[=[
		Applies a patch or initializes the state of the atoms with the given
		payload from the server.
		
		@param payload The patch or hydration payload to apply.
	]=]
	sync: (self: ClientSyncer, payload: SyncPayload) -> (),
}

--[=[
	Creates a `ClientSyncer` object that receives patches from the server and
	applies them to the local state.
	
	@param options The atoms to synchronize with the server.
	@return A `ClientSyncer` object.
]=]
local function client(options: ClientOptions): ClientSyncer
	local atoms = options.atoms
	local self = {} :: ClientSyncer

	-- Apply the state changes sent by the server.
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
