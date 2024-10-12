local Charm = require(script.Parent.Parent.Charm)
local patch = require(script.Parent.patch)
local types = require(script.Parent.types)
type SyncPayload = types.SyncPayload

type ClientOptions = {
	--[=[
		The atoms to synchronize with the server.
	]=]
	atoms: { [string]: Charm.Atom<any> },
	--[=[
		Whether to ignore patches sent before the client has been hydrated.
		Default is `true`.
	]=]
	ignoreUnhydrated: boolean?,
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
	local ignoreUnhydrated = options.ignoreUnhydrated ~= false
	local self = {} :: ClientSyncer
	local hydrated = false

	-- Apply the state changes sent by the server.
	function self:sync(...)
		for index = 1, select("#", ...) do
			local payload: SyncPayload = select(index, ...)

			if ignoreUnhydrated and payload.type == "patch" and not hydrated then
				-- If the client is not initialized, ignore patches. This is
				-- to prevent patching incomplete state.
				continue
			end

			hydrated = true

			Charm.batch(function()
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
