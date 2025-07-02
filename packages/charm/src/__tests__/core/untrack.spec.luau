local core = require("../../core")
local suite = require("../../../../../test/suite")

local computed = core.computed
local setCurrentSub = core.setCurrentSub
local atom = core.atom
local test = suite.test

test("should pause tracking", function()
	local src = atom(0)
	local c = computed(function()
		local currentSub = setCurrentSub(nil)
		local value = src()
		setCurrentSub(currentSub)
		return value
	end)
	assert(c() == 0, "should not track src")

	src(1)
	assert(c() == 0, "should not track src")
end)

return {}
