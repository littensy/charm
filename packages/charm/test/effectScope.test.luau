local Charm = require("../src")
local test = require("../../../tests/test")

local effect = Charm.effect
local effectScope = Charm.effectScope
local signal = Charm.signal
local onCleanup = Charm.onCleanup

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

	local a, setA = signal(false)
	local stopScope = effectScope(function()
		effect(function()
			a()
			onCleanup(function()
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

test("should dispose inner effects if created in an effect", function()
	local source, setSource = signal(1)
	local triggers = 0
	local dispose

	effect(function()
		dispose = effectScope(function()
			effect(function()
				source()
				triggers += 1
			end)
		end)
		assert(triggers == 1, "did not run initially")
	end)

	setSource(2)
	assert(triggers == 2, "did not run after update")
	dispose()
	setSource(3)
	assert(triggers == 2, "ran after dispose")
end)

test("should disallow yielding", function()
	local success = pcall(function()
		effectScope(function()
			coroutine.yield()
		end)
	end)
	assert(not success, "should error on yield")
end)

return {}
