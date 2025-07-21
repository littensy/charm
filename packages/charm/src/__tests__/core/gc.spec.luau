local core = require("../../core")
local suite = require("../../../../../test/suite")

local atom = core.atom
local computed = core.computed
local effect = core.effect
local effectScope = core.effectScope
local test = suite.test

--- Creates a weak reference to a value.
local function weakRef<T>(value: T): { value: T? }
	return setmetatable({ value = value }, { __mode = "v" }) :: any
end

--- Triggers garbage collection by creating a large number of tables.
local function gc()
	for _ = 1, 1000 do
		local _ = table.create(100, 0)
	end
end

--- In alien-signals, a computed value unlinks from dependencies when its last
--- parent scope is disposed. However, calling a computed value outside of a
--- scope still links it to dependencies, which act as strong references.
--- Computed values called in this way won't GC until unlinked from a scope.
---
--- This function releases a computed value by linking it to a scope and then
--- immediately closing it, causing alien-signals to unlink the computed value
--- from its dependencies and allow it to be garbage collected.
local function unlink(getter: () -> ())
	effectScope(function()
		getter()
	end)()
end

test("should release computed cache", function()
	local srcRef = weakRef({})
	local src = atom(srcRef.value)
	local c = computed(function()
		return src()
	end)

	c() -- cache src value
	src(nil) -- release value
	c = unlink(c) -- release computed

	gc()
	assert(srcRef.value == nil, "should release computed cache")
end)

test("should not release effect for atom", function()
	local effectCalls = 0
	local src = atom(0)

	effect(function()
		effectCalls += 1
		src()
	end)
	assert(effectCalls == 1, "should call effect once")

	gc()
	src(src() + 1)
	assert(effectCalls == 2, "should call effect again")
end)

return {}
