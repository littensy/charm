local Charm = require("../")
local suite = require("../../../../test/suite")

local atom = Charm.atom
local mapped = Charm.mapped
local test = suite.test

test("should map atom", function()
	local src = atom({ 1, 2, 3 })
	local map = mapped(src, function(value: number)
		return value + 1
	end)

	assert(table.concat(map()) == "234", table.concat(map()))
	src({ 4, 5, 6 })
	assert(table.concat(map()) == "567", table.concat(map()))
end)

test("should not map unchanged values", function()
	local calls = 0

	local src = atom({ 1, 2, 3 })
	local map = mapped(src, function(value: number)
		calls += 1
		return value + 1
	end)

	assert(table.concat(map()) == "234", table.concat(map()))
	assert(calls == 3, "should map 3 values")

	src({ 1, 3, 3 })
	assert(table.concat(map()) == "244", table.concat(map()))
	assert(calls == 4, "should map 1 change")

	src({})
	assert(#map() == 0, "should be empty")
	assert(calls == 4, "should not map for removed values")
end)

test("should not update if no values change", function()
	local calls = 0

	local src = atom({ 1, 2, 3 })
	local map = mapped(src, function(value: number)
		calls += 1
		return value + 1
	end)

	local prev = map()
	assert(calls == 3, "should map 3 values")
	assert(table.concat(map()) == "234", table.concat(map()))

	src({ 4, 5, 6, 7 })
	src({ 1, 2, 3 })
	map()
	assert(calls == 3, "should not map unchanged values")
	assert(table.concat(map()) == "234", table.concat(map()))
	assert(prev == map(), "should not create new table")
end)

test("should filter values", function()
	local calls = 0

	local src = atom({ a = 1, b = 2, c = 3 })
	local map = mapped(src, function(value: number)
		calls += 1
		return if value < 0 then nil else value
	end)

	local state = map()
	assert(calls == 3, "should map 3 values")
	assert(state.a and state.b and state.c, "should map all values")

	calls = 0
	src({ a = -1, b = 2, c = 3, d = 4 })
	state = map()
	assert(calls == 2, "should map 2 values")
	assert(state.a == nil, "should remove a")
	assert(state.b and state.c, "should keep b and c")
	assert(state.d == 4, "should add d")
end)

test("should map keys", function()
	local calls = 0

	local src = atom({ a = 1, b = 2, c = 3 })
	local map = mapped(src, function(value: number, key: string)
		calls += 1
		return if value < 0 then nil else value, string.upper(key)
	end)

	local state = map()
	assert(calls == 3, "should map 3 values")
	assert(not (state.a and state.b and state.c), "should discard old keys")
	assert(state.A == 1, "should map a")
	assert(state.B == 2, "should map b")
	assert(state.C == 3, "should map c")

	calls = 0
	src({ a = -1, b = 2, c = 3, d = 4 })
	state = map()
	assert(calls == 2, "should map 2 values")
	assert(state.A == nil and state.a == nil, "should remove a")
	assert(state.B and state.C, "should keep b and c")
	assert(state.D == 4, "should add d")
end)

return {}
