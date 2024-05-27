local Players = game:GetService("Players")

local subscribe = require(script.Parent.Parent.subscribe)
local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>
type SyncPayload = types.SyncPayload
local setInterval = require(script.Parent.Parent.utils.setInterval)
local patch = require(script.Parent.patch)

type ServerOptions = {
	atoms: { [string]: Atom<any> },
	interval: number?,
}

type ServerSyncer = {
	connect: (self: ServerSyncer, callback: (player: Player, payload: SyncPayload) -> ()) -> () -> (),
	hydrate: (self: ServerSyncer, player: Player) -> (),
	_sendPatch: (self: ServerSyncer, player: Player) -> (),
}

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
			stateSnapshot[key] = atom()
		end

		local disconnect = setInterval(function()
			if not changed then
				return
			end

			local diffs = patch.diff(stateSnapshot, state)
			stateSnapshot = table.clone(state)
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
