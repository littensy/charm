local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local computed = Charm.computed
local subscribe = Charm.subscribe

test("should subscribe to selector", function()
	local source, setSource = signal(0)
	local current, previous

	local unsub = subscribe(function()
		return source() + 1
	end, function(a, b)
		current = a
		previous = b
	end)

	assert(not current and not previous, "should not run initially")
	setSource(0)
	assert(not current and not previous, "should skip redundant update")
	setSource(1)
	assert(current == 2 and previous == 1, "should run with new value")
	unsub()
	setSource(2)
	assert(current == 2 and previous == 1, "should not run after unsub")
end)

test("should run in untracked", function()
	local runs = 0
	local a, setA = signal(0)
	local b, setB = signal(0)

	subscribe(a, function()
		runs += 1
		b()
	end)

	assert(runs == 0, "should not run once on init")
	setA(1)
	assert(runs == 1, "should run once on change")
	setB(1)
	assert(runs == 1, "should not run on b change")
	setA(2)
	assert(runs == 2, "should run on a change")
end)

test("should ensure correct execution order", function()
	local order: { number } = {}
	local n1, setN1 = signal(0)
	local n2, setN2 = signal(0)
	local sum = computed(function()
		return n1() + n2()
	end)

	subscribe(n1, function()
		table.insert(order, 1)
		setN2(n2() + 1)
	end)

	subscribe(sum, function()
		table.insert(order, 2)
	end)

	subscribe(n1, function()
		table.insert(order, 3)
	end)

	setN1(n1() + 1)

	assert(table.concat(order) == "123", `bad order: {table.concat(order)}`)
end)

test("should skip redundant updates", function()
	local order: { "even" | "odd" } = {}
	local a, setA = signal(0)

	subscribe(function(): "even" | "odd"
		return if a() % 2 == 0 then "even" else "odd"
	end, function(value)
		table.insert(order, value)
	end)

	setA(1)
	setA(3)
	setA(4)
	setA(6)
	assert(table.concat(order) == "oddeven", `bad order: {table.concat(order)}`)
end)

return {}
