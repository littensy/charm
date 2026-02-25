local Charm = require("../Charm")
local DeepCharm = require("../src")
local test = require("../../../tests/test")

type ReactiveProxy<T = any> = DeepCharm.ReactiveProxy<T>

local computed = Charm.computed
local effect = Charm.effect
local reactive = DeepCharm.reactive

local function weakRef<T>(value: T): { value: T? }
	return setmetatable({ value = value }, { __mode = "v" }) :: any
end

local function gc()
	for _ = 1, 2000 do
		local _ = table.create(100, 0)
	end
end

test("should release inner reactive proxy", function()
	local valueRef = weakRef({})
	local src: any = reactive({ value = valueRef.value })

	local dispose = effect(function()
		local _ = src.value -- create proxy
	end)
	src.value = nil :: any -- release proxy
	dispose()

	gc()
	assert(src.__signals.value == nil, "should release signals")
	assert(valueRef.value == nil, "should release inner proxy")
end)

test("should release reactive property deps", function()
	local src: any = reactive({ foo = 1 })

	local c = computed(function()
		return src.foo
	end)

	c()
	assert(src.__signals.foo ~= nil, "should have deps for foo")

	c = nil :: any
	gc()
	assert(src.__signals.foo == nil, "should release deps for foo")
end)

test("should not release effect for reactive", function()
	local src = reactive({ foo = 1 })
	local calls = 0

	effect(function()
		calls += 1
		local _ = src.foo
	end)
	assert(calls == 1, "should call effect once")

	gc()
	src.foo += 1
	assert(calls == 2, "should call effect again")
end)

test("should not release tracked reactive", function()
	local src = reactive({ users = {} :: { [string]: {}? } })
	local user

	effect(function()
		user = src.users.user
	end)

	gc()
	src.users.user = {}
	assert(user ~= nil, "src.users.user should not be released")
end)

return {}
