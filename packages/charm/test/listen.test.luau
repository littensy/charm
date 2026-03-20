local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local listen = Charm.listen

test("should listen to selector", function()
	local source, setSource = signal(0)
	local current, previous

	local unsub = listen(function()
		return source() + 1
	end, function(a, b)
		current = a
		previous = b
	end)

	assert(current == 1 and previous == nil, "should run initially")
	setSource(0)
	assert(current == 1 and previous == nil, "should skip redundant update")
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

	listen(a, function()
		runs += 1
		b()
	end)

	assert(runs == 1, "should run once on init")
	setA(1)
	assert(runs == 2, "should run once on change")
	setB(1)
	assert(runs == 2, "should not run on b change")
	setA(2)
	assert(runs == 3, "should run on a change")
end)

test("should run if first value is nil", function()
	local runs = 0
	local source, setSource = signal(nil :: number?)

	listen(source, function()
		runs += 1
	end)

	assert(runs == 1, "should run once on init")
	setSource(1)
	assert(runs == 2, "should run once on change")
end)

test("should skip redundant updates", function()
	local order = {}
	local a, setA = signal(0)

	listen(function(): "even" | "odd"
		return if a() % 2 == 0 then "even" else "odd"
	end, function(value)
		table.insert(order, value)
	end)

	setA(1)
	setA(3)
	setA(4)
	setA(6)
	assert(table.concat(order) == "evenoddeven", `bad order: {table.concat(order)}`)
end)

return {}
