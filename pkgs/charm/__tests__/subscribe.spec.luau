local atom = require("../src/atom")
local subscribe = require("../src/subscribe")
local suite = require("@tests/suite")

local test = suite.test

test("should subscribe to atom", function()
	local source = atom(0)
	local current, previous

	local unsub = subscribe(source, function(a, b)
		current = a
		previous = b
	end)

	assert(not current and not previous, "should not run initially")
	source(1)
	assert(current == 1, "should run with new value")
	assert(previous == 0, "should run with old value")
	source(2)
	assert(current == 2, "should run with new value 2")
	assert(previous == 1, "should run with old value 2")
	unsub()
	source(3)
	assert(current == 2, "should not run after unsubscribing")
end)

return {}
