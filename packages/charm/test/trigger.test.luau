local Charm = require("../src")
local test = require("../../../tests/test")

local computed = Charm.computed
local effect = Charm.effect
local listen = Charm.listen
local signal = Charm.signal
local subscribe = Charm.subscribe
local trigger = Charm.trigger

test.beforeEach(function()
	Charm.flags.frozen = false
end)

test.afterEach(function()
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
	local src1 = signal({} :: { number })
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

test("subscribe should not trigger updates for unchanged value", function()
	local src = signal({} :: { number })
	local triggers = 0

	subscribe(src, function()
		triggers += 1
	end)

	trigger(src)
	assert(triggers == 0, "subscribe callback should not run after trigger")
end)

test("listen should not trigger updates for unchanged value", function()
	local src = signal({} :: { number })
	local triggers = 0

	listen(src, function()
		triggers += 1
	end)
	assert(triggers == 1, "listen callback should run once initially")

	trigger(src)
	assert(triggers == 1, "listen callback should not run after trigger")
end)

return {}
