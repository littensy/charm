local config = require("../config")
local patch = require("../patch")
local suite = require("../../../../test/suite")

local test = suite.test
local afterEach = suite.afterEach

local function mockArraySerdes(object: {}): {}
	if object[1] then
		local copy = {}
		for index = 1, #object do
			copy[index] = object[index]
		end
		return copy
	elseif table.maxn(object) ~= #object then
		local copy = {}
		for key, value in object do
			copy[tostring(key)] = value
		end
		return copy
	else
		return object
	end
end

afterEach(function()
	config.fixArrays = true
	config.validatePatches = true
end)

test("returns a patch", function()
	local prevState = { foo = "bar", baz = "qux" }
	local nextState = { foo = "bar", baz = "quux" }
	local diffs = patch.diff(prevState, nextState)

	assert(diffs ~= nil, "should return a patch")
	assert(diffs.baz == "quux", "should return the changed value")
	assert(diffs.foo == nil, "should omit unchanged values")
end)

test("applies a patch", function()
	local prevState = { foo = "bar", baz = "qux" }
	local diffs = { baz = "quux", qaz = "qux" }
	local applied = patch.apply(prevState, diffs)

	assert(applied ~= nil, "should return a new state")
	assert(applied.baz == "quux", "should apply the changed value")
	assert(applied.foo == "bar", "should keep the unchanged value")
	assert(applied.qaz == "qux", "should add the new value")
end)

test("allows nested diffs", function()
	local prevState = { foo = { bar = "baz" } }
	local nextState = { foo = { bar = "qux" } }
	local diffs = patch.diff(prevState, nextState)
	local applied = patch.apply(prevState, diffs)

	assert(applied.foo.bar == "qux", "should apply the nested patch")
end)

test("preserves array density when applying", function()
	local prevState = { "a", "b", "c", "d" }
	local nextState = { ["2"] = "B", ["4"] = "D" }
	local applied = patch.apply(prevState, nextState)

	assert(applied[1] == "a", "should keep a")
	assert(applied[2] == "B", "should apply B")
	assert(applied[3] == "c", "should keep c")
	assert(applied[4] == "D", "should apply D")

	assert(applied["2"] == nil, "should convert serialized arrays to use numbers")
	assert(applied["4"] == nil, "should convert serialized arrays to use numbers")
end)

test("preserves array density after serdes", function()
	-- This particular change results in a patch that cannot be serialized
	-- without losing information. Charm resolves this issue internally.
	local prevState = { "a", "b", "c", "d", "e" }
	local nextState = { "A", "b", "c", "D" }

	local diffs = mockArraySerdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, diffs)

	for index in prevState do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end

	for index in applied do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end
end)

test("cannot preserve sparse arrays", function()
	config.validatePatches = false

	local prevState = {}
	local nextState = { [2] = "foo" }

	local diffs = mockArraySerdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, diffs)

	-- Not enough information is available to determine whether 'diffs'
	-- should keep the string keys added during remote event serialization.
	assert(applied["2"] ~= nil, "will fail to convert string keys to numbers")
	assert(applied[2] == nil, "will fail to convert string keys to numbers")
end)

test("optionally fixes sparse arrays", function()
	config.fixArrays = true

	for index in patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }) do
		assert(type(index) == "string", `expected {type(index)} {index} to be string`)
	end

	config.fixArrays = false

	for index in patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }) do
		assert(type(index) == "number", `expected {type(index)} {index} to be number`)
	end
end)

test("patches mutable state", function()
	local targetState: { [string]: string } = { foo = "bar", baz = "qux" }
	patch.applyMutable(targetState, { baz = "quux", qaz = "qux" })
	assert(targetState.baz == "quux", "should apply the changed value")
	assert(targetState.foo == "bar", "should keep the unchanged value")
	assert(targetState.qaz == "qux", "should add the new value")
end)

test("removes table from mutable state", function()
	local targetState = { foo = { bar = "baz" } }
	patch.applyMutable(targetState, { foo = { __none = "__none" } })
	assert(targetState.foo == nil, "should remove the table")
end)

return {}
