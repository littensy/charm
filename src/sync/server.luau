local Players = game:GetService("Players")

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
	flush: (self: ServerSyncer, player: Player) -> (),
	hydrate: (self: ServerSyncer, player: Player) -> (),
}

local function server(options: ServerOptions): ServerSyncer
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

	function self:connect(callback)
		sync = callback
		state = getState()

		return setInterval(function()
			local previous = state
			state = getState()

			if state ~= previous then
				local diffs = patch.diff(previous, state)

				for _, player in Players:GetPlayers() do
					callback(player, {
						type = "patch",
						data = diffs,
					})
				end
			end
		end, interval)
	end

	function self:flush(player: Player)
		local previous = state
		state = getState()

		sync(player, {
			type = "patch",
			data = patch.diff(previous, state),
		})
	end

	function self:hydrate(player)
		assert(sync, "connect() must be called before hydrate()")

		sync(player, {
			type = "init",
			data = getState(),
		})
	end

	return self
end

return server
