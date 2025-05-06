local Charm = require("../src/lib")
local suite = require("@tests/suite")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local effectScope = Charm.effectScope
local test = suite.test

--- Creates a weak reference to a value.
--- @return Function to dereference the value.
local function weakRef<T>(value: T): () -> T?
	local ref = setmetatable({ value = value }, { __mode = "v" })
	return function()
		return ref.value
	end
end

--- Triggers garbage collection by allocating excessive memory.
local function gc()
	for _ = 1, 1000 do
		local _ = table.create(100, 0)
	end
end

--- In alien-signals, a computed value unlinks from dependencies when its last
--- parent scope is disposed. Calling a computed value outside of a scope links
--- it to dependencies, but the two-way link holds a strong reference to the
--- computed value, so it won't GC until called in a scope and disposed.
---
--- This function releases a computed value by linking it to a scope and then
--- immediately closing it, causing alien-signals to unlink the computed value
--- and allow it to be garbage collected.
local function release(getter: () -> ())
	effectScope(function()
		getter()
	end)()
end

test("should release computed cache", function()
	local srcRef = weakRef({})
	local src = atom(srcRef())

	local c = computed(function()
		return src()
	end)

	c() -- cache src value
	src(nil) -- release value
	c = release(c) -- release computed

	gc()
	assert(srcRef() == nil, "should release computed cache")
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
