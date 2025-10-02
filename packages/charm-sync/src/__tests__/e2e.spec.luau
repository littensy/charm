local Charm = require("../../Charm")
local client = require("../client")
local config = require("../config")
local server = require("../server")
local suite = require("../../../../test/suite")

local afterEach = suite.afterEach
local test = suite.test

afterEach(function()
	server.reset()
	client.reset()
	config.preserveHistory = false
end)

test("should replicate server state to client", function()
	local target = {}
	local serverA = Charm.atom({ count = 0 })
	local serverB = Charm.atom({ count = 0 })
	local clientA = Charm.atom({ count = -1 })
	local clientB = Charm.atom({ count = -1 })

	client.syncAtoms({ a = clientA, b = clientB })
	server.syncAtomsToClient(target, { a = serverA, b = serverB })
	server.startSync(function(syncTarget, payloads)
		if syncTarget == target then
			client.applyPayloads(payloads)
		end
	end)

	server.flush()
	assert(clientA().count == 0, "Client atom A should be initialized to 0")
	assert(clientB().count == 0, "Client atom B should be initialized to 0")

	serverA({ count = 1 })
	serverB({ count = 1 })
	server.flush()
	assert(clientA().count == 1, "Client atom A should be updated to 1")
	assert(clientB().count == 1, "Client atom B should be updated to 1")

	local prevClientB = clientB()
	serverA({ count = 2 })
	server.flush()
	assert(clientA().count == 2, "Client atom A should be updated to 2")
	assert(clientB() == prevClientB, "Client atom B should not be updated")
end)

test("should replicate historical server state to client", function()
	local target = {}
	local serverA = Charm.atom({ count = 0 })
	local serverB = Charm.atom({ count = 0 })
	local clientA = Charm.atom({ count = -1 })
	local clientB = Charm.atom({ count = -1 })

	config.preserveHistory = true

	client.syncAtoms({ a = clientA, b = clientB })
	server.syncAtomsToClient(target, { a = serverA, b = serverB })
	server.startSync(function(syncTarget, payloads)
		if syncTarget == target then
			client.applyPayloads(payloads)
		end
	end)

	local expectedA = { -1, 0, 1, 2, 3, 4 }
	local expectedB = { -1, 0, 1, 2 }

	Charm.effect(function()
		local expected = table.remove(expectedA, 1)
		assert(expected == clientA().count, `Client atom A should be {expected}`)
	end)

	Charm.effect(function()
		local expected = table.remove(expectedB, 1)
		assert(expected == clientB().count, `Client atom B should be {expected}`)
	end)

	server.flush()

	serverA({ count = 1 })
	serverA({ count = 2 })
	serverB({ count = 1 })
	serverB({ count = 2 })
	server.flush()
	assert(clientA().count == 2, "Client atom A should be updated to 2")
	assert(clientB().count == 2, "Client atom B should be updated to 2")

	local prevClientB = clientB()
	serverA({ count = 3 })
	serverA({ count = 4 })
	server.flush()
	assert(clientA().count == 4, "Client atom A should be updated to 4")
	assert(clientB() == prevClientB, "Client atom B should not be updated")
end)

return {}
