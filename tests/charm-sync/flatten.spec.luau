local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local suite = require(ServerScriptService.Tests.suite)

local atom = Charm.atom
local flatten = CharmSync.flatten
local test = suite.test

test("should flatten atoms", function()
	local input = {
		a = atom(0),
		b = { c = atom(0) },
		d = { e = { f = atom(0) } },
	}
	local result = flatten(input)

	assert(result.a == input.a)
	assert(result["b/c"] == input.b.c)
	assert(result["d/e/f"] == input.d.e.f)

	assert(result.b == nil)
	assert(result.d == nil)
end)

return {}
