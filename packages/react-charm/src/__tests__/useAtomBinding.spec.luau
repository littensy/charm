local Charm = require("../../Charm")
local ReactCharm = require("../")
local renderHook = require("./helpers/renderHook")
local suite = require("../../../../test/suite")

local atom = Charm.atom
local useAtomBinding = ReactCharm.useAtomBinding
local test = suite.test

test("tracks atom state", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtomBinding(state)
	end)
	assert(hook.result:getValue() == 0, "should return 0")
	state(1)
	assert(hook.result:getValue() == 1, "should return 1")
end)

test("accepts a selector", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtomBinding(function()
			return 2 * state()
		end)
	end)
	assert(hook.result:getValue() == 0, "should return 0")
	state(1)
	assert(hook.result:getValue() == 2, "should return 2")
end)

test("tracks dependencies", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtomBinding(state, { state })
	end)
	assert(hook.result:getValue() == 0, "should return 0")
	state(1)
	assert(hook.result:getValue() == 1, "should return 1")
	state = atom(0)
	hook.rerender()
	assert(hook.result:getValue() == 0, "should return 0")
	state(1)
	assert(hook.result:getValue() == 1, "should return 1")
end)

return {}
