local Charm = require("../../Charm")
local CharmSync = require("../")
local suite = require("../../../../test/suite")

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

	assert(result.a == input.a, "should flatten the first level")
	assert(result["b/c"] == input.b.c, "should flatten the second level")
	assert(result["d/e/f"] == input.d.e.f, "should flatten the third level")

	assert(result.b == nil, "should remove the original nested tables")
	assert(result.d == nil, "should remove the original nested tables")
end)

return {}
