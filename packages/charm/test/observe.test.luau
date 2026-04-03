local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local effectScope = Charm.effectScope
local observe = Charm.observe

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
	local disposes = {}

	local dispose = observe(items, function(item)
		effect(function()
			table.insert(runs, item)
			a()
		end)
		effectScope(function()
			return function()
				table.insert(disposes, item)
			end
		end)
	end)

	table.clear(runs)
	setItems({ 1, 2 })
	setA(1)
	assert(table.concat(runs) == "12", `bad reruns: {table.concat(runs)}`)
	assert(table.concat(disposes) == "3", `should dispose 3: {table.concat(disposes)}`)

	table.clear(runs)
	table.clear(disposes)
	dispose()
	setA(2)
	assert(table.concat(runs) == "", `should not rerun: {table.concat(runs)}`)
	assert(table.concat(disposes) == "12", `should dispose 1 and 2: {table.concat(disposes)}`)
end)

test("should queue addition and removal", function()
	local items, setItems = signal({ 1 })
	local edits = {}

	observe(items, function(item)
		if item == 1 then
			setItems({ 1, 2, 3, 4 })
		elseif item == 4 then
			setItems({ 1 })
		end
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	assert(table.concat(edits) == "+1+2+3+4-2-3-4", `bad edits: {table.concat(edits)}`)
end)

test("should handle recursive additions and removals", function()
	local items, setItems = signal({ 1 })
	local edits: { string } = {}

	observe(items, function(item)
		if item < 5 then
			setItems(function(state: { number })
				state = table.clone(state)
				table.insert(state, item + 1)
				return state
			end)
		else
			setItems({})
		end
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	assert(table.concat(edits) == "+1+2+3+4+5-1-2-3-4-5", `bad edits: {table.concat(edits)}`)
end)

test("should handle self removal", function()
	local items, setItems = signal({ 1, 2, 3, 4 })
	local edits: { string } = {}

	observe(items, function(item, index)
		setItems(function(state: { number })
			state = table.clone(state)
			state[index] = nil
			return state
		end)
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	assert(table.concat(edits) == "+1+2+3+4-1-2-3-4", `bad edits: {table.concat(edits)}`)
end)

test("should allow disposal during addition", function()
	local items, setItems = signal({})
	local edits = {}
	local dispose: () -> ()

	dispose = observe(items, function(item)
		if item == 1 then
			dispose()
		end
		table.insert(edits, `+{item}`)
		return function()
			table.insert(edits, `-{item}`)
		end
	end)

	setItems({ 1, 2, 3, 4 })
	assert(table.concat(edits) == "+1-1", `bad edits: {table.concat(edits)}`)
end)

test("should allow disposal during removal", function()
	local items, setItems = signal({ 1, 2, 3, 4 })
	local edits = {}
	local dispose: () -> ()

	dispose = observe(items, function(item)
		table.insert(edits, `+{item}`)
		return function()
			dispose()
			table.insert(edits, `-{item}`)
		end
	end)

	setItems({ 1, 2, 3, nil :: any, 5 })
	assert(table.concat(edits) == "+1+2+3+4-1-2-3-4", `bad edits: {table.concat(edits)}`)
end)

return {}
