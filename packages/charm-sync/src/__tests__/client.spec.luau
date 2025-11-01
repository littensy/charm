local Charm = require("../../Charm")
local client = require("../client")
local suite = require("../../../../test/suite")

local test = suite.test
local afterEach = suite.afterEach

afterEach(function()
	client.reset()
end)

test("should hydrate atom", function()
	local a = Charm.atom(1)

	client.register({ a = a })
	client.hydrate({
		{ type = "init", data = { a = 2 } },
	})

	assert(a() == 2, "should set a to the initial value")
end)

test("should merge patch", function()
	local a = Charm.atom({ b = 1, c = 2 })
	local previous = a()

	client.register({ a = a })
	client.hydrate({
		{ type = "init", data = { a = a() } },
	})

	assert(a() == previous, "should set a to the initial value")

	client.hydrate({
		{ type = "patch", data = { a = { b = 3 } } },
	})

	assert(a() ~= previous, "should apply patch")
	assert(a().b == 3, "should set b to the new value")
	assert(a().c == 2, "should not change c")
end)

test("should fix sparse array patches", function()
	local a = Charm.atom({ 1 })

	client.register({ a = a })
	client.hydrate({
		{ type = "init", data = { a = a() } },
	})

	-- This patch would be the result of a diff between { 1 } and { 1, 2 } that
	-- was JSON-serialized and deserialized. The client should be able to catch
	-- this and convert the string key back to a number.
	client.hydrate({
		{ type = "patch", data = { a = { ["2"] = 2 } } },
	})

	assert(a()["2" :: any] == nil, "should convert serialized arrays to use numbers")
	assert(a()[2] == 2, "should convert serialized arrays to use numbers")
end)

test("should merge multiple patches", function()
	local a = Charm.atom(1)
	local calls = {}

	client.register({ a = a })

	Charm.subscribe(a, function(value)
		table.insert(calls, value)
	end)

	client.hydrate({
		{ type = "init", data = { a = a() } },
	})

	client.hydrate({
		{ type = "patch", data = { a = 2 } },
		{ type = "patch", data = { a = 3 } },
	})

	assert(a() == 3, "should apply the last patch")
	assert(table.concat(calls) == "23", `wrong order: {table.concat(calls)}`)
end)

test("should batch patches", function()
	local a = Charm.atom(0)
	local b = Charm.atom(0)
	local states = {}

	client.register({ a = a, b = b })

	Charm.subscribe(a, function()
		states.b = b()
	end)

	Charm.subscribe(b, function()
		states.a = a()
	end)

	client.hydrate({
		{ type = "init", data = { a = a(), b = b() } },
	})

	client.hydrate({
		{ type = "patch", data = { a = 1, b = 2 } },
	})

	assert(a() == 1, "should set a to the new value")
	assert(b() == 2, "should set b to the new value")
	assert(states.a == 1, "sub to a should run after b updates")
	assert(states.b == 2, "sub to b should run after a updates")
end)

return {}
