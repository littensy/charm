local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local effect = Charm.effect

test("should accept equality function", function()
	local calls = {}
	local src, setSrc = signal(0, function(current: number, incoming: number)
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

test("should not freeze values with metatables", function()
	local src = signal({ object = setmetatable({}, {}) })
	assert(
		pcall(function()
			src().object.a = 2
		end),
		"should allow mutation of values with metatables"
	)
end)

return {}
