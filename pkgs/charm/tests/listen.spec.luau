local Charm = require("../src/lib")
local suite = require("@test/suite")

local atom = Charm.atom
local listen = Charm.listen
local test = suite.test

test("should listen to selector", function()
	local source = atom(0)
	local current, previous

	local unsub = listen(function()
		return source() + 1
	end, function(a, b)
		current = a
		previous = b
	end)

	assert(current == 1 and previous == nil, "should run initially")
	source(0)
	assert(current == 1 and previous == nil, "should skip redundant update")
	source(1)
	assert(current == 2 and previous == 1, "should run with new value")
	unsub()
	source(2)
	assert(current == 2 and previous == 1, "should not run after unsub")
end)

test("should track inner subs", function()
	local order = {}
	local a = atom(1)

	local unsub = listen(a, function()
		table.insert(order, 1)
		listen(a, function()
			table.insert(order, 2)
		end)
		listen(a, function()
			table.insert(order, 3)
		end)
	end)

	assert(table.concat(order) == "123", `bad mount order: {table.concat(order)}`)

	table.clear(order)
	a(a() + 1)
	assert(table.concat(order) == "123", `bad order: {table.concat(order)}`)

	table.clear(order)
	a(a() + 1)
	assert(table.concat(order) == "123", `bad order: {table.concat(order)}`)

	table.clear(order)
	unsub()
	a(a() + 1)
	assert(table.concat(order) == "", `bad order: {table.concat(order)}`)
end)

return {}
