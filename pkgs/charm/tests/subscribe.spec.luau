local Charm = require("../src/lib")
local suite = require("@test/suite")

type Atom<T> = Charm.Atom<T>

local atom = Charm.atom
local computed = Charm.computed
local subscribe = Charm.subscribe
local listen = Charm.listen
local effect = Charm.effect
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

test("should run in untracked", function()
	local runs = 0
	local cleanups = 0
	local a = atom(0)
	local b = atom(0)

	subscribe(a, function()
		runs += 1
		b()
		effect(function()
			return function()
				cleanups += 1
			end
		end)
	end)

	assert(runs == 0, "should not run once on init")
	assert(cleanups == 0, "should not cleanup yet")

	a(1)
	assert(runs == 1, "should run once on change")
	assert(cleanups == 0, "should not cleanup yet")

	b(1)
	assert(runs == 1, "should not run on b change")
	assert(cleanups == 0, "should not cleanup first call")

	a(2)
	assert(runs == 2, "should run on a change")
	assert(cleanups == 1, "should cleanup first call")
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

test("should track inner subs", function()
	local order = {}
	local a = atom(1)

	local unsub = subscribe(a, function()
		table.insert(order, 1)
		listen(a, function()
			table.insert(order, 2)
		end)
		listen(a, function()
			table.insert(order, 3)
		end)
	end)

	assert(table.concat(order) == "", "should not run immediately")

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
