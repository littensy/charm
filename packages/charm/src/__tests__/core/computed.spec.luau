local core = require("../../core")
local suite = require("../../../../../test/suite")

local atom = core.atom
local computed = core.computed
local effect = core.effect
local test = suite.test

test("should correctly propagate changes through computed core", function()
	local src = atom(0)
	local c1 = computed(function()
		return src() % 2
	end)
	local c2 = computed(function()
		return c1()
	end)
	local c3 = computed(function()
		return c2()
	end)

	c3()
	src(1) -- c1 -> dirty, c2 -> toCheckDirty, c3 -> toCheckDirty
	c2() -- c1 -> none, c2 -> none
	src(3) -- c1 -> dirty, c2 -> toCheckDirty

	assert(c3() == 1, "bad final value")
end)

test("should propagate updated source value through chained computations", function()
	local src = atom(0)
	local a = computed(function()
		return src()
	end)
	local b = computed(function()
		return a() % 2
	end)
	local c = computed(function()
		return src()
	end)
	local d = computed(function()
		return b() + c()
	end)

	assert(d() == 0, "bad initial value")
	src(2)
	assert(d() == 2, "bad updated value")
end)

test("should handle flags are indirectly updated during checkDirty", function()
	local a = atom(false)
	local b = computed(function()
		return a()
	end)
	local c = computed(function()
		b()
		return 0
	end)
	local d = computed(function()
		c()
		return b()
	end)

	assert(d() == false, "bad initial value")
	a(true)
	assert(d() == true, "bad updated value")
end)

test("should not update if the atom value is reverted", function()
	local times = 0

	local src = atom(0)
	local c1 = computed(function()
		times += 1
		return src()
	end)
	c1()
	assert(times == 1, "computed did not run")
	src(1)
	src(0)
	c1()
	assert(times == 1, "computed ran when it should not")
end)

test("should accept equality function", function()
	local calls = {}
	local src = atom(0)
	local c1 = computed(function()
		return src()
	end, function(current, incoming)
		return current == incoming or incoming % 2 == 1
	end)

	effect(function()
		table.insert(calls, c1())
	end)

	src(2)
	src(3)
	assert(c1() == 2, "should skip odd value")

	src(4)
	src(5)
	assert(c1() == 4, "should skip odd value")
	assert(table.concat(calls) == "024", `should only call on even updates, got {table.concat(calls)}`)
end)

return {}
