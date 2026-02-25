local Charm = require("../Charm")
local Vide = require("../Vide")
local VideCharm = require("../src")
local test = require("../../../tests/test")

test("tracks signal state", function()
	local getState, setState = Charm.signal(0)
	local source
	local cleanup = Vide.root(function()
		source = VideCharm.useSignalState(getState)
	end)
	assert(source() == 0, "should return 0")
	setState(1)
	assert(source() == 1, "should return 1")
	cleanup()
end)

test("accepts a selector", function()
	local getState, setState = Charm.signal(0)
	local source
	local cleanup = Vide.root(function()
		source = VideCharm.useSignalState(function()
			return 2 * getState()
		end)
	end)
	assert(source() == 0, "should return 0")
	setState(1)
	assert(source() == 2, "should return 2")
	cleanup()
end)

test("updates source in untracked", function()
	local getOuter, setOuter = Charm.signal(nil :: any)
	local getInner, setInner = Charm.signal(0)
	local spyCalls = 0
	local cleanup = Vide.root(function()
		return Vide.show(VideCharm.useSignalState(getOuter), function()
			-- Charm effects created in Vide scopes triggered by useSignalState might
			-- incorrectly get treated as an inner effect in useSignalState. This test
			-- ensures that doesn't happen.
			Vide.cleanup(Charm.effect(function()
				getInner()
				spyCalls += 1
			end))
			return nil
		end)
	end)
	assert(spyCalls == 0, "should not call spy initially")
	setOuter(true)
	assert(spyCalls == 1, "should call spy when visible")
	setInner(1)
	assert(spyCalls == 2, "spy should run when counter updates")
	setOuter({}) -- set to a truthy value to trigger an outer effect re-run
	setInner(2)
	assert(spyCalls == 3, "spy should still run when counter updates")
	cleanup()
end)

return {}
