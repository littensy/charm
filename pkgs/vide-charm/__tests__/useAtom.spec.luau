local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Vide = require(ReplicatedStorage.Packages.Vide)
local VideCharm = require(ReplicatedStorage.Packages.VideCharm)
local suite = require(ServerScriptService.Tests.suite)

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
	assert(source() == 0)
	state(1)
	assert(source() == 1)
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
	assert(source() == 0)
	state(1)
	assert(source() == 2)
	cleanup()
end)

return {}
