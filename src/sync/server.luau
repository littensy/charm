local Players = game:GetService("Players")

local subscribe = require(script.Parent.Parent.subscribe)
local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>
type SyncPayload = types.SyncPayload
local setInterval = require(script.Parent.Parent.utils.setInterval)
local patch = require(script.Parent.patch)

type ServerOptions = {
	--[=[
		The atoms to synchronize with the client.
	]=]
	atoms: { [string]: Atom<any> },
	--[=[
		The interval at which to send patches to the client, in seconds.
		Defaults to `0` (patches are sent up to once per frame). Set to a
		negative value to disable automatic syncing.
	]=]
	interval: number?,
}

type ServerSyncer = {
	--[=[
		Sets up a subscription to each atom that schedules a patch to be sent to
		the client whenever the state changes. When a change occurs, the `callback`
		is called with the player and the payload to send.

		Note that the `payload` object should not be mutated. If you need to
		modify the payload, apply the changes to a copy of the object.

		@param callback The function to call when the state changes.
		@return A cleanup function that unsubscribes all listeners.
	]=]
	connect: (self: ServerSyncer, callback: (player: Player, payload: SyncPayload) -> ()) -> () -> (),
	--[=[
		Hydrates the client's state with the server's state. This should be
		called when a player joins the game and requires the server's state.

		@param player The player to hydrate.
	]=]
	hydrate: (self: ServerSyncer, player: Player) -> (),
	--[=[
		@deprecated For internal use only.
	]=]
	_sendPatch: (self: ServerSyncer, player: Player) -> (),
}

--[=[
	Creates a `ServerSyncer` object that sends patches to the client and
	hydrates the client's state.
	
	@param options The atoms to synchronize with the client.
	@return A `ServerSyncer` object.
]=]
local function server(options: ServerOptions): ServerSyncer
	local atoms = options.atoms
	local interval = options.interval or 0

	local self = {} :: ServerSyncer
	local sync: (player: Player, payload: SyncPayload) -> ()
	local state: { [string]: any } = {}
	local stateSnapshot = {}
	local changed = false

	-- Start the interval to send state patches over the network.
	function self:connect(callback)
		local cleanups = {}
		sync = callback

		-- Populate the initial state and snapshot for each atom.
		-- Subscribe to each atom and update the state when it changes.
		for key, atom in atoms do
			cleanups[key] = subscribe(atom, function(current)
				state[key] = current
				changed = true
			end)

			state[key] = atom()
			stateSnapshot[key] = state[key]
		end

		local disconnect = setInterval(function()
			if not changed then
				return
			end

			local diffs = patch.diff(stateSnapshot, state)
			stateSnapshot = state
			changed = false

			for _, player in Players:GetPlayers() do
				callback(player, {
					type = "patch",
					data = diffs,
				})
			end
		end, interval)

		return function()
			disconnect()
			for _, cleanup in cleanups do
				cleanup()
			end
		end
	end

	-- Send the initial state to a player when they join the server.
	function self:hydrate(player)
		assert(sync, "connect() must be called before hydrate()")

		sync(player, {
			type = "init",
			data = state,
		})
	end

	function self:_sendPatch(player: Player)
		assert(sync, "connect() must be called before _sendPatch()")

		if not changed then
			return
		end

		local diffs = patch.diff(stateSnapshot, state)
		stateSnapshot = table.clone(state)
		changed = false

		sync(player, {
			type = "patch",
			data = diffs,
		})
	end

	return self
end

return server
