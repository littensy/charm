local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local renderHook = require(script.Parent.helpers.renderHook)
local suite = require(ServerScriptService.Tests.suite)

local atom = Charm.atom
local useAtom = ReactCharm.useAtom
local test = suite.test

test("tracks atom state", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtom(state)
	end)
	assert(hook.result == 0)
	state(1)
	assert(hook.result == 1)
end)

test("accepts a selector", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtom(function()
			return 2 * state()
		end)
	end)
	assert(hook.result == 0)
	state(1)
	assert(hook.result == 2)
end)

test("tracks dependencies", function()
	local state = atom(0)
	local hook = renderHook(function()
		return useAtom(state, { state })
	end)
	assert(hook.result == 0)
	state(1)
	assert(hook.result == 1)
	state = atom(0)
	hook.rerender()
	assert(hook.result == 0)
	state(1)
	assert(hook.result == 1)
end)

return {}
