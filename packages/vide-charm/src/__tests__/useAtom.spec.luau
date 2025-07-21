local Charm = require("../../Charm")
local Vide = require("../../Vide")
local VideCharm = require("../")
local suite = require("../../../../test/suite")

local atom = Charm.atom
local root = Vide.root
local useAtom = VideCharm.useAtom
local test = suite.test

test("tracks atom state", function()
	local state = atom(0)
	local source
	local cleanup = root(function()
		source = useAtom(state)
	end)
	assert(source() == 0, "should return 0")
	state(1)
	assert(source() == 1, "should return 1")
	cleanup()
end)

test("accepts a selector", function()
	local state = atom(0)
	local source
	local cleanup = root(function()
		source = useAtom(function()
			return 2 * state()
		end)
	end)
	assert(source() == 0, "should return 0")
	state(1)
	assert(source() == 2, "should return 2")
	cleanup()
end)

return {}
