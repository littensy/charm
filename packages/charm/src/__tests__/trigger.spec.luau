local Charm = require("../")
local suite = require("../../../../test/suite")

local computed = Charm.computed
local effect = Charm.effect
local signal = Charm.signal
local subscribe = Charm.subscribe
local trigger = Charm.trigger
local test = suite.test
local beforeEach = suite.beforeEach
local afterEach = suite.afterEach

beforeEach(function()
	Charm.flags.frozen = false
end)

afterEach(function()
	Charm.flags.frozen = true
end)

test("should not throw when triggering with no dependencies", function()
	trigger(function() end)
end)

test("should trigger updates for dependent computed signals", function()
	local arr = signal({} :: { number })
	local length = computed(function()
		return #arr()
	end)

	assert(length() == 0, "initial length should be 0")
	table.insert(arr(), 1)
	trigger(arr)
	assert(length() == 1, "length should be 1")
end)

test("should trigger updates for the second source signal", function()
	local src1 = signal({} :: { number })
	local src2 = signal({} :: { number })
	local length = computed(function()
		return #src2()
	end)

	assert(length() == 0, "initial length should be 0")
	table.insert(src2(), 1)
	trigger(function()
		src1()
		src2()
	end)
	assert(length() == 1, "length should be 1")
end)

test("should trigger effect once", function()
	local src1 = signal({} :: { number })
	local src2 = signal({} :: { number })
	local triggers = 0

	effect(function()
		triggers += 1
		src1()
		src2()
	end)
	assert(triggers == 1, "effect should run once initially")

	trigger(function()
		src1()
		src2()
	end)
	assert(triggers == 2, "effect should run twice")
end)

test("should not notify the trigger function sub", function()
	local src1 = signal({})
	local src2 = computed(function()
		return src1()
	end)

	effect(function()
		src1()
		src2()
	end)
	trigger(function()
		src1()
		src2()
	end)
end)

test("should trigger updates for subscribe", function()
	local src = signal({} :: { number })
	local triggers = 0

	subscribe(src, function()
		triggers += 1
	end)

	table.insert(src(), 1)
	trigger(src)
	assert(triggers == 1, "subscribe callback should run after trigger")
end)

return {}
