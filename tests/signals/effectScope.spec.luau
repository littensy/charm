local test = require("../suite").test
local signals = require("../charm").signals

local effect = signals.effect
local effectScope = signals.effectScope
local signal = signals.signal

test("should not trigger after stop", function()
	local count = signal(1)

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

test("should run effect cleanup", function()
	local cleanups = 0

	local cleanup = effectScope(function()
		return function()
			cleanups += 1
		end
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	cleanup()
	assert(cleanups == 1, "should cleanup after effect stop")
	cleanup()
	assert(cleanups == 1, "should skip redundant cleanup")
end)

test("should not run indirect effect cleanup", function()
	local cleanups = 0

	local cleanup
	local stopScope = effectScope(function()
		cleanup = effectScope(function()
			return function()
				cleanups += 1
			end
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	stopScope()
	assert(cleanups == 0, "should be detached from parent dispose")
	cleanup()
	assert(cleanups == 1, "should cleanup after inner dispose")
end)

return {}
