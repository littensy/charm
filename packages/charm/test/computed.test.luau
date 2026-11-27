local Charm = require("../src")
local test = require("../../../tests/test")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local signal = Charm.signal

test("should correctly propagate changes through computed core", function()
	local src, setSrc = signal(0)
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
	setSrc(1) -- c1 -> dirty, c2 -> toCheckDirty, c3 -> toCheckDirty
	c2() -- c1 -> none, c2 -> none
	setSrc(3) -- c1 -> dirty, c2 -> toCheckDirty

	assert(c3() == 1, "bad final value")
end)

test("should propagate updated source value through chained computations", function()
	local src, setSrc = signal(0)
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
	setSrc(2)
	assert(d() == 2, "bad updated value")
end)

test("should handle flags are indirectly updated during checkDirty", function()
	local a, setA = signal(false)
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
	setA(true)
	assert(d() == true, "bad updated value")
end)

test("should not update if the signal value is reverted", function()
	local times = 0

	local src, setSrc = signal(0)
	local c1 = computed(function()
		times += 1
		return src()
	end)
	c1()
	assert(times == 1, "computed did not run")
	setSrc(1)
	setSrc(0)
	c1()
	assert(times == 1, "computed ran when it should not")
end)

test("should receive previous value", function()
	local calls = {}
	local src, setSrc = signal(0)
	local c1 = computed(function(current: number?): number
		local incoming = src()
		return if current == incoming or incoming % 2 == 1 then current or incoming else incoming
	end)

	effect(function()
		table.insert(calls, c1())
	end)

	setSrc(2)
	setSrc(3)
	assert(c1() == 2, "should skip odd value")

	setSrc(4)
	setSrc(5)
	assert(c1() == 4, "should skip odd value")
	assert(table.concat(calls) == "024", `should only call on even updates, got {table.concat(calls)}`)
end)

-- https://github.com/vuejs/core/blob/minor/packages/reactivity/__tests__/computed.spec.ts#L528
test("should not override queried MaybeDirty result", function()
	local v1 = atom(nil :: any)
	local v2 = atom(false)
	local c1 = computed(function()
		local c = v1()
		if not v1() then
			c = { v = atom(0) }
			v1(c)
		end
		return c.v()
	end)
	local c2 = computed(function()
		if not v2() then
			return "no"
		end
		return if c1() then "yes" else "no"
	end)
	local c3 = computed(function()
		return c2()
	end)

	c3()
	v2(true)

	c3()
	v1().v(999)

	assert(c3() == "yes", "should return correct value after update")
end)

test("should handle inner effect clearing outer computed's deps on rerun", function()
	local src, setSrc = signal(false)
	local stopEffect: () -> ()
	local c = computed(function()
		src()
		effect(function()
			return function()
				stopEffect()
			end
		end)
		effect(function() end)
		return 0
	end)
	stopEffect = effect(function()
		c()
	end)
	setSrc(true)
end)

test("consecutive inner resets through computed chain", function()
	local s = atom(0)
	local c = computed(function()
		return s()
	end)
	local calls = {}

	effect(function()
		table.insert(calls, c())
		if c() > 0 then
			s(0)
		end
	end)

	assert(table.concat(calls) == "0", "bad initial runs")
	s(1)
	assert(s() == 0, "bad s value")
	assert(table.concat(calls) == "010", `bad runs after s(1), got {table.concat(calls)}`)
	s(2)
	assert(s() == 0, "bad s value")
	assert(table.concat(calls) == "01020", `bad runs after s(2), got {table.concat(calls)}`)
	s(3)
	assert(s() == 0, "bad s value")
	assert(table.concat(calls) == "0102030", `bad runs after s(3), got {table.concat(calls)}`)
end)

test("should recover from error on init", function()
	local a, setA = Charm.signal(1)
	local shouldFail = true

	local c = Charm.computed(function()
		if shouldFail then
			error("boom", 0)
		end
		return a() * 2
	end)

	assert(not pcall(c), "initial call should fail")
	shouldFail = false
	assert(c() == 2, "should succeed after error recovery")
	setA(5)
	assert(c() == 10, "should succeed after update")
end)

test("should recover from error on update", function()
	local e, setE = Charm.signal(1)
	local c3 = Charm.computed(function()
		local v = e()
		if v == 2 then
			error("boom", 0)
		end
		return v * 10
	end)

	assert(c3() == 10, "initial call should succeed")
	setE(2)
	assert(not pcall(c3), "should fail after e updates to 2")
	assert(not pcall(c3), "should fail after trying again with e still 2")
	setE(3)
	assert(c3() == 30, "should recover and return 30 after error")
end)

return {}
