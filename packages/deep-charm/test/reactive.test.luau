local Charm = require("../Charm")
local DeepCharm = require("../src")
local test = require("../../../tests/test")

local batch = Charm.batch
local computed = Charm.computed
local effect = Charm.effect
local observe = Charm.observe
local reactive = DeepCharm.reactive
local toRaw = DeepCharm.toRaw

test("should track nested properties", function()
	local src, setSrc = reactive({ a = { b = { c = 0 } } })
	local calls = {}

	effect(function()
		table.insert(calls, `{src.a.b.c}`)
	end)

	setSrc(function(state)
		state.a.b.c = 1
	end)
	src.a.b.c = 2
	src.a.b.c = 2
	setSrc()
	assert(table.concat(calls) == "012", table.concat(calls))
end)

test("should track object type changes", function()
	local src = reactive({ a = { b = 0 } } :: { a: any })
	local calls = {}

	effect(function()
		table.insert(calls, tostring(if type(src.a) == "table" then src.a.b else src.a))
	end)

	src.a = { b = 0 }
	src.a = 1
	src.a = { b = 2 }
	src.a = nil
	src.a = 3
	assert(table.concat(calls) == "0012nil3", table.concat(calls))
end)

test("should unwrap proxy assignments", function()
	local src = reactive({ a = { x = 0 }, b = { x = 0 } })
	local runs = 0

	effect(function()
		local _, _ = src.a.x, src.b.x
		runs += 1
	end)

	src.a, src.b = src.a, src.b
	assert(runs == 1, `bad runs: {runs}`)

	src.a, src.b = src.b, src.a
	assert(runs == 3, `bad runs: {runs}`)
end)

test("should track iteration", function()
	local src, setSrc = reactive({} :: { [string]: number })
	local calls = {}

	effect(function()
		for key, value in src do
			table.insert(calls, `{key}={value};`)
		end
	end)

	src.a = 1
	assert(table.concat(calls) == "a=1;", table.concat(calls))

	table.clear(calls)
	src.b = 2
	assert(table.concat(calls) == "a=1;b=2;", table.concat(calls))

	table.clear(calls)
	src.a = 2
	assert(table.concat(calls) == "a=2;b=2;", table.concat(calls))

	table.clear(calls)
	setSrc()
	assert(table.concat(calls) == "a=2;b=2;", table.concat(calls))
end)

test("should track iteration for nested tables", function()
	local src = reactive({} :: { [string]: { value: number } })
	local calls = {}

	effect(function()
		for key, obj in src do
			table.insert(calls, `{key}={obj.value};`)
		end
	end)

	src.a = { value = 1 }

	table.clear(calls)
	src.b = { value = 1 }
	assert(table.concat(calls) == "a=1;b=1;", table.concat(calls))

	table.clear(calls)
	src.a.value = 2
	assert(table.concat(calls) == "a=2;b=1;", table.concat(calls))
end)

test("should track array length", function()
	local src = reactive({ array = {} :: { number } })
	local calls = {}

	effect(function()
		table.insert(calls, #src.array)
	end)

	src.array[#src.array + 1] = 1
	src.array[#src.array + 1] = 2
	src.array[#src.array + 1] = 3
	src.array = { 1, 2, 3, 4 }
	assert(table.concat(calls) == "01234", table.concat(calls))
end)

test("should not track unread properties", function()
	local src = reactive({ value = { a = 1, b = 2 } })
	local calls = 0

	effect(function()
		local _ = src.value.a
		calls += 1
	end)
	assert(calls == 1, `bad calls: {calls}`)

	src.value.b = 3
	assert(calls == 1, `bad calls: {calls}`)
end)

test("should overwrite with table passed to setter", function()
	local src, setSrc = reactive({ a = 1, b = 2, c = 3 } :: { [string]: number? })
	local calls = {}

	effect(function()
		table.insert(calls, `{src.a}{src.b}{src.c}`)
	end)

	setSrc(function(src)
		src.a = 2
		src.b = nil
		src.c = 4
	end)
	assert(table.concat(calls, ",") == "123,2nil4", table.concat(calls, ","))
end)

test("should unwrap proxy", function()
	local raw = {}
	local src = reactive(raw)
	local runs = 0

	effect(function()
		local _ = toRaw(src)
		runs += 1
	end)

	assert(toRaw(src) == raw, "unwrap did not return the original table")
	assert(toRaw(raw) == raw, "unwrap modified a non-proxy value")
	assert(runs == 1, `bad runs: {runs}`)

	src.x = 1
	assert(runs == 2, `bad runs: {runs}`)
end)

test("should unwrap nested proxy", function()
	local raw = {}
	local inner = reactive(raw)
	local src = reactive(inner)
	local runs = 0

	effect(function()
		local _ = toRaw(src)
		runs += 1
	end)

	assert(toRaw(src) == raw, "unwrap did not return the original table")
	assert(runs == 1, `bad runs: {runs}`)

	inner.x = 1
	assert(runs == 2, `bad runs: {runs}`)

	src.y = 2
	assert(runs == 3, `bad runs: {runs}`)
end)

test("should observe items", function()
	local items, updateItems = reactive({ 0, 0, 0 })
	local updates = {}
	local cleanups = {}

	observe(function()
		return toRaw(items)
	end, function(_, key: number)
		local get = computed(function()
			return items[key]
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
	updateItems(function(state)
		state[1] = 1
		state[2] = 2
		state[3] = 3
	end)
	assert(table.concat(updates) == "123", `bad update: {table.concat(updates)}`)

	table.clear(updates)
	batch(function()
		items[3] = nil
		items[4] = 4
	end)
	assert(table.concat(updates) == "4", `should add 4: {table.concat(updates)}`)
	assert(table.concat(cleanups) == "3", `bad cleanup: {table.concat(cleanups)}`)
end)

return {}
