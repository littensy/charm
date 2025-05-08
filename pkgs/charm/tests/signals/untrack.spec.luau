local signals = require("../../src/signals")
local suite = require("@tests/suite")

local computed = signals.computed
local setCurrentSub = signals.setCurrentSub
local signal = signals.signal
local test = suite.test

test("should pause tracking", function()
	local src, setSrc = signal(0)
	local c = computed(function()
		local currentSub = setCurrentSub(nil)
		local value = src()
		setCurrentSub(currentSub)
		return value
	end)
	assert(c() == 0, "should not track src")

	setSrc(1)
	assert(c() == 0, "should not track src")
end)

return {}
