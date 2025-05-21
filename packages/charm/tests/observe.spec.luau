local Charm = require("../src")
local suite = require("@test/suite")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local observe = Charm.observe
local test = suite.test

test("should observe items", function()
	local items = atom({ 0, 0, 0 })
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
	items({ 1, 2, 3 })
	assert(table.concat(updates) == "123", `bad update: {table.concat(updates)}`)

	table.clear(updates)
	items({ 1, 2, nil :: any, 4 })
	assert(table.concat(updates) == "4", `should add 4: {table.concat(updates)}`)
	assert(table.concat(cleanups) == "3", `bad cleanup: {table.concat(cleanups)}`)
end)

test("should dispose scopes", function()
	local items = atom({ 1, 2, 3 })
	local a = atom(0)
	local runs = {}

	local dispose = observe(items, function(item)
		effect(function()
			table.insert(runs, item)
			a()
		end)
	end)

	table.clear(runs)
	items({ 1, 2 })
	a(1)
	assert(table.concat(runs) == "12", `bad reruns: {table.concat(runs)}`)

	table.clear(runs)
	dispose()
	a(2)
	assert(table.concat(runs) == "", `should not rerun: {table.concat(runs)}`)
end)

return {}
