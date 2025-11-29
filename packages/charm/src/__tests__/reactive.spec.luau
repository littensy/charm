local Charm = require("../")
local suite = require("../../../../test/suite")

local effect = Charm.effect
local reactive = Charm.reactive
local toRaw = Charm.toRaw
local test = suite.test

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
	assert(runs == 1, runs)

	src.a, src.b = src.b, src.a
	assert(runs == 3, runs)
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
	assert(calls == 1, calls)

	src.value.b = 3
	assert(calls == 1, calls)
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
	assert(runs == 1, runs)

	src.x = 1
	assert(runs == 2, runs)
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
	assert(runs == 1, runs)

	inner.x = 1
	assert(runs == 2, runs)

	src.y = 2
	assert(runs == 3, runs)
end)

return {}
