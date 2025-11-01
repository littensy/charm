local Charm = require("../")
local suite = require("../../../../test/suite")

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local peek = Charm.peek
local test = suite.test

test("should not run detached", function()
	local a, setA = signal(1)
	local spyCalls = 0

	effect(function()
		a()
		peek(function()
			effect(function()
				return function()
					spyCalls += 1
				end
			end)
		end)
	end)

	assert(spyCalls == 0, "should not be called yet")
	setA(2)
	assert(spyCalls == 1, "should be called once")
	setA(3)
	assert(spyCalls == 2, "should be called twice")
end)

test("should block tracking inside effects", function()
	local a, setA = signal(1)
	local b, setB = signal(2)
	local spyCalls = 0

	effect(function()
		peek(function()
			spyCalls += 1
			return a() + b()
		end)
	end)
	assert(spyCalls == 1, "should be called once")

	setA(10)
	setB(20)
	assert(spyCalls == 1, "should be called once")
end)

test("should block tracking even when run inside effect run inside peek", function()
	local s, setS = signal(1)
	local spyCalls = 0

	peek(function()
		effect(function()
			peek(function()
				spyCalls += 1
				return s()
			end)
		end)
	end)
	assert(spyCalls == 1, "should be called once")

	setS(2)
	assert(spyCalls == 1, "should be called once")
end)

test("should not cause signal assignments to throw", function()
	local a, setA = signal(1)
	local aChangedTime, setAChangedTime = signal(0)

	local dispose = effect(function()
		a()
		peek(function()
			setAChangedTime(aChangedTime() + 1)
		end)
	end)

	setA(2)
	assert(aChangedTime() == 2, "aChangedTime should be 2")
	setA(3)
	assert(aChangedTime() == 3, "aChangedTime should be 3")

	dispose()
end)

test("should block tracking inside computed signals", function()
	local a, setA = signal(1)
	local b, setB = signal(2)
	local spyCalls = 0
	local c = computed(function()
		return peek(function()
			spyCalls += 1
			return a() + b()
		end)
	end)

	assert(spyCalls == 0, "should not be called yet")
	assert(c() == 3, "c should be 3")
	setA(10)
	c()
	setB(20)
	c()
	assert(spyCalls == 1, "should be called once")
	assert(c() == 3, "c should be 3")
end)

test("should track outside peek", function()
	local a, setA = signal(1)
	local b, setB = signal(2)
	local c, setC = signal(3)
	local spyCalls = 0

	effect(function()
		a()
		peek(c)
		b()
		spyCalls += 1
	end)

	assert(spyCalls == 1, "should be called once")
	setA(10)
	assert(spyCalls == 2, "should be called twice")
	setB(20)
	assert(spyCalls == 3, "should be called three times")
	setC(30)
	assert(spyCalls == 3, "should not run on c change")
end)

test("should stack peek", function()
	local a, setA = signal(1)
	local spyCalls = 0

	effect(function()
		peek(function()
			peek(a)
			return a()
		end)
		spyCalls += 1
	end)

	assert(spyCalls == 1, "should be called once")
	setA(2)
	assert(spyCalls == 1, "should not be called twice")
end)

return {}
