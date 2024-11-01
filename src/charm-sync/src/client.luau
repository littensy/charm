local Charm = require(script.Parent.Parent.Charm)
local packets = require(script.Parent.packets)
type Packet = packets.Packet
local types = require(script.Parent.types)
type SyncPayload = types.SyncPayload

type ClientOptions = {
	--[=[
		The atoms to synchronize with the server.
	]=]
	atoms: { [string | number]: Charm.Atom<any> },
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
	local self = {} :: ClientSyncer

	local atoms = options.atoms
	local ignoreUnhydrated = options.ignoreUnhydrated ~= false
	local hydrated = false

	local function hydrate(state: { [string | number]: any })
		hydrated = true

		for key, value in next, state do
			local atom = atoms[key]
			atom(value)
		end
	end

	local function patch(data: { Packet })
		local target = {}

		for key, atom in next, atoms do
			target[key] = atom()
		end

		target = packets.apply(target, data)

		for key, atom in next, atoms do
			atom(target[key])
		end
	end

	function self:sync(...)
		for index = 1, select("#", ...) do
			local payload: SyncPayload = select(index, ...)

			Charm.batch(function()
				if payload.type == "init" then
					hydrate(payload.data)
				elseif not ignoreUnhydrated or hydrated then
					patch(payload.data)
				end
			end)
		end
	end

	return self
end

return client
