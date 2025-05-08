local suite = require("./suite")

local finish = suite.finish

if not script then
	return
end

_G.__DEV__ = true

require(script.Parent.CharmSync.spec)
require(script.Parent.ReactCharm.spec)
require(script.Parent.VideCharm.spec)

finish()
