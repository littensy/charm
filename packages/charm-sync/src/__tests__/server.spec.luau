local Charm = require("../../Charm")
local config = require("../config")
local patch = require("../patch")
local server = require("../server")
local suite = require("../../../../test/suite")

local afterEach = suite.afterEach
local beforeEach = suite.beforeEach
local describe = suite.describe
local test = suite.test

afterEach(function()
	server.reset()
end)

test("should replicate state changes", function()
	local client = {}
	local a = Charm.atom(0)
	local b = Charm.atom(0)
	local c = Charm.atom(0)
	local target, payloads

	server.subscribeClient(client, { a = a, b = b, c = c })
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

	server.subscribeClient(client, { a = a, b = b })
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

test("should init new clients", function()
	local clientA = {}
	local clientB = {}
	local a = Charm.atom(0)
	local payloadsA, payloadsB

	server.subscribeClient(clientA, { a = a })
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

	server.subscribeClient(clientB, { a = a })
	a(2)
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

	server.subscribeClient(client, { a = a })
	server.connect(function(...)
		target, payloads = ...
	end)

	server.flush()
	server.subscribeClient(client, { b = b })
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

	server.subscribeClient(clientA, { a = a })
	server.subscribeClient(clientB, { b = b })
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

test("should validate state", function()
	local client = {}
	local a = Charm.atom({})

	server.subscribeClient(client, { a = a })
	server.connect(function() end)

	a({ [0.5] = true })
	assert(not pcall(server.flush), "Expected server.flush to fail")

	a({ [0.5] = true, valid = true })
	server.flush()
end)

test("should serialize state", function()
	local client = {}
	local a = Charm.atom({ 1, 2, 3, 4, 5 })
	local payloads

	server.subscribeClient(client, { a = a })
	server.connect(function(_, p)
		payloads = p
	end)
	server.flush()

	a({ 1, 2, 0, 4 })
	server.flush()
	assert(payloads[1].data.a["3"] == 0, "Expected index 3 to be serialized as string key")
	assert(patch.isNone(payloads[1].data.a["5"]), "Expected index 5 to be serialized as string key")
end)

describe("historical", function()
	beforeEach(function()
		config.preserveHistory = true
	end)

	afterEach(function()
		config.preserveHistory = false
	end)

	test("should replicate granular state changes", function()
		local client = {}
		local a = Charm.atom(0)
		local b = Charm.atom(0)
		local c = Charm.atom(0)
		local target, payloads

		server.subscribeClient(client, { a = a, b = b, c = c })
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

	test("should init new clients", function()
		local clientA = {}
		local clientB = {}
		local a = Charm.atom(0)
		local payloadsA, payloadsB

		server.subscribeClient(clientA, { a = a })
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

		server.subscribeClient(clientB, { a = a })
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

		server.subscribeClient(client, { a = a })
		server.connect(function(_, ...)
			payloads = ...
		end)

		server.flush()
		assert(payloads[1].type == "init", "Expected first payload to be init")
		assert(payloads[1].data.a == 0, "Expected init payload to contain atom 'a'")

		server.subscribeClient(client, { b = b })
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
end)

return {}
