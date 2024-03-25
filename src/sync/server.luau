local Players = game:GetService("Players")

local atomTypes = require(script.Parent.Parent.types)
type Atom<T> = atomTypes.Atom<T>
local setInterval = require(script.Parent.Parent.utils.setInterval)
local patch = require(script.Parent.patch)
local types = require(script.Parent.types)
type SyncPayload = types.SyncPayload

type ServerSyncOptions = {
	atoms: { [string]: Atom<any> },
	interval: number?,
}

type ServerSyncer = {
	onSync: (self: ServerSyncer, callback: (player: Player, payload: SyncPayload) -> ()) -> () -> (),
	flush: (self: ServerSyncer, player: Player?) -> (),
	hydrate: (self: ServerSyncer, player: Player) -> (),
}

local function server(options: ServerSyncOptions): ServerSyncer
	local atoms = options.atoms
	local interval = options.interval or 0
	local self = {} :: ServerSyncer
	local sync: (player: Player, payload: SyncPayload) -> ()
	local state: {}

	local function getState()
		local state = {}
		for key, atom in atoms do
			state[key] = atom()
		end
		return state
	end

	function self:onSync(callback)
		sync = callback
		state = getState()

		return setInterval(function()
			self:flush()
		end, interval)
	end

	function self:flush(player: Player?)
		local current = getState()
		local previous = state or current
		state = current

		if current ~= previous then
			local payload: SyncPayload = {
				type = "patch",
				data = patch.diff(previous, current),
			}

			if player then
				return sync(player, payload)
			end

			for _, player in Players:GetPlayers() do
				sync(player, payload)
			end
		end
	end

	function self:hydrate(player)
		assert(sync, "onSync must be called before onJoin")

		sync(player, {
			type = "set",
			data = getState(),
		})
	end

	return self
end

return server
