local core = require("../../core")
local suite = require("../../../../../test/suite")

local effect = core.effect
local effectScope = core.effectScope
local atom = core.atom
local onCleanup = core.onCleanup
local test = suite.test

test("should not trigger after stop", function()
	local count = atom(1)

	local triggers = 0

	local stopScope = effectScope(function()
		effect(function()
			triggers += 1
			count()
		end)
		assert(triggers == 1, "did not run initially")

		count(2)
		assert(triggers == 2, "did not run after update")
	end)

	count(3)
	assert(triggers == 3, "did not run after update outside scope")
	stopScope()
	count(4)
	assert(triggers == 3, "ran after stop")
end)

test("should run indirect scope cleanup", function()
	local cleanups = 0

	local cleanup
	local stopScope = effectScope(function()
		cleanup = effectScope(function()
			onCleanup(function()
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

	local a = atom(false)
	local stopScope = effectScope(function()
		effect(function()
			a()
			onCleanup(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	a(true)
	assert(cleanups == 1, "should cleanup once")
	stopScope()
	assert(cleanups == 2, "should cleanup after outer dispose")
	a(false)
	assert(cleanups == 2, "should not cleanup after update")
end)

return {}
