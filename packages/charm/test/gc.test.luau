local Charm = require("../src")
local test = require("../../../tests/test")

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local effectScope = Charm.effectScope

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

return {}
