local store = require(script.Parent.Parent.store)
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
		
		@param ...payloads The patches or hydration payloads to apply.
	]=]
	sync: (self: ClientSyncer, ...SyncPayload) -> (),
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
	function self:sync(...)
		for index = 1, select("#", ...) do
			local payload = select(index, ...)

			store.batch(function()
				for key, state in next, payload.data do
					local atom = atoms[key]

					if payload.type == "patch" then
						atom(patch.apply(atom(), state))
					else
						atom(state)
					end
				end
			end)
		end
	end

	return self
end

return client
