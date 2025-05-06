local Charm = require("../src/lib")
local suite = require("@tests/suite")

type Atom<T> = Charm.Atom<T>

local atom = Charm.atom
local computed = Charm.computed
local subscribe = Charm.subscribe
local test = suite.test

test("should subscribe to selector", function()
	local source = atom(0)
	local current, previous

	local unsub = subscribe(function()
		return source() + 1
	end, function(a, b)
		current = a
		previous = b
	end)

	assert(not current and not previous, "should not run initially")
	source(0)
	assert(not current and not previous, "should skip redundant update")
	source(1)
	assert(current == 2 and previous == 1, "should run with new value")
	unsub()
	source(2)
	assert(current == 2 and previous == 1, "should not run after unsub")
end)

test("should ensure correct execution order", function()
	local order = {}
	local n1 = atom(0)
	local n2 = atom(0)
	local sum = computed(function()
		return n1() + n2()
	end)

	subscribe(n1, function()
		table.insert(order, 1)
		n2(n2() + 1)
	end)

	subscribe(sum, function()
		table.insert(order, 2)
	end)

	subscribe(n1, function()
		table.insert(order, 3)
	end)

	n1(n1() + 1)

	assert(table.concat(order) == "123", `bad order: {table.concat(order)}`)
end)

return {}
