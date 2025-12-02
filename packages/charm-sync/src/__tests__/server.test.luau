local Charm = require("../../Charm")
local config = require("../config")
local patch = require("../patch")
local server = require("../server")
local test = require("../../../../tests/test")

test.afterEach(function()
	server.reset()
end)

test("should replicate state changes", function()
	local client = {}
	local a = Charm.atom(0)
	local b = Charm.atom(0)
	local c = Charm.atom(0)
	local target, payloads

	server.addSignalsToClient(client, { a = a, b = b, c = c })
	server.connect(function(...)
		target, payloads = ...
	end)

	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "init", "Expected first payload to be init")
	assert(payloads[1].data.a == a(), "Expected init payload to contain atom 'a'")
	assert(payloads[1].data.b == b(), "Expected init payload to contain atom 'b'")
	assert(payloads[1].data.c == c(), "Expected init payload to contain atom 'c'")

	a(1)
	b(2)
	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "patch", "Expected first payload to be patch")
	assert(payloads[1].data.a == a(), "Expected patch payload to contain atom 'a'")
	assert(payloads[1].data.b == b(), "Expected patch payload to contain atom 'b'")
end)

test("should replicate partial state patches", function()
	local client = {}
	local a = Charm.atom({ x = 0, y = 0 })
	local b = Charm.atom(0 :: number?)
	local target, payloads

	server.addSignalsToClient(client, { a = a, b = b })
	server.connect(function(...)
		target, payloads = ...
	end)

	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "init", "Expected first payload to be init")
	assert(payloads[1].data.a.x == a().x, "Expected init payload to contain atom 'a.x'")
	assert(payloads[1].data.a.y == a().y, "Expected init payload to contain atom 'a.y'")
	assert(payloads[1].data.b == b(), "Expected init payload to contain atom 'b'")

	a({ x = 1, y = 0 })
	b(nil)
	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "patch", "Expected first payload to be patch")
	assert(payloads[1].data.a.x == 1, "Expected patch payload to contain atom 'a.x'")
	assert(payloads[1].data.a.y == nil, "Expected patch payload to not contain atom 'a.y'")
	assert(patch.isNone(payloads[1].data.b), "Expected patch payload to contain atom 'b' as None")
end)

test("should replicate partial state patches (reactive)", function()
	local client = {}
	local a = Charm.reactive({ x = { y = 0 }, z = 0 :: number? })
	local target, payloads

	server.addSignalsToClient(client, { a = a })
	server.connect(function(...)
		target, payloads = ...
	end)

	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "init", "Expected first payload to be init")
	assert(payloads[1].data.a.x ~= nil, "Expected init payload to contain value 'a.x'")
	assert(payloads[1].data.a.x.y == a.x.y, "Expected init payload to contain value 'a.x.y'")
	assert(payloads[1].data.a.z == a.z, "Expected init payload to contain value 'a.z'")

	a.x.y = 1
	a.z = nil
	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "patch", "Expected first payload to be patch")
	assert(payloads[1].data.a.x.y == 1, "Expected patch payload to contain value 'a.x'")
	assert(patch.isNone(payloads[1].data.a.z), "Expected patch payload to contain value 'a.z' as None")

	a.z = 1
	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "patch", "Expected first payload to be patch")
	assert(payloads[1].data.a.z == 1, "Expected patch payload to contain value 'a.z'")
	assert(payloads[1].data.a.x == nil, "Expected patch payload to not contain value 'a.x'")
end)

test("should handle nested proxies", function()
	local client = {}
	local src = Charm.reactive({ (Charm.reactive({})) })
	local payloads: {}? = nil

	server.addSignalsToClient(client, { src = src })
	server.connect(function(_, newPayloads)
		payloads = newPayloads
	end)
	server.flush()

	payloads = nil
	server.flush()
	assert(payloads == nil, "Expected no payloads to be sent for unchanged nested proxy")
end)

test("should init new clients", function()
	local clientA = {}
	local clientB = {}
	local a = Charm.atom(0)
	local payloadsA, payloadsB

	server.addSignalsToClient(clientA, { a = a })
	server.connect(function(target, payloads)
		if target == clientA then
			payloadsA = payloads
		elseif target == clientB then
			payloadsB = payloads
		end
	end)

	a(1)
	server.flush()
	assert(payloadsA[1].type == "init", "Expected first payload to be init for client A")
	assert(payloadsA[1].data.a == a(), "Expected init payload to contain atom 'a' for client A")

	a(2)
	server.addSignalsToClient(clientB, { a = a })
	server.flush()
	assert(payloadsA[1].type == "patch", "Expected first payload to be patch for client A")
	assert(payloadsA[1].data.a == a(), "Expected patch payload to contain atom 'a' for client A")
	assert(payloadsB[1].type == "init", "Expected first payload to be init for client B")
	assert(payloadsB[1].data.a == a(), "Expected init payload to contain atom 'a' for client B")
end)

test("should init new atoms", function()
	local client = {}
	local a = Charm.atom(0)
	local b = Charm.atom(0)
	local target, payloads

	server.addSignalsToClient(client, { a = a })
	server.connect(function(...)
		target, payloads = ...
	end)

	server.flush()
	server.addSignalsToClient(client, { b = b })
	a(1)
	b(1)
	server.flush()
	assert(target == client, "Expected target to be the client")
	assert(payloads[1].type == "init", "Expected first payload to be init")
	assert(payloads[1].data.b == b(), "Expected init payload to contain atom 'b'")
	assert(payloads[2].type == "patch", "Expected second payload to be patch")
	assert(payloads[2].data.a == a(), "Expected patch payload to contain atom 'a'")
	assert(payloads[2].data.b == nil, "Expected patch payload to not contain atom 'b'")
end)

test("should only replicate to synced clients", function()
	local clientA = {}
	local clientB = {}
	local a = Charm.atom(0)
	local b = Charm.atom(0)
	local payloadsA, payloadsB

	server.addSignalsToClient(clientA, { a = a })
	server.addSignalsToClient(clientB, { b = b })
	server.connect(function(target, payloads)
		if target == clientA then
			payloadsA = payloads
		elseif target == clientB then
			payloadsB = payloads
		end
	end)

	server.flush()
	assert(payloadsA[1].type == "init", "Expected first payload to be init for client A")
	assert(payloadsA[1].data.a == a(), "Expected init payload to contain atom 'a' for client A")
	assert(payloadsA[1].data.b == nil, "Expected init payload to not contain atom 'b' for client A")
	assert(payloadsB[1].type == "init", "Expected first payload to be init for client B")
	assert(payloadsB[1].data.b == b(), "Expected init payload to contain atom 'b' for client B")
	assert(payloadsB[1].data.a == nil, "Expected init payload to not contain atom 'a' for client B")

	payloadsA = {}
	payloadsB = {}
	a(1)
	server.flush()
	assert(payloadsA[1].type == "patch", "Expected first payload to be patch for client A")
	assert(payloadsA[1].data.a == a(), "Expected patch payload to contain atom 'a' for client A")
	assert(payloadsA[1].data.b == nil, "Expected patch payload to not contain atom 'b' for client A")
	assert(#payloadsB == 0, "Expected no payloads for client B")

	payloadsA = {}
	payloadsB = {}
	b(1)
	server.flush()
	assert(#payloadsA == 0, "Expected no payloads for client A")
	assert(payloadsB[1].type == "patch", "Expected first payload to be patch for client B")
	assert(payloadsB[1].data.b == b(), "Expected patch payload to contain atom 'b' for client B")
	assert(payloadsB[1].data.a == nil, "Expected patch payload to not contain atom 'a' for client B")
end)

test("should serialize state", function()
	local client = {}
	local a = Charm.atom({ 1, 2, 3, 4, 5 })
	local payloads

	server.addSignalsToClient(client, { a = a })
	server.connect(function(_, p)
		payloads = p
	end)
	server.flush()

	a({ 1, 2, 0, 4 })
	server.flush()
	assert(payloads[1].data.a["3"] == 0, "Expected index 3 to be serialized as string key")
	assert(patch.isNone(payloads[1].data.a["5"]), "Expected index 5 to be serialized as string key")
end)

test("should not send unchanged state", function()
	local client = {}
	local a = Charm.atom(0)
	local payloads

	server.addSignalsToClient(client, { a = a })
	server.connect(function(_, p)
		payloads = p
	end)

	server.flush()
	assert(payloads[1].type == "init", "Expected first payload to be init")
	assert(payloads[1].data.a == 0, "Expected init payload to contain atom 'a'")

	payloads = {}
	a(0)
	server.flush()
	assert(#payloads == 0, "Expected no payloads to be sent for unchanged state")
end)

test.describe("historical", function()
	test.beforeEach(function()
		config.preserveHistory = true
	end)

	test.afterEach(function()
		config.preserveHistory = false
	end)

	test("should replicate granular state changes", function()
		local client = {}
		local a = Charm.atom(0)
		local b = Charm.atom(0)
		local c = Charm.atom(0)
		local target, payloads

		server.addSignalsToClient(client, { a = a, b = b, c = c })
		server.connect(function(...)
			target, payloads = ...
		end)

		server.flush()
		assert(target == client, "Expected target to be the client")
		assert(payloads[1].type == "init", "Expected first payload to be init")
		assert(payloads[1].data.a == 0, "Expected init payload to contain atom 'a'")
		assert(payloads[1].data.b == 0, "Expected init payload to contain atom 'b'")
		assert(payloads[1].data.c == 0, "Expected init payload to contain atom 'c'")

		a(1)
		a(2)
		b(2)
		server.flush()
		assert(target == client, "Expected target to be the client")
		assert(payloads[1].type == "patch", "Expected first payload to be patch")
		assert(payloads[1].data.a == 1, "Expected patch payload to contain atom 'a'")
		assert(payloads[2].data.a == 2, "Expected patch payload to contain atom 'a'")
		assert(payloads[3].data.b == 2, "Expected patch payload to contain atom 'b'")
	end)

	test("should replicate granular state changes (reactive)", function()
		local client = {}
		local a = Charm.reactive({ value = 0 })
		local b = Charm.reactive({ value = 0 })
		local c = Charm.reactive({ value = 0 })
		local target, payloads

		server.addSignalsToClient(client, { a = a, b = b, c = c })
		server.connect(function(...)
			target, payloads = ...
		end)

		server.flush()
		assert(target == client, "Expected target to be the client")
		assert(payloads[1].type == "init", "Expected first payload to be init")
		assert(payloads[1].data.a.value == 0, "Expected init payload to contain atom 'a'")
		assert(payloads[1].data.b.value == 0, "Expected init payload to contain atom 'b'")
		assert(payloads[1].data.c.value == 0, "Expected init payload to contain atom 'c'")

		a.value = 1
		a.value = 2
		b.value = 2
		server.flush()
		assert(target == client, "Expected target to be the client")
		assert(payloads[1].type == "patch", "Expected first payload to be patch")
		assert(payloads[1].data.a.value == 1, "Expected patch payload to contain atom 'a'")
		assert(payloads[2].data.a.value == 2, "Expected patch payload to contain atom 'a'")
		assert(payloads[3].data.b.value == 2, "Expected patch payload to contain atom 'b'")
	end)

	test("should init new clients", function()
		local clientA = {}
		local clientB = {}
		local a = Charm.atom(0)
		local payloadsA, payloadsB

		server.addSignalsToClient(clientA, { a = a })
		server.connect(function(target, payloads)
			if target == clientA then
				payloadsA = payloads
			elseif target == clientB then
				payloadsB = payloads
			end
		end)

		a(1)
		a(2)
		server.flush()
		assert(payloadsA[1].type == "init", "Expected first payload to be init for client A")
		assert(payloadsA[1].data.a == 1, "Expected init payload to contain atom 'a' for client A")
		assert(payloadsA[2].type == "patch", "Expected second payload to be patch for client A")
		assert(payloadsA[2].data.a == 2, "Expected second patch payload to contain atom 'a' with value 1 for client A")

		server.addSignalsToClient(clientB, { a = a })
		a(3)
		a(4)
		server.flush()
		assert(payloadsA[1].type == "patch", "Expected first payload to be patch for client A")
		assert(payloadsA[1].data.a == 3, "Expected patch payload to contain atom 'a' for client A")
		assert(payloadsA[2].data.a == 4, "Expected patch payload to contain atom 'a' for client A")
		assert(payloadsB[1].type == "init", "Expected first payload to be init for client B")
		assert(payloadsB[1].data.a == 3, "Expected init payload to contain atom 'a' for client B")
		assert(payloadsB[2].type == "patch", "Expected second payload to be patch for client B")
		assert(payloadsB[2].data.a == 4, "Expected second patch payload to contain atom 'a' with value 3 for client B")
	end)

	test("should init new atoms", function()
		local client = {}
		local a = Charm.atom(0)
		local b = Charm.atom(0)
		local payloads

		server.addSignalsToClient(client, { a = a })
		server.connect(function(_, ...)
			payloads = ...
		end)

		server.flush()
		assert(payloads[1].type == "init", "Expected first payload to be init")
		assert(payloads[1].data.a == 0, "Expected init payload to contain atom 'a'")

		server.addSignalsToClient(client, { b = b })
		a(1)
		a(2)
		b(1)
		b(2)
		server.flush()
		assert(payloads[1].type == "patch", "Expected first payload to be patch")
		assert(payloads[1].data.a == 1, "Expected patch payload to contain atom 'a'")
		assert(payloads[2].data.a == 2, "Expected patch payload to contain atom 'a'")
		assert(payloads[3].type == "init", "Expected third payload to be init")
		assert(payloads[3].data.b == 1, "Expected init payload to contain atom 'b'")
		assert(payloads[4].type == "patch", "Expected fourth payload to be patch")
		assert(payloads[4].data.b == 2, "Expected patch payload to contain atom 'b'")
	end)

	test("should not send unchanged state", function()
		local client = {}
		local a = Charm.atom(0)
		local payloads

		server.addSignalsToClient(client, { a = a })
		server.connect(function(_, p)
			payloads = p
		end)

		server.flush()
		assert(payloads[1].type == "init", "Expected first payload to be init")
		assert(payloads[1].data.a == 0, "Expected init payload to contain atom 'a'")

		payloads = {}
		a(0)
		server.flush()
		assert(#payloads == 0, "Expected no payloads to be sent for unchanged state")
	end)
end)

return {}
