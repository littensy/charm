local core = require("../../core")
local suite = require("../../../../../test/suite")

local atom = core.atom
local effect = core.effect
local test = suite.test

test("should accept equality function", function()
	local calls = {}
	local src = atom(0, function(current, incoming)
		return current == incoming or incoming % 2 == 1
	end)

	effect(function()
		table.insert(calls, src())
	end)

	src(2)
	src(3)
	assert(src() == 2, "should skip odd value")

	src(4)
	src(5)
	assert(src() == 4, "should skip odd value")
	assert(table.concat(calls) == "024", `should only call on even updates, got {table.concat(calls)}`)
end)

test("should enforce immutability", function()
	local src = atom({ nested = {} })
	assert(not pcall(function()
		src().nested.a = 1
	end), "should not allow mutation of initial value")

	src({ nested = { a = 1 } })
	assert(not pcall(function()
		src().nested.a = 2
	end), "should not allow mutation of new value")
end)

return {}
