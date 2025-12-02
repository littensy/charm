local Charm = require("../")
local test = require("../../../../tests/test")

type ReactiveProxy<T = any> = Charm.ReactiveProxy<T>

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local effectScope = Charm.effectScope
local reactive = Charm.reactive

local function weakRef<T>(value: T): { value: T? }
	return setmetatable({ value = value }, { __mode = "v" }) :: any
end

local function gc()
	for _ = 1, 2000 do
		local _ = table.create(100, 0)
	end
end

--[[
	In alien-signals, a computed value unlinks from dependencies when its last
	parent scope is disposed. However, calling a computed value outside of a
	scope still links it to dependencies, which act as strong references.
	Computed values called in this way won't GC until unlinked from a scope.

	This function releases a computed value by linking it to a scope and then
	immediately closing it, causing alien-signals to unlink the computed value
	from its dependencies and allow it to be garbage collected.
]]
local function unlink(getter: () -> ())
	effectScope(function()
		getter()
	end)()
end

test("should release computed cache", function()
	local srcRef = weakRef({})
	local src, setSrc = signal(srcRef.value)
	local c = computed(function()
		return src()
	end)

	c() -- cache src value
	setSrc(nil) -- release value
	unlink(c) -- release computed

	gc()
	assert(srcRef.value == nil, "should release computed cache")
end)

test("should not release effect for atom", function()
	local effectCalls = 0
	local src, setSrc = signal(0)

	effect(function()
		effectCalls += 1
		src()
	end)
	assert(effectCalls == 1, "should call effect once")

	gc()
	setSrc(src() + 1)
	assert(effectCalls == 2, "should call effect again")
end)

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
	local src = Charm.reactive({ users = {} :: { [string]: {}? } })
	local user

	effect(function()
		user = src.users.user
	end)

	gc()
	src.users.user = {}
	assert(user ~= nil, "src.users.user should not be released")
end)

return {}
