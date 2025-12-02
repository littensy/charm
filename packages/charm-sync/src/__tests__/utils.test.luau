local Charm = require("../../Charm")
local test = require("../../../../tests/test")
local utils = require("../utils")

test("should flatten functions", function()
	local input = {
		a = Charm.atom(0),
		b = { c = Charm.atom(0) },
		d = { e = { f = utils.signalToAtom(Charm.signal(0)) } },
	}
	local result = utils.flatten(input)

	assert(result.a == input.a, "should flatten the first level")
	assert(result["b/c"] == input.b.c, "should flatten the second level")
	assert(result["d/e/f"] == input.d.e.f, "should flatten the third level")

	assert(result.b == nil, "should remove the original nested tables")
	assert(result.d == nil, "should remove the original nested tables")
end)

return {}
