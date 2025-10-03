local Charm = require("../../Charm")
local Vide = require("../../Vide")
local VideCharm = require("../")
local suite = require("../../../../test/suite")

local test = suite.test

test("tracks atom state", function()
	local state = Charm.atom(0)
	local source
	local cleanup = Vide.root(function()
		source = VideCharm.useAtom(state)
	end)
	assert(source() == 0, "should return 0")
	state(1)
	assert(source() == 1, "should return 1")
	cleanup()
end)

test("accepts a selector", function()
	local state = Charm.atom(0)
	local source
	local cleanup = Vide.root(function()
		source = VideCharm.useAtom(function()
			return 2 * state()
		end)
	end)
	assert(source() == 0, "should return 0")
	state(1)
	assert(source() == 2, "should return 2")
	cleanup()
end)

test("updates source in untracked", function()
	local outerAtom = Charm.atom(nil :: any)
	local innerAtom = Charm.atom(0)
	local spyCalls = 0
	local cleanup = Vide.root(function()
		return Vide.show(VideCharm.useAtom(outerAtom), function()
			-- Charm effects created in Vide scopes triggered by useAtom might
			-- incorrectly get treated as an inner effect in useAtom. This test
			-- ensures that doesn't happen.
			Vide.cleanup(Charm.effect(function()
				innerAtom()
				spyCalls += 1
			end))
			return nil
		end)
	end)
	assert(spyCalls == 0, "should not call spy initially")
	outerAtom(true)
	assert(spyCalls == 1, "should call spy when visible")
	innerAtom(1)
	assert(spyCalls == 2, "spy should run when counter updates")
	outerAtom({}) -- set to a truthy value to trigger an outer effect re-run
	innerAtom(2)
	assert(spyCalls == 3, "spy should still run when counter updates")
	cleanup()
end)

return {}
