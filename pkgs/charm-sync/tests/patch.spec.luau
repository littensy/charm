local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local suite = require(ServerScriptService.Tests.suite)

local patch = CharmSync.patch
local test = suite.test

local function serdes(value: { [any]: any })
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

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

	local patches = serdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, patches)

	for index in next, prevState do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end

	for index in next, applied do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end
end)

test("preserves large gaps between keys", function()
	local prevState = table.create(10000, "foo")
	local nextState = table.move(prevState, 2, 9998, 2, { [1] = "bar", [9999] = "bar" })

	local start = os.clock()

	local patches = serdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, patches)

	assert(os.clock() - start < 10e-3, `Performance is not acceptable ({(os.clock() - start) * 1e3}ms)`)

	for index in next, prevState do
		assert(applied[index] == nextState[index], `expected {applied[index]} to be {nextState[index]}`)
	end
end)

test("cannot preserve sparse arrays", function()
	local prevState = {}
	local nextState = { [2] = "foo" }

	local patches = serdes(patch.diff(prevState, nextState))
	local applied = patch.apply(prevState, patches)

	-- Not enough information is available to determine whether 'patches'
	-- should keep the string keys added during remote event serialization.
	assert(applied["2"] ~= nil, "will fail to convert string keys to numbers")
	assert(applied[2] == nil, "will fail to convert string keys to numbers")
end)

test("optionally fixes sparse arrays", function()
	for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }, true) do
		assert(type(index) == "string", `expected {type(index)} {index} to be string`)
	end

	for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }, false) do
		assert(type(index) == "number", `expected {type(index)} {index} to be number`)
	end
end)

test("optionally validates state", function()
	local success = pcall(function()
		patch.diff({}, { [0.1] = true }, true)
	end)

	assert(not success, "should not allow non-integer keys")

	success = pcall(function()
		patch.diff({}, { [0.1] = true }, false)
	end)

	assert(success, "should skip validation if not requested")
end)

return {}
