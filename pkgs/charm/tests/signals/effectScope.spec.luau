local signals = require("../../src/signals")
local suite = require("@test/suite")

local effect = signals.effect
local effectScope = signals.effectScope
local signal = signals.signal
local onEffectCleanup = signals.onEffectCleanup
local onScopeDispose = signals.onScopeDispose
local test = suite.test

test("should not trigger after stop", function()
	local count, setCount = signal(1)

	local triggers = 0

	local stopScope = effectScope(function()
		effect(function()
			triggers += 1
			count()
		end)
		assert(triggers == 1, "did not run initially")

		setCount(2)
		assert(triggers == 2, "did not run after update")
	end)

	setCount(3)
	assert(triggers == 3, "did not run after update outside scope")
	stopScope()
	setCount(4)
	assert(triggers == 3, "ran after stop")
end)

test("should run indirect scope cleanup", function()
	local cleanups = 0

	local cleanup
	local stopScope = effectScope(function()
		cleanup = effectScope(function()
			onScopeDispose(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	stopScope()
	assert(cleanups == 1, "should cleanup from parent dispose")
	cleanup()
	assert(cleanups == 1, "should skip redundant dispose")
end)

test("should run indirect effect cleanup", function()
	local cleanups = 0

	local a, setA = signal(false)
	local stopScope = effectScope(function()
		effect(function()
			a()
			onEffectCleanup(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	setA(true)
	assert(cleanups == 1, "should cleanup once")
	stopScope()
	assert(cleanups == 2, "should cleanup after outer dispose")
	setA(false)
	assert(cleanups == 2, "should not cleanup after update")
end)

return {}
