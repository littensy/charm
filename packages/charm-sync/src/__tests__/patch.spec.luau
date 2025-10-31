local config = require("../config")
local patch = require("../patch")
local suite = require("../../../../test/suite")

local test = suite.test
local afterEach = suite.afterEach

local function mockArraySerdes(object: { [any]: any }): { [any]: any }
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
	local patches = patch.diff(prevState, nextState)

	assert(patches ~= nil, "should return a patch")
	assert(patches.baz == "quux", "should return the changed value")
	assert(patches.foo == nil, "should omit unchanged values")
end)

test("applies a patch", function()
	local prevState = { foo = "bar", baz = "qux" }
	local patches = { baz = "quux", qaz = "qux" }
	local applied = patch.apply(prevState, patches)

	assert(applied ~= nil, "should return a new state")
	assert(applied.baz == "quux", "should apply the changed value")
	assert(applied.foo == "bar", "should keep the unchanged value")
	assert(applied.qaz == "qux", "should add the new value")
end)

test("allows nested patches", function()
	local prevState = { foo = { bar = "baz" } }
	local nextState = { foo = { bar = "qux" } }
	local patches = patch.diff(prevState, nextState)
	local applied = patch.apply(prevState, patches)

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

	local patches = mockArraySerdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, patches)

	for index in next, prevState do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end

	for index in next, applied do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end
end)

test("cannot preserve sparse arrays", function()
	local prevState = {}
	local nextState = { [2] = "foo" }

	local patches = mockArraySerdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, patches)

	-- Not enough information is available to determine whether 'patches'
	-- should keep the string keys added during remote event serialization.
	assert(applied["2"] ~= nil, "will fail to convert string keys to numbers")
	assert(applied[2] == nil, "will fail to convert string keys to numbers")
end)

test("optionally fixes sparse arrays", function()
	config.fixArrays = true

	for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }) do
		assert(type(index) == "string", `expected {type(index)} {index} to be string`)
	end

	config.fixArrays = false

	for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }) do
		assert(type(index) == "number", `expected {type(index)} {index} to be number`)
	end
end)

test("optionally validates state", function()
	local success = pcall(function()
		config.validatePatches = true
		patch.diff({}, { [0.1] = true })
	end)

	assert(not success, "should not allow non-integer keys")

	success = pcall(function()
		config.validatePatches = false
		patch.diff({}, { [0.1] = true })
	end)

	assert(success, "should skip validation if not requested")
end)

return {}
