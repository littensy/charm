local Charm = require("../")
local suite = require("../../../../test/suite")

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local observe = Charm.observe
local test = suite.test

test("should observe items", function()
	local items, setItems = signal({ 0, 0, 0 })
	local updates = {}
	local cleanups = {}

	observe(items, function(_, key)
		local get = computed(function()
			return items()[key]
		end)

		effect(function()
			table.insert(updates, get())
		end)

		return function()
			table.insert(cleanups, key)
		end
	end)

	assert(table.concat(updates) == "000", `bad mount: {table.concat(updates)}`)

	table.clear(updates)
	setItems({ 1, 2, 3 })
	assert(table.concat(updates) == "123", `bad update: {table.concat(updates)}`)

	table.clear(updates)
	setItems({ 1, 2, nil :: any, 4 })
	assert(table.concat(updates) == "4", `should add 4: {table.concat(updates)}`)
	assert(table.concat(cleanups) == "3", `bad cleanup: {table.concat(cleanups)}`)
end)

test("should dispose scopes", function()
	local items, setItems = signal({ 1, 2, 3 })
	local a, setA = signal(0)
	local runs = {}

	local dispose = observe(items, function(item)
		effect(function()
			table.insert(runs, item)
			a()
		end)
	end)

	table.clear(runs)
	setItems({ 1, 2 })
	setA(1)
	assert(table.concat(runs) == "12", `bad reruns: {table.concat(runs)}`)

	table.clear(runs)
	dispose()
	setA(2)
	assert(table.concat(runs) == "", `should not rerun: {table.concat(runs)}`)
end)

test("should queue addition", function()
	local items, setItems = signal({ 1 })
	local edits = {}

	observe(items, function(item)
		setItems({ 1, 2 })
		setItems({ 1, 2, 3, 4 })
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	assert(table.concat(edits) == "+1+2+3+4", `bad edits: {table.concat(edits)}`)
end)

test("should queue removal", function()
	local items, setItems = signal({ 1, 2, 3, 4 })
	local edits = {}

	observe(items, function(item)
		setItems({ 1, 2, 3 })
		setItems({ 1 })
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	assert(table.concat(edits) == "+1+2+3+4-2-3-4", `bad edits: {table.concat(edits)}`)
end)

return {}
