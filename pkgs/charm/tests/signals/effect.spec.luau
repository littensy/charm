local signals = require("../../src/signals")
local suite = require("@test/suite")

local computed = signals.computed
local effect = signals.effect
local effectScope = signals.effectScope
local endBatch = signals.endBatch
local setCurrentSub = signals.setCurrentSub
local onEffectCleanup = signals.onEffectCleanup
local signal = signals.signal
local startBatch = signals.startBatch
local test = suite.test

test("should clear subscriptions when untracked by all subscribers", function()
	local bRunTimes = 0

	local a, setA = signal(1)
	local b = computed(function()
		bRunTimes += 1
		return a() * 2
	end)
	local stopEffect = effect(function()
		b()
	end)

	assert(bRunTimes == 1, "should run initially")
	setA(2)
	assert(bRunTimes == 2, "should run after change")
	stopEffect()
	setA(3)
	assert(bRunTimes == 2, "should not run after stop")
end)

test("should not run untracked inner effect", function()
	local a, setA = signal(3)
	local b = computed(function()
		return a() > 0
	end)

	effect(function()
		if b() then
			effect(function()
				if a() == 0 then
					error("bad")
				end
			end)
		end
	end)

	setA(2)
	setA(1)
	setA(0)
end)

test("should run outer effect first", function()
	local a, setA = signal(1)
	local b, setB = signal(1)

	effect(function()
		if a() > 0 then
			effect(function()
				b()
				if a() == 0 then
					error("bad")
				end
			end)
		end
	end)

	startBatch()
	setB(0)
	setA(0)
	endBatch()
end)

test("should not trigger inner effect when resolve maybe dirty", function()
	local a, setA = signal(0)
	local b = computed(function()
		return a() % 2
	end)

	local innerTriggerTimes = 0

	effect(function()
		effect(function()
			b()
			innerTriggerTimes += 1
			if innerTriggerTimes >= 2 then
				error("bad")
			end
		end)
	end)

	setA(2)
end)

test("should trigger inner effects in sequence", function()
	local a, setA = signal(0)
	local b, setB = signal(0)
	local c = computed(function()
		return a() - b()
	end)
	local order: { string } = {}

	effect(function()
		c()

		effect(function()
			table.insert(order, "first inner")
			a()
		end)

		effect(function()
			table.insert(order, "last inner")
			a()
			b()
		end)
	end)

	table.clear(order)

	startBatch()
	setB(1)
	setA(1)
	endBatch()

	assert(table.concat(order, ", ") == "first inner, last inner", `wrong order: {table.concat(order, ", ")}`)
end)

test("should trigger inner effects in sequence in effect scope", function()
	local a, setA = signal(0)
	local b, setB = signal(0)
	local order: { string } = {}

	effectScope(function()
		effect(function()
			table.insert(order, "first inner")
			a()
		end)

		effect(function()
			table.insert(order, "last inner")
			a()
			b()
		end)
	end)

	table.clear(order)

	startBatch()
	setB(1)
	setA(1)
	endBatch()

	assert(table.concat(order, ", ") == "first inner, last inner", `wrong order: {table.concat(order, ", ")}`)
end)

test("should custom effect support batch", function()
	local function batchEffect(fn: () -> ())
		return effect(function()
			startBatch()
			local success, result: unknown = pcall(fn)
			endBatch()
			if not success then
				error(result)
			end
		end)
	end

	local logs: { string } = {}
	local a = signal(0)
	local b, setB = signal(0)

	local aa = computed(function()
		table.insert(logs, "aa-0")
		if a() == 0 then
			setB(1)
		end
		table.insert(logs, "aa-1")
		return nil
	end)

	local bb = computed(function()
		table.insert(logs, "bb")
		return b()
	end)

	batchEffect(function()
		bb()
	end)
	batchEffect(function()
		aa()
	end)

	assert(table.concat(logs, ", ") == "bb, aa-0, aa-1, bb", `wrong order: {table.concat(logs, ", ")}`)
end)

test("should duplicate subscribers do not affect the notify order", function()
	local src1, setSrc1 = signal(0)
	local src2, setSrc2 = signal(0)
	local order: { string } = {}

	effect(function()
		table.insert(order, "a")
		local currentSub = setCurrentSub(nil)
		local isOne = src2() == 1
		setCurrentSub(currentSub)
		if isOne then
			src1()
		end
		src2()
		src1()
	end)
	effect(function()
		table.insert(order, "b")
		src1()
	end)
	setSrc2(1) -- src1.subs: a -> b -> a

	table.clear(order)
	setSrc1(src1() + 1)

	assert(table.concat(order) == "ab", `wrong order: {table.concat(order)}`)
end)

test("should handle side effect with inner effects", function()
	local a, setA = signal(0)
	local b, setB = signal(0)
	local order: { string } = {}

	effect(function()
		effect(function()
			a()
			table.insert(order, "a")
		end)
		effect(function()
			b()
			table.insert(order, "b")
		end)
		assert(table.concat(order) == "ab", `wrong order: {table.concat(order)}`)

		table.clear(order)
		setB(1)
		setA(1)
		assert(table.concat(order) == "ba", `wrong order: {table.concat(order)}`)
	end)
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

	local triggers = 0

	effect(function()
		d()
		triggers += 1
	end)
	assert(triggers == 1, "did not run initially")
	setA(true)
	assert(triggers == 2, "did not update indirectly")
end)

test("should run cleanups in sequence", function()
	local order = {}

	local a, setA = signal(false)
	local stopEffect = effect(function()
		a()
		onEffectCleanup(function()
			table.insert(order, "a")
		end)
		onEffectCleanup(function()
			table.insert(order, "b")
		end)
	end)

	assert(table.concat(order) == "", "should not cleanup immediately")

	setA(true)
	assert(table.concat(order) == "ab", `bad update: {table.concat(order)}`)

	table.clear(order)
	stopEffect()
	assert(table.concat(order) == "ab", `bad dispose: {table.concat(order)}`)

	table.clear(order)
	setA(false)
	assert(table.concat(order) == "", "should not cleanup after update")
end)

test("should run inner effect cleanup", function()
	local cleanups = 0

	local src, setSrc = signal(false)
	local stopEffect = effect(function()
		src()
		effect(function()
			onEffectCleanup(function()
				cleanups += 1
			end)
		end)
		effect(function()
			onEffectCleanup(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	setSrc(true)
	assert(cleanups == 2, "should cleanup after outer update")
	stopEffect()
	assert(cleanups == 4, "should cleanup after outer dispose")
	setSrc(false)
	assert(cleanups == 4, "should not cleanup after update")
end)

return {}
