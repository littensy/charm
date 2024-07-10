local atom = require(script.Parent.Parent.Parent.atom)
local sync = require(script.Parent.Parent.Parent.sync)
local patch = require(script.Parent.Parent.Parent.sync.patch)
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
		expect(payload.type).to.equal("init")
		expect(payload.data.a).to.equal(1)

		disconnect()
	end)

	it("sends state patches", function()
		local a = atom({ b = 1, c = 2 } :: { [string]: number? })
		local server = sync.server({ atoms = { a = a }, interval = -1 })
		local player: Player, payload: types.SyncPayload

		local disconnect = server:connect(function(...)
			player, payload = ...
		end)

		a({ b = 1, c = 5 })
		server:_sendPatch(target)

		expect(player).to.equal(target)
		expect(payload.type).to.equal("patch")
		expect(payload.data.a.b).to.never.be.ok()
		expect(payload.data.a.c).to.equal(5)

		a({ b = 1, d = 1 })
		server:_sendPatch(target)

		expect(payload.data.a.b).to.never.be.ok()
		expect(payload.data.a.c).to.equal(patch.NONE)
		expect(payload.data.a.d).to.equal(1)

		disconnect()
	end)

	it("preserves history", function()
		local a = atom(1)
		local b = atom(1)
		local payloads: { types.SyncPayload }

		local server = sync.server({
			atoms = { a = a, b = b },
			interval = -1,
			preserveHistory = true,
		})

		local disconnect = server:connect(function(_, ...)
			payloads = { ... }
		end)

		a(2)
		b(2)
		server:_sendPatch(target)

		expect(#payloads).to.equal(1)
		expect(payloads[1].type).to.equal("patch")
		expect(payloads[1].data.a).to.equal(2)
		expect(payloads[1].data.b).to.equal(2)

		a(3)
		a(4)
		b(3)
		server:_sendPatch(target)

		expect(#payloads).to.equal(2)
		expect(payloads[1].type).to.equal("patch")
		expect(payloads[1].data.a).to.equal(3)
		expect(payloads[1].data.b).to.never.be.ok()
		expect(payloads[2].type).to.equal("patch")
		expect(payloads[2].data.a).to.equal(4)
		expect(payloads[2].data.b).to.equal(3)

		disconnect()
	end)
end
