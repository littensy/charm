local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local effectScope = Charm.effectScope
local untracked = Charm.untracked

test("should run detached from effect", function()
	local a, setA = signal(1)
	local effects = 0
	local innerEffects = {}

	local stopEffect = effect(function()
		a()
		untracked(function()
			local stopInnerEffect = effect(function()
				effects += 1
				return function()
					effects -= 1
				end
			end)
			table.insert(innerEffects, stopInnerEffect)
		end)
	end)

	assert(effects == 1, "should have one effect")
	setA(2)
	assert(effects == 2, "should have two effects")
	stopEffect()
	assert(effects == 2, "should still have two effects")
	for _, stopInnerEffect in innerEffects do
		stopInnerEffect()
	end
	assert(effects == 0, "should have zero effects")
end)

test("should run detached from effect scope", function()
	local effects = 0
	local stopEffect: () -> ()

	local stopScope = effectScope(function()
		untracked(function()
			stopEffect = effect(function()
				effects += 1
				return function()
					effects -= 1
				end
			end)
		end)
	end)

	assert(effects == 1, "should have one effect")
	stopScope()
	assert(effects == 1, "should still have one effect")
	stopEffect()
	assert(effects == 0, "should have zero effects")
end)

test("should block tracking inside effects", function()
	local a, setA = signal(1)
	local b, setB = signal(2)
	local spyCalls = 0

	effect(function()
		untracked(function()
			spyCalls += 1
			return a() + b()
		end)
	end)
	assert(spyCalls == 1, "should be called once")

	setA(10)
	setB(20)
	assert(spyCalls == 1, "should be called once")
end)

test("should block tracking even when run inside effect run inside untracked", function()
	local s, setS = signal(1)
	local spyCalls = 0

	untracked(function()
		effect(function()
			untracked(function()
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
		untracked(function()
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
		return untracked(function()
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

test("should track outside untracked", function()
	local a, setA = signal(1)
	local b, setB = signal(2)
	local c, setC = signal(3)
	local spyCalls = 0

	effect(function()
		a()
		untracked(c)
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

test("should stack untracked", function()
	local a, setA = signal(1)
	local spyCalls = 0

	effect(function()
		untracked(function()
			untracked(a)
			return a()
		end)
		spyCalls += 1
	end)

	assert(spyCalls == 1, "should be called once")
	setA(2)
	assert(spyCalls == 1, "should not be called twice")
end)

return {}
