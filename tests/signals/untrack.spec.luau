local test = require("../suite").test
local signals = require("../charm").signals

local computed = signals.computed
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking
local signal = signals.signal

test("should pause tracking", function()
	local src = signal(0)
	local c = computed(function()
		pauseTracking()
		local value = src()
		resumeTracking()
		return value
	end)
	assert(c() == 0, "should not track src")

	src(1)
	assert(c() == 0, "should not track src")
end)

return {}
