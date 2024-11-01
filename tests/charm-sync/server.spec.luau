local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local CharmSync = require(ReplicatedStorage.DevPackages.CharmSync)
type SyncPayload = CharmSync.SyncPayload
local server = CharmSync.server

return function()
	local target: Player = {} :: any

	it("sends state to new players", function()
		local a = atom(1)
		local server = server({ atoms = { a = a }, interval = -1 })
		local player: Player, payload: SyncPayload

		local disconnect = server:connect(function(...)
			player, payload = ...
		end)

		server:hydrate(target)

		expect(player).to.equal(target)
		assert(payload.type == "init", "payload.type is not 'init'")
		expect(payload.data.a).to.equal(1)

		disconnect()
	end)

	it("sends state patches", function()
		local a = atom({ 1, 2 })
		local server = server({ atoms = { a = a }, interval = -1 })
		local player: Player, payload: SyncPayload

		local disconnect = server:connect(function(...)
			player, payload = ...
		end)

		a({ 1, 5 })
		server:_sendPatch(target)

		expect(player).to.equal(target)
		assert(payload.type == "patch", "payload.type is not 'patch'")
		expect(#payload.data).to.equal(1)

		expect(table.concat(payload.data[1].path, "/")).to.equal("a/2")
		expect(payload.data[1].data).to.equal(5)

		a({ 1, nil :: any, 1 })
		server:_sendPatch(target)

		assert(payload.type == "patch", "payload.type is not 'patch'")
		expect(#payload.data).to.equal(2)

		expect(table.concat(payload.data[1].path, "/")).to.equal("a/2")
		expect(payload.data[1].data).to.never.be.ok()

		expect(table.concat(payload.data[2].path, "/")).to.equal("a/3")
		expect(payload.data[2].data).to.equal(1)

		disconnect()
	end)

	it("preserves history", function()
		local a = atom(1)
		local b = atom(1)
		local payloads: { SyncPayload }

		local server = server({
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
		assert(payloads[1].type == "patch", "payload 1 type is not 'patch'")
		expect(#payloads[1].data).to.equal(2)

		-- a(2)
		expect(table.concat(payloads[1].data[1].path, "/")).to.equal("a")
		expect(payloads[1].data[1].data).to.equal(2)

		-- b(2)
		expect(table.concat(payloads[1].data[2].path, "/")).to.equal("b")
		expect(payloads[1].data[2].data).to.equal(2)

		a(3)
		a(4)
		b(3)
		server:_sendPatch(target)

		expect(#payloads).to.equal(2)
		assert(payloads[1].type == "patch", "payload 1 type is not 'patch'")
		expect(#payloads[1].data).to.equal(1)

		-- a(3)
		expect(table.concat(payloads[1].data[1].path, "/")).to.equal("a")
		expect(payloads[1].data[1].data).to.equal(3)

		-- second a() call cannot be collapsed, so it is added to a new payload
		assert(payloads[2].type == "patch", "payload 2 type is not 'patch'")
		expect(#payloads[2].data).to.equal(2)

		-- a(4)
		expect(table.concat(payloads[2].data[1].path, "/")).to.equal("a")
		expect(payloads[2].data[1].data).to.equal(4)

		-- b(3)
		expect(table.concat(payloads[2].data[2].path, "/")).to.equal("b")
		expect(payloads[2].data[2].data).to.equal(3)

		disconnect()
	end)
end
