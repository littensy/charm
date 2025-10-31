local core = require("../../core")
local suite = require("../../../../../test/suite")

local signal = core.signal
local effect = core.effect
local test = suite.test

test("should accept equality function", function()
	local calls = {}
	local src, setSrc = signal(0, function(current, incoming)
		return current == incoming or incoming % 2 == 1
	end)

	effect(function()
		table.insert(calls, src())
	end)

	setSrc(2)
	setSrc(3)
	assert(src() == 2, "should skip odd value")

	setSrc(4)
	setSrc(5)
	assert(src() == 4, "should skip odd value")
	assert(table.concat(calls) == "024", `should only call on even updates, got {table.concat(calls)}`)
end)

test("should enforce immutability", function()
	local src, setSrc = signal({ nested = {} })
	assert(not pcall(function()
		src().nested.a = 1
	end), "should not allow mutation of initial value")

	setSrc({ nested = { a = 1 } })
	assert(not pcall(function()
		src().nested.a = 2
	end), "should not allow mutation of new value")
end)

return {}
