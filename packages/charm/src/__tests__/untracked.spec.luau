local Charm = require("../")
local suite = require("../../../../test/suite")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local untracked = Charm.untracked
local test = suite.test

test("should block tracking inside effects", function()
	local a = atom(1)
	local b = atom(2)
	local spyCalls = 0

	effect(function()
		untracked(function()
			spyCalls += 1
			return a() + b()
		end)
	end)
	assert(spyCalls == 1, "should be called once")

	a(10)
	b(20)
	assert(spyCalls == 1, "should be called once")
end)

test("should block tracking even when run inside effect run inside untracked", function()
	local s = atom(1)
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

	s(2)
	assert(spyCalls == 1, "should be called once")
end)

test("should not cause atom assignments throw", function()
	local a = atom(1)
	local aChangedTime = atom(0)

	local dispose = effect(function()
		a()
		untracked(function()
			aChangedTime(aChangedTime() + 1)
		end)
	end)

	a(2)
	assert(aChangedTime() == 2, "aChangedTime should be 2")
	a(3)
	assert(aChangedTime() == 3, "aChangedTime should be 3")

	dispose()
end)

test("should block tracking inside computed atoms", function()
	local a = atom(1)
	local b = atom(2)
	local spyCalls = 0
	local c = computed(function()
		return untracked(function()
			spyCalls += 1
			return a() + b()
		end)
	end)

	assert(spyCalls == 0, "should not be called yet")
	assert(c() == 3, "c should be 3")
	a(10)
	c()
	b(20)
	c()
	assert(spyCalls == 1, "should be called once")
	assert(c() == 3, "c should be 3")
end)

return {}
