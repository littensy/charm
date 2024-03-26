local atom = require(script.Parent.Parent.Parent.atom)
local sync = require(script.Parent.Parent.Parent.sync)
local types = require(script.Parent.Parent.Parent.types)

return function()
	local target: Player = {} :: any

	it("sends state to new players", function()
		local a = atom(1)
		local server = sync.server({ atoms = { a = a }, interval = -1 })
		local player: Player, payload: types.SyncPayload

		local disconnect = server:connect(function(...)
			player, payload = ...
		end)

		server:hydrate(target)

		expect(player).to.equal(target)
		expect(payload.type).to.equal("set")
		expect(payload.data.a).to.equal(1)

		disconnect()
	end)

	it("sends state patches", function()
		local a = atom({ b = 1, c = 2 })
		local server = sync.server({ atoms = { a = a }, interval = -1 })
		local player: Player, payload: types.SyncPayload

		local disconnect = server:connect(function(...)
			player, payload = ...
		end)

		a({ b = 1, c = 5 })
		server:flush(target)

		expect(player).to.equal(target)
		expect(payload.type).to.equal("patch")
		expect(payload.data.a.b).to.never.be.ok()
		expect(payload.data.a.c).to.equal(5)

		disconnect()
	end)
end
